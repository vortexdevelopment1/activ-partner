require('ts-node/register');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const dotenv = require('dotenv');
const { Client } = require('pg');
const { getMigrationDatabaseUrlFromEnv } = require('../src/config/database.config');

const root = path.resolve(__dirname, '..');
const readEnv = (file) => fs.existsSync(file) ? dotenv.parse(fs.readFileSync(file)) : {};
const env = { ...process.env, ...readEnv(path.join(root, '.env')), ...readEnv(path.join(root, '.env.local')) };
const connectionString = getMigrationDatabaseUrlFromEnv(env);
const client = new Client({ connectionString, connectionTimeoutMillis: 10000 });
const migration = '20261008_normalize_venue_data';

async function main() {
  console.log('Database host:', new URL(connectionString).hostname);
  await client.connect();
  const execute = process.argv.includes('--execute');
  const check = process.argv.includes('--check');
  if (!execute && !check) {
    const result = await client.query(`SELECT
      (SELECT count(*) FROM venues) AS venues,
      (SELECT count(*) FROM partner_venue_services) AS activities,
      (SELECT array_agg(DISTINCT key) FROM venues, jsonb_object_keys(COALESCE(metadata::jsonb, '{}'::jsonb)) key) AS venue_keys,
      (SELECT array_agg(DISTINCT key) FROM partner_venue_services, jsonb_object_keys(onboarding_data::jsonb) key) AS activity_keys`);
    console.log(JSON.stringify(result.rows[0]));
    return;
  }
  const sql = fs.readFileSync(path.join(root, 'prisma', 'migrations', migration, 'migration.sql'), 'utf8');
  const checksum = crypto.createHash('sha256').update(sql).digest('hex');
  await client.query('BEGIN');
  try {
    await client.query("SET LOCAL lock_timeout = '10s'");
    await client.query("SET LOCAL statement_timeout = '120s'");
    await client.query("SELECT pg_advisory_xact_lock(hashtext('normalize_venue_data'))");
    await client.query(`CREATE TABLE IF NOT EXISTS partner_schema_migrations (
      name text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())`);
    const applied = await client.query('SELECT checksum FROM partner_schema_migrations WHERE name = $1', [migration]);
    if (applied.rowCount) {
      if (applied.rows[0].checksum !== checksum) throw new Error('Applied migration checksum differs');
      console.log('Migration already applied.');
    } else {
      await client.query(sql);
      await client.query('INSERT INTO partner_schema_migrations (name, checksum) VALUES ($1, $2)', [migration, checksum]);
      console.log('Venue tables created and existing JSON data backfilled. Source JSON retained.');
    }
    const counts = await client.query(`SELECT
      (SELECT count(*) FROM partner_venue_availability) AS availability_rows,
      (SELECT count(*) FROM partner_venue_amenities) AS venue_amenities,
      (SELECT count(*) FROM partner_service_amenities) AS activity_amenities,
      (SELECT count(*) FROM partner_venue_images WHERE venue_service_id IS NOT NULL) AS activity_images,
      (SELECT count(*) FROM partner_venue_legal_documents) AS legal_documents`);
    console.log(JSON.stringify(counts.rows[0]));
    await client.query(check ? 'ROLLBACK' : 'COMMIT');
    console.log(check ? 'Validation succeeded; transaction rolled back.' : 'Migration committed.');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  }
}

main().catch((error) => { console.error(error.message); process.exitCode = 1; })
  .finally(() => client.end());
