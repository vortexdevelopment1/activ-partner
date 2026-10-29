// Offline by default. --inspect-local permits catalog reads on loopback only.
// Never invokes migrations, loads NestJS, or sends messages.
require('ts-node/register/transpile-only');
const fs = require('fs');
const path = require('path');
const { parse } = require('dotenv');
const { Client } = require('pg');
const { migrationEnvironment, isProductionEnvironment } = require('../src/config/environment');
const { getDatabaseUrlFromEnv, getMigrationDatabaseUrlFromEnv } = require('../src/config/database.config');
const root = path.resolve(__dirname, '..');
const read = file => fs.existsSync(path.join(root, file)) ? parse(fs.readFileSync(path.join(root, file))) : {};

function describeTarget(value) {
  const url = new URL(value);
  return {
    host: url.hostname, port: url.port || '5432',
    database: decodeURIComponent(url.pathname.slice(1)),
    schema: url.searchParams.get('schema') || 'public',
    loopback: ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname),
  };
}

function configuration(env = process.env, readFile = read) {
  const production = isProductionEnvironment(env);
  // Same process.env > .env.local > .env precedence as ConfigModule.forRoot.
  const runtimeEnv = production ? { ...env } : { ...readFile('.env'), ...readFile('.env.local'), ...env };
  const runtimeUrl = getDatabaseUrlFromEnv(runtimeEnv);
  const migrationUrl = getMigrationDatabaseUrlFromEnv(migrationEnvironment(env, readFile));
  return { production, runtimeUrl, migrationUrl };
}

function assertLocal(config) {
  if (config.production || !describeTarget(config.runtimeUrl).loopback || !describeTarget(config.migrationUrl).loopback) {
    throw new Error('Catalog inspection blocked: both targets must be loopback development databases. No connection was opened.');
  }
}

async function inspect(url) {
  const target = describeTarget(url);
  const client = new Client({ connectionString: url, connectionTimeoutMillis: 5000,
    options: '-c default_transaction_read_only=on -c statement_timeout=5000' });
  try {
    await client.connect();
    const identity = (await client.query('SELECT current_database() AS database, current_schema() AS default_schema, inet_server_addr()::text AS server_address')).rows[0];
    const tables = (await client.query(`SELECT table_name, column_name, data_type, is_nullable, column_default
      FROM information_schema.columns WHERE table_schema=$1 AND table_name IN ('email_deliveries','google_oauth_credentials')
      ORDER BY table_name, ordinal_position`, [target.schema])).rows;
    const indexes = (await client.query(`SELECT tablename, indexname, indexdef FROM pg_indexes
      WHERE schemaname=$1 AND tablename IN ('email_deliveries','google_oauth_credentials') ORDER BY indexname`, [target.schema])).rows;
    const constraints = (await client.query(`SELECT t.relname AS table_name, c.conname, pg_get_constraintdef(c.oid) AS definition
      FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid JOIN pg_namespace n ON n.oid=t.relnamespace
      WHERE n.nspname=$1 AND t.relname IN ('email_deliveries','google_oauth_credentials') ORDER BY c.conname`, [target.schema])).rows;
    const historyExists = (await client.query('SELECT to_regclass($1) IS NOT NULL AS present', [`${target.schema}._prisma_migrations`])).rows[0].present;
    // Identifiers cannot be SQL parameters; quote the configured schema safely.
    const schema = '"' + target.schema.replace(/"/g, '""') + '"';
    const migrations = historyExists ? (await client.query(`SELECT migration_name, finished_at IS NOT NULL AS finished,
      rolled_back_at IS NOT NULL AS rolled_back FROM ${schema}._prisma_migrations ORDER BY started_at`)).rows : [];
    return { identity, tables, indexes, constraints, migrationHistoryPresent: historyExists, migrations };
  } finally { await client.end(); }
}

async function main() {
  const config = configuration();
  console.log(JSON.stringify({ production: config.production,
    runtime: describeTarget(config.runtimeUrl), migrations: describeTarget(config.migrationUrl),
    identicalConnectionConfiguration: config.runtimeUrl === config.migrationUrl }, null, 2));
  if (!process.argv.includes('--inspect-local')) {
    console.log('Offline only: no database connection opened. Use --inspect-local for loopback catalog inspection.');
    return;
  }
  assertLocal(config);
  console.log(JSON.stringify({ runtimeCatalog: await inspect(config.runtimeUrl), migrationCatalog: await inspect(config.migrationUrl) }, null, 2));
}

module.exports = { describeTarget, configuration, assertLocal };
if (require.main === module) main().catch(error => {
  // Driver error text may contain connection details. Never print it.
  console.error(error.message?.startsWith('Catalog inspection blocked:') ? error.message : 'Email schema check failed. Check local database availability and configuration; credentials were not printed.');
  process.exitCode = 1;
});
