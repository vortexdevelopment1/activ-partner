import 'reflect-metadata';
import { config } from 'dotenv';
import { PrismaPg } from '@prisma/adapter-pg';

import { PrismaClient } from '../../generated/prisma/client';
import { getDatabaseUrlFromEnv } from '../../config/database.config';
import { isProductionEnvironment } from '../../config/environment';
import { seedAdmin } from './admin.seed';
import { seedPartner } from './partner.seed';
import { seedCategories } from './categories.seed';
import { seedQuestions } from './questions.seed';
import { seedActivityDetailFields } from './activity-detail-fields.seed';

if (!isProductionEnvironment(process.env)) {
  config({ path: ['.env.local', '.env'] });
}
const adapter = new PrismaPg(getDatabaseUrlFromEnv(process.env));
const prisma = new PrismaClient({ adapter });

async function runSeeds() {
  try {
    const args = process.argv.slice(2);
    const adminOnly = args.includes('--admin-only');
    if (adminOnly && args.length !== 1) {
      throw new Error('--admin-only cannot be combined with activity names');
    }
    if (adminOnly && !process.env.DATABASE_URL && !process.env.DB_HOST) {
      throw new Error('Set DATABASE_URL or DB_HOST for the database used by the backend before seeding.');
    }
    await prisma.$connect();
    console.log('Database connected. Running seeds...');

    if (adminOnly) {
      await seedAdmin(prisma, { verifyCredentials: true });
    } else if (args.length > 0) {
      await seedQuestions(prisma, args);
    } else {
      await seedAdmin(prisma);
      if (process.env.SEED_DEMO_PARTNER === 'true') {
        await seedPartner(prisma);
      }
      await seedCategories(prisma);
      // await seedQuestions(prisma); // Replaced by seedActivityDetailFields
      await seedActivityDetailFields(prisma);
    }

    console.log('All seeds completed successfully.');
  } catch (error) {
    console.error('Error running seeds:', error);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
}

void runSeeds();
