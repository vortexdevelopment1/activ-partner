import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaPg } from '@prisma/adapter-pg';

import { PrismaClient } from '../generated/prisma/client';
import { getDatabaseUrl, getPrismaLogLevels } from '../config/database.config';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  constructor(configService: ConfigService) {
    const connectionString = getDatabaseUrl(configService);
    const adapter = new PrismaPg({
      connectionString,
      max: 5,
      connectionTimeoutMillis: 15000,
      idleTimeoutMillis: 10000,
      maxLifetimeSeconds: 300,
      keepAlive: true,
      keepAliveInitialDelayMillis: 10000,
    }, {
      onPoolError: () => new Logger(PrismaService.name).warn(
        'An idle database connection was lost; the pool will replace it.',
      ),
    });

    super({
      adapter,
      log: getPrismaLogLevels(configService),
    });
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
