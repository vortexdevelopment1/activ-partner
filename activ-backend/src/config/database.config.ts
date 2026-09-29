import { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';

export const getDatabaseConfig = (
  configService: ConfigService,
): TypeOrmModuleOptions => {
  const sslEnabled =
    configService.get<string>('DB_SSL', 'false') === 'true';

  const sslConfig = sslEnabled
    ? { rejectUnauthorized: false }
    : false;

  return {
    type: 'postgres',
    host: configService.get<string>('DB_HOST', 'localhost'),
    port: configService.get<number>('DB_PORT', 5432),
    username: configService.get<string>('DB_USERNAME', 'postgres'),
    password: configService.get<string>('DB_PASSWORD', 'postgres'),
    database: configService.get<string>('DB_DATABASE', 'neondb'),

    entities: [__dirname + '/../**/*.entity{.ts,.js}'],

    synchronize: configService.get<boolean>('DB_SYNCHRONIZE', true),
    logging: configService.get<boolean>('DB_LOGGING', false),

    ssl: sslConfig,
    extra: {
      ssl: sslConfig,
    },
  };
};