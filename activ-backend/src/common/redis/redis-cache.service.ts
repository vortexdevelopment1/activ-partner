import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis, { RedisOptions } from 'ioredis';
import { loadRedisCacheConfig, RedisCacheConfig } from './redis.config';
import { CacheKeys, withTtlJitter } from './redis-cache.keys';

const MAX_CACHE_PAYLOAD_BYTES = 1_048_576; // 1 MB cap per key
const TAG_INDEX_TTL_SECONDS = 24 * 60 * 60;
const ERROR_LOG_THROTTLE_MS = 30_000;

export interface CacheMetrics {
  hits: number;
  misses: number;
  coalesced: number;
  invalidations: number;
  fallbacks: number;
  errors: number;
  oversizedSkips: number;
}

@Injectable()
export class RedisCacheService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisCacheService.name);
  readonly config: RedisCacheConfig;
  readonly keys: CacheKeys;

  private client: Redis | null = null;
  private isReady = false;
  private readonly inflight = new Map<string, Promise<unknown>>();
  private readonly lastErrorLoggedAt = new Map<string, number>();

  private readonly metrics: CacheMetrics = {
    hits: 0,
    misses: 0,
    coalesced: 0,
    invalidations: 0,
    fallbacks: 0,
    errors: 0,
    oversizedSkips: 0,
  };

  constructor(configService: ConfigService) {
    this.config = loadRedisCacheConfig(configService);
    this.keys = new CacheKeys(this.config.keyPrefix, this.config.env);
  }

  async onModuleInit(): Promise<void> {
    if (!this.config.enabled || !this.config.url) {
      this.logger.log('Redis cache disabled (REDIS_URL unset or REDIS_CACHE_ENABLED=false); using PostgreSQL directly.');
      return;
    }

    const useTls = this.config.url.startsWith('rediss://');
    const options: RedisOptions = {
      lazyConnect: true,
      connectTimeout: this.config.connectTimeoutMs,
      commandTimeout: this.config.commandTimeoutMs,
      maxRetriesPerRequest: 1,
      enableOfflineQueue: false,
      enableReadyCheck: true,
      retryStrategy: (times: number) => {
        if (times > 20) return 30_000;
        const base = Math.min(100 * Math.pow(2, times), 10_000);
        const jitter = Math.floor(Math.random() * 250);
        return base + jitter;
      },
      ...(useTls
        ? { tls: { rejectUnauthorized: this.config.tlsRejectUnauthorized } }
        : {}),
    };

    this.client = new Redis(this.config.url, options);
    this.client.on('ready', () => {
      this.isReady = true;
      this.logger.log(`Redis cache connected (env=${this.config.env}, prefix=${this.config.keyPrefix}).`);
    });
    this.client.on('close', () => {
      this.isReady = false;
    });
    this.client.on('end', () => {
      this.isReady = false;
    });
    this.client.on('error', (err: Error) => {
      this.isReady = false;
      this.metrics.errors += 1;
      this.logThrottledError('redis_client_error', err.message);
    });

    try {
      await this.client.connect();
    } catch (err) {
      this.isReady = false;
      this.metrics.errors += 1;
      const msg = err instanceof Error ? err.message : String(err);
      this.logThrottledError('redis_init_connect', msg);
    }
  }

  async onModuleDestroy(): Promise<void> {
    this.isReady = false;
    if (this.client) {
      try {
        await this.client.quit();
      } catch {
        this.client.disconnect();
      }
      this.client = null;
    }
  }

  private logThrottledError(category: string, message: string): void {
    const now = Date.now();
    const last = this.lastErrorLoggedAt.get(category) ?? 0;
    if (now - last < ERROR_LOG_THROTTLE_MS) return;
    this.lastErrorLoggedAt.set(category, now);
    if (message.toLowerCase().includes('allowlist')) {
      this.logger.warn(
        `Redis connection blocked by IP allowlist (${message}). Ensure backend egress IP or private network is allowlisted; falling back to PostgreSQL.`,
      );
      return;
    }
    this.logger.warn(`Redis unavailable [${category}]: ${message}; falling back to PostgreSQL.`);
  }

  private canUseRedis(): boolean {
    return Boolean(this.config.enabled && this.client && this.isReady);
  }

  async getOrSet<T>(
    key: string,
    ttlSeconds: number,
    fetcher: () => Promise<T>,
    tags: string[] = [],
  ): Promise<T> {
    if (!this.canUseRedis()) {
      this.metrics.fallbacks += 1;
      return this.coalesce(key, fetcher);
    }

    try {
      const started = this.config.perfLogging ? process.hrtime.bigint() : 0n;
      const raw = await this.client!.get(key);
      if (raw !== null) {
        this.metrics.hits += 1;
        if (this.config.perfLogging) {
          const ms = Number(process.hrtime.bigint() - started) / 1e6;
          this.logger.log(`event=cache_hit key=${key} redis_ms=${ms.toFixed(2)}`);
        }
        return JSON.parse(raw) as T;
      }
    } catch (err) {
      this.metrics.errors += 1;
      this.metrics.fallbacks += 1;
      this.logThrottledError('redis_get', err instanceof Error ? err.message : String(err));
      return this.coalesce(key, fetcher);
    }

    this.metrics.misses += 1;
    return this.coalesce(key, async () => {
      const value = await fetcher();
      await this.set(key, value, ttlSeconds, tags);
      return value;
    });
  }

  private async coalesce<T>(key: string, fn: () => Promise<T>): Promise<T> {
    const existing = this.inflight.get(key) as Promise<T> | undefined;
    if (existing) {
      this.metrics.coalesced += 1;
      return existing;
    }
    const promise = fn().finally(() => {
      this.inflight.delete(key);
    });
    this.inflight.set(key, promise);
    return promise;
  }

  async set(
    key: string,
    value: unknown,
    ttlSeconds: number = this.config.defaultTtlSeconds,
    tags: string[] = [],
  ): Promise<void> {
    if (!this.canUseRedis() || value === undefined) return;
    try {
      const serialized = JSON.stringify(value);
      if (Buffer.byteLength(serialized, 'utf8') > MAX_CACHE_PAYLOAD_BYTES) {
        this.metrics.oversizedSkips += 1;
        return;
      }
      const ttl = withTtlJitter(ttlSeconds);
      const pipeline = this.client!.pipeline();
      pipeline.set(key, serialized, 'EX', ttl);
      for (const tag of tags) {
        const tagKey = this.keys.tag(tag);
        pipeline.sadd(tagKey, key);
        pipeline.expire(tagKey, TAG_INDEX_TTL_SECONDS);
      }
      await pipeline.exec();
    } catch (err) {
      this.metrics.errors += 1;
      this.logThrottledError('redis_set', err instanceof Error ? err.message : String(err));
    }
  }

  async del(...keys: string[]): Promise<void> {
    const valid = keys.filter(Boolean);
    if (!this.canUseRedis() || valid.length === 0) return;
    try {
      await this.client!.unlink(...valid);
      this.metrics.invalidations += valid.length;
    } catch (err) {
      this.metrics.errors += 1;
      this.logThrottledError('redis_del', err instanceof Error ? err.message : String(err));
    }
  }

  async invalidateTags(...tags: string[]): Promise<void> {
    const validTags = tags.filter(Boolean);
    if (!this.canUseRedis() || validTags.length === 0) return;
    try {
      const tagKeys = validTags.map((t) => this.keys.tag(t));
      const membersList = await Promise.all(
        tagKeys.map((tk) => this.client!.smembers(tk)),
      );
      const toDelete = new Set<string>(tagKeys);
      for (const members of membersList) {
        for (const member of members) toDelete.add(member);
      }
      if (toDelete.size > 0) {
        await this.client!.unlink(...Array.from(toDelete));
        this.metrics.invalidations += toDelete.size;
      }
    } catch (err) {
      this.metrics.errors += 1;
      this.logThrottledError('redis_invalidate_tags', err instanceof Error ? err.message : String(err));
    }
  }

  async getHealth(): Promise<{
    enabled: boolean;
    connected: boolean;
    latencyMs: number | null;
    hitRatio: number;
    metrics: CacheMetrics;
  }> {
    let latencyMs: number | null = null;
    if (this.canUseRedis()) {
      try {
        const started = process.hrtime.bigint();
        await this.client!.ping();
        latencyMs = Number((Number(process.hrtime.bigint() - started) / 1e6).toFixed(2));
      } catch {
        this.isReady = false;
      }
    }
    const total = this.metrics.hits + this.metrics.misses;
    const hitRatio = total > 0 ? Number((this.metrics.hits / total).toFixed(4)) : 0;
    return {
      enabled: this.config.enabled,
      connected: this.isReady,
      latencyMs,
      hitRatio,
      metrics: { ...this.metrics },
    };
  }

  getMetrics(): CacheMetrics {
    return { ...this.metrics };
  }
}
