import { ConfigService } from '@nestjs/config';
import { RedisCacheService } from './redis-cache.service';
import { canonicalQueryHash, withTtlJitter } from './redis-cache.keys';

describe('RedisCacheService', () => {
  const makeConfig = (overrides: Record<string, string> = {}) =>
    ({
      get: (key: string) => overrides[key],
    }) as unknown as ConfigService;

  it('produces deterministic canonical query hashes regardless of key order or empty values', () => {
    const h1 = canonicalQueryHash({ page: 1, limit: 10, search: ' turf ', empty: '' });
    const h2 = canonicalQueryHash({ search: 'turf', limit: 10, page: 1, extra: undefined });
    expect(h1).toBe(h2);
    expect(h1).toHaveLength(16);
  });

  it('scopes cache keys by environment and partner id to prevent cross-partner leakage', () => {
    const svc = new RedisCacheService(makeConfig({ APP_ENV: 'production', REDIS_KEY_PREFIX: 'activ' }));
    const k1 = svc.keys.partnerVenues('partner-a');
    const k2 = svc.keys.partnerVenues('partner-b');
    expect(k1).toBe('activ:prod:partner:v1:partner:partner-a:venues');
    expect(k2).toBe('activ:prod:partner:v1:partner:partner-b:venues');
    expect(k1).not.toBe(k2);
  });

  it('applies bounded +/-10% TTL jitter', () => {
    for (let i = 0; i < 20; i++) {
      const ttl = withTtlJitter(100);
      expect(ttl).toBeGreaterThanOrEqual(90);
      expect(ttl).toBeLessThanOrEqual(110);
    }
  });

  it('falls back to PostgreSQL fetcher when Redis is disabled and coalesces concurrent identical misses', async () => {
    const svc = new RedisCacheService(makeConfig({ REDIS_CACHE_ENABLED: 'false' }));
    await svc.onModuleInit();

    let calls = 0;
    const fetcher = async () => {
      calls += 1;
      await new Promise((r) => setTimeout(r, 15));
      return { ok: true, calls };
    };

    const [a, b, c] = await Promise.all([
      svc.getOrSet('k:coalesce', 60, fetcher),
      svc.getOrSet('k:coalesce', 60, fetcher),
      svc.getOrSet('k:coalesce', 60, fetcher),
    ]);

    expect(calls).toBe(1);
    expect(a).toEqual({ ok: true, calls: 1 });
    expect(b).toEqual({ ok: true, calls: 1 });
    expect(c).toEqual({ ok: true, calls: 1 });
    expect(svc.getMetrics().coalesced).toBe(2);
    expect(svc.getMetrics().fallbacks).toBe(3);
  });

  it('serves cache hits, populates on miss, invalidates by tag, and falls back on Redis error', async () => {
    const svc = new RedisCacheService(
      makeConfig({ REDIS_URL: 'redis://127.0.0.1:6379', REDIS_CACHE_ENABLED: 'true' }),
    );
    const store = new Map<string, string>();
    const tagSets = new Map<string, Set<string>>();

    const mockClient: any = {
      get: jest.fn(async (k: string) => store.get(k) ?? null),
      pipeline: jest.fn(() => {
        const ops: Array<() => void> = [];
        const pipe = {
          set: (k: string, v: string) => {
            ops.push(() => store.set(k, v));
            return pipe;
          },
          sadd: (tk: string, k: string) => {
            ops.push(() => {
              if (!tagSets.has(tk)) tagSets.set(tk, new Set());
              tagSets.get(tk)!.add(k);
            });
            return pipe;
          },
          expire: () => pipe,
          exec: async () => {
            ops.forEach((op) => op());
            return [];
          },
        };
        return pipe;
      }),
      smembers: jest.fn(async (tk: string) => Array.from(tagSets.get(tk) ?? [])),
      unlink: jest.fn(async (...keys: string[]) => {
        keys.forEach((k) => {
          store.delete(k);
          tagSets.delete(k);
        });
        return keys.length;
      }),
      ping: jest.fn(async () => 'PONG'),
    };
    (svc as any).client = mockClient;
    (svc as any).isReady = true;

    let dbCalls = 0;
    const fetcher = async () => {
      dbCalls += 1;
      return { count: dbCalls };
    };

    const key = svc.keys.adminVenueStats();
    const first = await svc.getOrSet(key, 45, fetcher, ['admin:venues']);
    const second = await svc.getOrSet(key, 45, fetcher, ['admin:venues']);
    expect(first).toEqual({ count: 1 });
    expect(second).toEqual({ count: 1 });
    expect(dbCalls).toBe(1);
    expect(svc.getMetrics().hits).toBe(1);
    expect(svc.getMetrics().misses).toBe(1);

    await svc.invalidateTags('admin:venues');
    const afterInvalidation = await svc.getOrSet(key, 45, fetcher, ['admin:venues']);
    expect(afterInvalidation).toEqual({ count: 2 });
    expect(dbCalls).toBe(2);

    // Simulate Redis outage during GET
    mockClient.get.mockRejectedValueOnce(new Error('ERR Client IP address is not in the allowlist.'));
    const fallbackResult = await svc.getOrSet(key, 45, fetcher, ['admin:venues']);
    expect(fallbackResult).toEqual({ count: 3 });
    expect(svc.getMetrics().errors).toBe(1);
  });
});
