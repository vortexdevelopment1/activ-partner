// Creates its own loopback-only cluster. Never consumes DATABASE_URL/DB_* or .env.
const { execFile, spawn } = require('child_process');
const { promisify } = require('util');
const fs = require('fs');
const os = require('os');
const path = require('path');
const net = require('net');
const { randomUUID } = require('crypto');
const { Client } = require('pg');
const exec = promisify(execFile);
const root = path.resolve(__dirname, '..');
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'activ-pg-integration-'));
const data = path.join(directory, 'data');
const binary = name => path.join(process.env.PG_BIN || (process.platform === 'win32'
  ? 'C:\\Program Files\\PostgreSQL\\16\\bin' : '/usr/lib/postgresql/16/bin'), name + (process.platform === 'win32' ? '.exe' : ''));
const marker = randomUUID();
let started = false;
let client;
async function run(file, args, env) {
  try {
    return await exec(file, args, { cwd: root, env, windowsHide: true, maxBuffer: 8 * 1024 * 1024 });
  } catch (error) {
    // Only synthetic credentials are passed to subprocesses; do not dump inherited env.
    throw new Error(`${path.basename(file)} failed (${error.code}): ${error.stdout || ''}\n${error.stderr || ''}`);
  }
}
async function control(args) {
  // A Windows PostgreSQL child may retain pipes after pg_ctl exits. Do not wait
  // on inherited output handles; diagnostics are written to postgres.log.
  await new Promise((resolve, reject) => {
    const child = spawn(binary('pg_ctl'), args, { windowsHide: true, stdio: 'ignore' });
    child.once('error', reject);
    child.once('exit', code => code === 0 ? resolve() : reject(new Error(`pg_ctl failed (${code}); inspect postgres.log`)));
  });
}
async function main() {
  if (!fs.existsSync(binary('initdb'))) throw new Error('PostgreSQL binaries unavailable: set PG_BIN to a directory containing initdb and pg_ctl');
  const port = await new Promise(resolve => {
    const server = net.createServer();
    server.listen(0, '127.0.0.1', () => { const port = server.address().port; server.close(() => resolve(port)); });
  });
  await run(binary('initdb'), ['-D', data, '-U', 'activ_integration', '--auth-local=trust', '--auth-host=trust', '--encoding=UTF8', '--locale=C']);
  await control(['-D', data, '-l', path.join(directory, 'postgres.log'), '-o', `-h 127.0.0.1 -p ${port}`, '-w', 'start']);
  started = true;
  const connectionString = `postgresql://activ_integration@127.0.0.1:${port}/activ_integration_test`;
  client = new Client({ host: '127.0.0.1', port, user: 'activ_integration', database: 'postgres' });
  await client.connect();
  await client.query('CREATE DATABASE activ_integration_test');
  await client.end();
  client = new Client({ connectionString });
  await client.connect();
  const env = { ...process.env, APP_ENV: 'production', NODE_ENV: 'test', DATABASE_URL: connectionString,
    DIRECT_URL: connectionString, DB_HOST: '127.0.0.1', DB_PORT: String(port), DB_SSL: 'false',
    ACTIV_PG_TEST_URL: connectionString, ACTIV_PG_TEST_MARKER: marker };
  const prisma = args => run(process.execPath, ['node_modules/prisma/build/index.js', ...args, '--config', './prisma7.config.ts'], env);
  // The repository starts with ALTER TABLE migrations, not an initial baseline.
  // Build a synthetic prior schema, then apply the actual additive email migration.
  const schema = fs.readFileSync(path.join(root, 'prisma/schema.prisma'), 'utf8')
    .replace(/model (email_deliveries|google_oauth_credentials) \{[\s\S]*?\n\}/g, '');
  const baseline = path.join(directory, 'prior.prisma');
  fs.writeFileSync(baseline, schema);
  const referenceSql = ['20261020_booking_reference', '20261023_public_references'].map(name =>
    fs.readFileSync(path.join(root, 'prisma/migrations', name, 'migration.sql'), 'utf8')).join('\n');
  const sequences = referenceSql.match(/CREATE SEQUENCE[^;]+;/g) || [];
  const functions = referenceSql.match(/CREATE OR REPLACE FUNCTION[\s\S]*?\$\$;/g) || [];
  await client.query([...sequences, ...functions].join('\n'));
  const diff = await prisma(['migrate', 'diff', '--from-empty', '--to-schema', baseline, '--script']);
  await client.query(diff.stdout);
  console.log('Synthetic prior schema created in the isolated cluster; marking historical migration receipts.');
  const history = fs.readdirSync(path.join(root, 'prisma/migrations')).filter(name =>
    fs.existsSync(path.join(root, 'prisma/migrations', name, 'migration.sql'))).sort();
  const additions = ['20261029000000_email_deliveries', '20261029010000_google_oauth_credentials'];
  for (const name of history.filter(name => !additions.includes(name))) {
    await prisma(['migrate', 'resolve', '--applied', name]);
  }
  await prisma(['migrate', 'deploy']);
  await prisma(['migrate', 'status']);
  await prisma(['migrate', 'deploy']); // Second deploy must be a no-op.
  await client.query('CREATE TABLE activ_integration_guard (marker TEXT NOT NULL)');
  await client.query('INSERT INTO activ_integration_guard VALUES ($1)', [marker]);
  await client.end(); client = null;
  console.log('Isolated PostgreSQL ready; additive migration applied and repeat deploy verified.');
  const result = await run(process.execPath, ['node_modules/jest/bin/jest.js', '--config', 'test/postgres/jest.config.cjs', '--runInBand', '--no-cache'], env);
  process.stdout.write(result.stdout); process.stderr.write(result.stderr);
}
main().catch(error => { console.error(error.message); process.exitCode = 1; }).finally(async () => {
  if (client) await client.end().catch(() => {});
  if (started) {
    try { await control(['-D', data, '-m', 'fast', '-w', 'stop']); }
    catch { console.error('Temporary PostgreSQL shutdown failed; inspect the isolated cluster.'); process.exitCode = 1; }
  }
  // Keep logs/data for inspection. Never delete or stop an existing service.
  console.log(`Temporary cluster files (stopped after tests): ${directory}`);
});
