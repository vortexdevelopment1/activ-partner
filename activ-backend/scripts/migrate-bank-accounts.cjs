require('ts-node/register');
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');
const { Client } = require('pg');
const { randomUUID } = require('crypto');
const { getMigrationDatabaseUrlFromEnv } = require('../src/config/database.config');

const root = path.resolve(__dirname, '..');
const readEnv = (file) => fs.existsSync(file) ? dotenv.parse(fs.readFileSync(file)) : {};
const env = { ...process.env, ...readEnv(path.join(root, '.env')), ...readEnv(path.join(root, '.env.local')) };
const client = new Client({ connectionString: getMigrationDatabaseUrlFromEnv(env), connectionTimeoutMillis: 10000 });

async function main() {
  const execute = process.argv.includes('--execute');
  const verify = process.argv.includes('--verify');
  if (!execute && !verify && !process.argv.includes('--check')) throw new Error('Specify --check, --execute or --verify');
  await client.connect();
  await client.query('BEGIN');
  try {
    await client.query("SET LOCAL lock_timeout = '10s'");
    if (verify) {
      const partnerId = randomUUID(), bankId = randomUUID();
      await client.query('INSERT INTO partners (id, legal_name, updated_at) VALUES ($1, $2, NOW())', [partnerId, 'Bank persistence test']);
      await client.query(`INSERT INTO partner_bank_accounts
        (id, partner_id, account_holder_name, bank_name, account_number, ifsc_code,
         account_type, branch_name, cancelled_cheque_url, status, updated_at)
        VALUES ($1, $2, 'Test Holder', 'Test Bank', '1234567890', 'HDFC0001234',
          'Saving Account', 'Test Branch', '/test-cheque.pdf', 'UNDER_REVIEW', NOW())`, [bankId, partnerId]);
      const result = await client.query(`SELECT account_type, branch_name, cancelled_cheque_url, status
        FROM partner_bank_accounts WHERE id = $1 AND partner_id = $2`, [bankId, partnerId]);
      const account = result.rows[0];
      if (!account || account.account_type !== 'Saving Account' || account.branch_name !== 'Test Branch' ||
          account.cancelled_cheque_url !== '/test-cheque.pdf' || account.status !== 'UNDER_REVIEW') {
        throw new Error('Bank account persistence verification failed');
      }
      await client.query('ROLLBACK');
      console.log('Database bank-account write/read verified; test records rolled back.');
      return;
    }
    await client.query("SELECT pg_advisory_xact_lock(hashtext('bank_account_details'))");
    await client.query(fs.readFileSync(path.join(root, 'prisma/migrations/20261010_bank_account_details/migration.sql'), 'utf8'));
    await client.query(execute ? 'COMMIT' : 'ROLLBACK');
    console.log(execute ? 'Bank account schema updated.' : 'Schema validation passed; transaction rolled back.');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  }
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; }).finally(() => client.end());
