import type { ConfigService } from '@nestjs/config';

type Env = Record<string, string | number | boolean | undefined>;

export const getDatabaseUrlFromEnv = (env: Env): string => {
  if (env.DATABASE_URL) return String(env.DATABASE_URL);
  const url = new URL('postgresql://localhost');
  url.hostname = String(env.DB_HOST || 'localhost');
  url.port = String(env.DB_PORT || 5432);
  url.username = String(env.DB_USERNAME || 'postgres');
  url.password = String(env.DB_PASSWORD || 'postgres');
  url.pathname = `/${env.DB_DATABASE || 'activ_product_db'}`;
  return url.toString();
};

<<<<<<< HEAD
/**
 * Resolve the direct connection used by Prisma migrations and catalog checks.
 * Callers should pass the result of migrationEnvironment so production
 * credentials cannot inherit local-file overrides.
 */
=======
>>>>>>> origin/main
export const getMigrationDatabaseUrlFromEnv = (env: Env): string =>
  env.DIRECT_URL ? String(env.DIRECT_URL) : getDatabaseUrlFromEnv(env);

export const getDatabaseUrl = (config: ConfigService): string =>
  getDatabaseUrlFromEnv({
    DATABASE_URL: config.get<string>('DATABASE_URL'),
    DB_HOST: config.get<string>('DB_HOST'),
    DB_PORT: config.get<string | number>('DB_PORT'),
    DB_USERNAME: config.get<string>('DB_USERNAME'),
    DB_PASSWORD: config.get<string>('DB_PASSWORD'),
    DB_DATABASE: config.get<string>('DB_DATABASE'),
  });

export const getPrismaLogLevels = (config: ConfigService): Array<'query' | 'info' | 'warn' | 'error'> =>
  config.get<string | boolean>('DB_LOGGING', false) === true || config.get<string>('DB_LOGGING', 'false') === 'true'
    ? ['query', 'info', 'warn', 'error']
    : ['warn', 'error'];
