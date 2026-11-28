import { ConfigService } from '@nestjs/config';

export interface RedisCacheConfig {
  enabled: boolean;
  url: string | null;
  keyPrefix: string;
  env: string;
  connectTimeoutMs: number;
  commandTimeoutMs: number;
  defaultTtlSeconds: number;
  tlsRejectUnauthorized: boolean;
  perfLogging: boolean;
}

function parsePositiveInt(raw: string | undefined, fallback: number): number {
  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : fallback;
}

export function loadRedisCacheConfig(config: ConfigService): RedisCacheConfig {
  const url = (config.get<string>('REDIS_URL') ?? process.env.REDIS_URL ?? '').trim() || null;
  const rawEnabled = (
    config.get<string>('REDIS_CACHE_ENABLED') ??
    process.env.REDIS_CACHE_ENABLED ??
    ''
  )
    .trim()
    .toLowerCase();

  const enabled = rawEnabled === 'false' ? false : Boolean(url);
  const rawEnv = (
    config.get<string>('APP_ENV') ??
    config.get<string>('NODE_ENV') ??
    process.env.APP_ENV ??
    process.env.NODE_ENV ??
    'dev'
  )
    .trim()
    .toLowerCase();
  const env = rawEnv === 'production' ? 'prod' : rawEnv === 'development' ? 'dev' : rawEnv;

  const keyPrefix = (
    config.get<string>('REDIS_KEY_PREFIX') ??
    process.env.REDIS_KEY_PREFIX ??
    'activ'
  )
    .trim()
    .replace(/[^a-zA-Z0-9_-]/g, '') || 'activ';

  const perfLogging =
    (config.get<string>('ACTIV_PERF_LOGGING') ?? process.env.ACTIV_PERF_LOGGING) === 'true' ||
    (config.get<string>('PERF_LOGGING') ?? process.env.PERF_LOGGING) === 'true';

  return {
    enabled,
    url,
    keyPrefix,
    env,
    connectTimeoutMs: parsePositiveInt(
      config.get<string>('REDIS_CONNECT_TIMEOUT_MS') ?? process.env.REDIS_CONNECT_TIMEOUT_MS,
      3000,
    ),
    commandTimeoutMs: parsePositiveInt(
      config.get<string>('REDIS_COMMAND_TIMEOUT_MS') ?? process.env.REDIS_COMMAND_TIMEOUT_MS,
      1500,
    ),
    defaultTtlSeconds: parsePositiveInt(
      config.get<string>('REDIS_CACHE_DEFAULT_TTL_SECONDS') ??
        process.env.REDIS_CACHE_DEFAULT_TTL_SECONDS,
      300,
    ),
    tlsRejectUnauthorized:
      (config.get<string>('REDIS_TLS_REJECT_UNAUTHORIZED') ??
        process.env.REDIS_TLS_REJECT_UNAUTHORIZED) !== 'false',
    perfLogging,
  };
}
