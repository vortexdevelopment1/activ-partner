require('ts-node/register');
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');
const { ConfigService } = require('@nestjs/config');
const { PrismaService } = require('../src/prisma/prisma.service');
const root = path.resolve(__dirname, '..');
const readEnv = (name) => fs.existsSync(path.join(root, name)) ? dotenv.parse(fs.readFileSync(path.join(root, name))) : {};
const db = new PrismaService(new ConfigService({ ...process.env, ...readEnv('.env'), ...readEnv('.env.local') }));
async function main() {
  try {
    await db.onModuleInit();
    for (let i = 0; i < 3; i++) {
      await db.$queryRawUnsafe('SELECT 1');
      console.log(`Prisma database read ${i + 1}/3: OK`);
      if (i < 2) await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  } finally {
    await db.onModuleDestroy();
  }
}
main().catch((error) => {
  console.error(`Database connection check failed (${error.code ?? 'network error'}). No records were changed.`);
  process.exitCode = 1;
});
