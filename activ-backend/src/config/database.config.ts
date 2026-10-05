import type { ConfigService } from '@nestjs/config';
import type { TypeOrmModuleOptions } from '@nestjs/typeorm';

type DatabaseEnv = {
  [key: string]: string | number | boolean | undefined;
  DATABASE_URL?: string;
  DIRECT_URL?: string;
  DB_HOST?: string;
  DB_PORT?: string | number;
  DB_USERNAME?: string;
  DB_PASSWORD?: string;
  DB_DATABASE?: string;
  DB_SSL?: string | boolean;
};

const truthy = (value: string | boolean | undefined): boolean =>
  value === true || value === 'true';

const withSslMode = (databaseUrl: string, sslEnabled: boolean): string => {
  if (!sslEnabled) {
    return databaseUrl;
  }

  try {
    const url = new URL(databaseUrl);
    if (!url.searchParams.has('sslmode')) {
      url.searchParams.set('sslmode', 'require');
    }
    if (!url.searchParams.has('uselibpqcompat')) {
      url.searchParams.set('uselibpqcompat', 'true');
    }
    return url.toString();
  } catch {
    return databaseUrl;
  }
};

const isLocalhostUrl = (databaseUrl: string): boolean => {
  try {
    const hostname = new URL(databaseUrl).hostname;
    return hostname === 'localhost' || hostname === '127.0.0.1';
  } catch {
    return false;
  }
};

const isLocalhostHost = (host: string | undefined): boolean =>
  !host || host === 'localhost' || host === '127.0.0.1';

export const getDatabaseUrlFromEnv = (env: DatabaseEnv): string => {
  const sslEnabled = truthy(env.DB_SSL);

  if (
    env.DATABASE_URL &&
    !(
      isLocalhostUrl(env.DATABASE_URL) &&
      !isLocalhostHost(env.DB_HOST)
    )
  ) {
    return withSslMode(env.DATABASE_URL, sslEnabled);
  }

  const url = new URL('postgresql://localhost');
  url.hostname = env.DB_HOST || 'localhost';
  url.port = String(env.DB_PORT || 5432);
  url.username = env.DB_USERNAME || 'postgres';
  url.password = env.DB_PASSWORD || 'postgres';
  url.pathname = `/${env.DB_DATABASE || 'activ_product_db'}`;

  return withSslMode(url.toString(), sslEnabled);
};

export const getMigrationDatabaseUrlFromEnv = (env: DatabaseEnv): string =>
  env.DIRECT_URL
    ? withSslMode(env.DIRECT_URL, truthy(env.DB_SSL))
    : getDatabaseUrlFromEnv(env);

export const getDatabaseUrl = (configService: ConfigService): string => {
  return getDatabaseUrlFromEnv({
    DATABASE_URL: configService.get<string>('DATABASE_URL'),
    DB_HOST: configService.get<string>('DB_HOST'),
    DB_PORT: configService.get<string | number>('DB_PORT'),
    DB_USERNAME: configService.get<string>('DB_USERNAME'),
    DB_PASSWORD: configService.get<string>('DB_PASSWORD'),
    DB_DATABASE: configService.get<string>('DB_DATABASE'),
    DB_SSL: configService.get<string | boolean>('DB_SSL'),
  });
};

export const getPrismaLogLevels = (
  configService: ConfigService,
): Array<'query' | 'info' | 'warn' | 'error'> => {
  return configService.get<string | boolean>('DB_LOGGING', false) === true ||
    configService.get<string>('DB_LOGGING', 'false') === 'true'
    ? ['query', 'info', 'warn', 'error']
    : ['warn', 'error'];
};

export const getTypeOrmCompatibilityConfig = (
  configService: ConfigService,
): TypeOrmModuleOptions => {
  const sslEnabled =
    configService.get<string | boolean>('DB_SSL', false) === true ||
    configService.get<string>('DB_SSL', 'false') === 'true';
  // TypeORM keeps long-lived connections, so Supabase's session-mode pooler is
  // more suitable than the transaction-mode URL used by Prisma.
  const databaseUrl = getMigrationDatabaseUrlFromEnv({
    DATABASE_URL: configService.get<string>('DATABASE_URL'),
    DIRECT_URL: configService.get<string>('DIRECT_URL'),
    DB_HOST: configService.get<string>('DB_HOST'),
    DB_PORT: configService.get<string | number>('DB_PORT'),
    DB_USERNAME: configService.get<string>('DB_USERNAME'),
    DB_PASSWORD: configService.get<string>('DB_PASSWORD'),
    DB_DATABASE: configService.get<string>('DB_DATABASE'),
    DB_SSL: sslEnabled,
  });
  const sslConfig = sslEnabled ? { rejectUnauthorized: false } : false;

  return {
    type: 'postgres',
    url: databaseUrl,
    entities: [__dirname + '/../**/*.entity{.ts,.js}'],
    migrations: [__dirname + '/../database/migrations/*{.ts,.js}'],
    synchronize: false,
    logging:
      configService.get<string | boolean>('DB_LOGGING', false) === true ||
      configService.get<string>('DB_LOGGING', 'false') === 'true',
    retryAttempts: 10,
    retryDelay: 3000,
    ssl: sslConfig,
    extra: {
      ssl: sslConfig,
      connectionTimeoutMillis: 15000,
      keepAlive: true,
    },
  };
};
