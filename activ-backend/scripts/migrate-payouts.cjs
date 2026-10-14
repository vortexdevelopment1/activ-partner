require('ts-node/register');
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');
const { randomUUID } = require('crypto');
const { Client } = require('pg');
const { getMigrationDatabaseUrlFromEnv } = require('../src/config/database.config');
const root = path.resolve(__dirname, '..');
const readEnv = (name) => fs.existsSync(path.join(root, name)) ? dotenv.parse(fs.readFileSync(path.join(root, name))) : {};
const client = new Client({ connectionString: getMigrationDatabaseUrlFromEnv({ ...process.env, ...readEnv('.env'), ...readEnv('.env.local') }), connectionTimeoutMillis: 10000 });

async function main() {
  const execute = process.argv.includes('--execute'), verify = process.argv.includes('--verify');
  if (!execute && !verify && !process.argv.includes('--check')) throw new Error('Use --check, --execute or --verify');
  await client.connect();
  await client.query('BEGIN');
  try {
    await client.query("SET LOCAL lock_timeout = '10s'");
    await client.query("SELECT pg_advisory_xact_lock(hashtext('partner_payouts'))");
    if (verify) {
      const partnerId = randomUUID(), otherId = randomUUID();
      await client.query('INSERT INTO partners (id, legal_name, updated_at) VALUES ($1, $2, NOW()), ($3, $2, NOW())', [partnerId, 'Payout test', otherId]);
      await client.query(`INSERT INTO partner_payouts (id, partner_id, reference, amount_paise, status, payout_date, updated_at)
        VALUES ($1::uuid, $2::uuid, $1::text, 12000, 'SUCCESS', '2026-10-10 09:00:00', NOW()),
               ($3::uuid, $2::uuid, $3::text, 5000, 'PENDING', '2026-10-10 09:00:00', NOW()),
               ($4::uuid, $5::uuid, $4::text, 9900, 'SUCCESS', '2026-10-10 09:00:00', NOW())`,
        [randomUUID(), partnerId, randomUUID(), randomUUID(), otherId]);
      const result = await client.query(`SELECT count(*) AS count, sum(amount_paise) AS credited FROM partner_payouts
        WHERE partner_id = $1 AND status = 'SUCCESS' AND payout_date >= '2026-10-09' AND payout_date < '2026-10-11'`, [partnerId]);
      if (result.rows[0].count !== '1' || result.rows[0].credited !== '12000') throw new Error('Payout filtering verification failed');
      await client.query('ROLLBACK');
      console.log('Database payout storage, ownership, filters and credited total verified; test records rolled back.');
      return;
    }
    await client.query(fs.readFileSync(path.join(root, 'prisma/migrations/20261010_partner_payouts/migration.sql'), 'utf8'));
    await client.query(execute ? 'COMMIT' : 'ROLLBACK');
    console.log(execute ? 'Payout schema applied.' : 'Payout schema validated; changes rolled back.');
  } catch (error) { await client.query('ROLLBACK'); throw error; }
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; }).finally(() => client.end());
