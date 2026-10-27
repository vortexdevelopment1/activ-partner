// --check prints only an aggregate count in a read-only transaction.
// --execute applies the idempotent, venue-local status repair.
require('ts-node/register');
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');
const { Client } = require('pg');
const { getMigrationDatabaseUrlFromEnv } = require('../src/config/database.config');
const root = path.resolve(__dirname, '..');
const readEnv = name => fs.existsSync(path.join(root, name)) ? dotenv.parse(fs.readFileSync(path.join(root, name))) : {};
const env = { ...readEnv('.env'), ...readEnv('.env.local'), ...process.env };
const sql = fs.readFileSync(path.join(root, 'prisma/migrations/20261027_inactive_activity_visibility/migration.sql'), 'utf8');
const checkSql = sql.slice(sql.indexOf('WITH stale_links AS'), sql.indexOf('UPDATE venue_activities AS link')) + 'SELECT COUNT(*)::int AS count FROM stale_links';
const client = new Client({ connectionString: getMigrationDatabaseUrlFromEnv(env), connectionTimeoutMillis: 10000 });
async function main() {
  const execute = process.argv.includes('--execute');
  if (!execute && !process.argv.includes('--check')) throw new Error('Specify --check or --execute');
  await client.connect();
  await client.query(execute ? 'BEGIN' : 'BEGIN READ ONLY');
  try {
    await client.query("SET LOCAL lock_timeout = '10s'");
    await client.query("SET LOCAL statement_timeout = '60s'");
    if (execute) {
      const results = await client.query(sql);
      await client.query('COMMIT');
      const last = Array.isArray(results) ? results.at(-1) : results;
      console.log(JSON.stringify({ repairedVenueActivityLinks: last.rowCount }));
    } else {
      const result = await client.query(checkSql);
      await client.query('ROLLBACK');
      console.log(JSON.stringify({ staleApprovedLinks: result.rows[0].count, readOnly: true }));
    }
  } catch (error) { await client.query('ROLLBACK'); throw error; }
}
main().catch(() => { console.error('Activity visibility repair failed. Check database connectivity and migration permissions.'); process.exitCode = 1; }).finally(() => client.end());
