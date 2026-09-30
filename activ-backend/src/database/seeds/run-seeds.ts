import 'reflect-metadata';
import { config } from 'dotenv';
import { PrismaPg } from '@prisma/adapter-pg';

import { PrismaClient } from '../../generated/prisma/client';
import { getDatabaseUrlFromEnv } from '../../config/database.config';
import { seedAdmin } from './admin.seed';
import { seedCategories } from './categories.seed';
import { seedQuestions } from './questions.seed';

const envFile = config({ path: '.env' }).parsed ?? {};
const localEnvFile = config({ path: '.env.local' }).parsed ?? {};
const databaseEnv = { ...process.env, ...envFile, ...localEnvFile };
const adapter = new PrismaPg(getDatabaseUrlFromEnv(databaseEnv));
const prisma = new PrismaClient({ adapter });

async function runSeeds() {
  try {
    await prisma.$connect();
    console.log('Database connected. Running seeds...');

    await seedAdmin(prisma);
    await seedCategories(prisma);
    await seedQuestions(prisma);

    console.log('All seeds completed successfully.');
  } catch (error) {
    console.error('Error running seeds:', error);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
}

void runSeeds();
