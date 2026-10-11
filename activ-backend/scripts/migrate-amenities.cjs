require('ts-node/register');
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');
const { Client } = require('pg');
const { getMigrationDatabaseUrlFromEnv } = require('../src/config/database.config');

const root = path.resolve(__dirname, '..');
const readEnv = (file) => fs.existsSync(file) ? dotenv.parse(fs.readFileSync(file)) : {};
const env = { ...process.env, ...readEnv(path.join(root, '.env')), ...readEnv(path.join(root, '.env.local')) };
const client = new Client({ connectionString: getMigrationDatabaseUrlFromEnv(env), connectionTimeoutMillis: 10000 });

async function main() {
  if (!process.argv.includes('--execute') && !process.argv.includes('--check')) {
    throw new Error('Specify --check or --execute');
  }
  await client.connect();
  await client.query('BEGIN');
  try {
    await client.query("SET LOCAL lock_timeout = '10s'");
    await client.query("SELECT pg_advisory_xact_lock(hashtext('amenity_catalog'))");
    await client.query(fs.readFileSync(path.join(root, 'prisma/migrations/20261011_amenity_catalog/migration.sql'), 'utf8'));
    const result = await client.query('SELECT COUNT(*)::int AS count FROM partner_amenity_catalog WHERE active = true');
    if (result.rows[0].count !== 24) throw new Error('Expected 24 active amenities');
    await client.query(process.argv.includes('--execute') ? 'COMMIT' : 'ROLLBACK');
    console.log(process.argv.includes('--execute') ? 'Database updated: 24 amenities.' : 'Validated 24 amenities; changes rolled back.');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  }
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; }).finally(() => client.end());
