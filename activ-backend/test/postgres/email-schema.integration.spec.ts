import { Client } from 'pg';
import { createHash } from 'crypto';
import { readFileSync } from 'fs';
import { resolve } from 'path';

describe('email storage additive migration catalog', () => {
  let db: Client;
  beforeAll(async () => {
    const url = new URL(process.env.ACTIV_PG_TEST_URL || '');
    if (url.hostname !== '127.0.0.1' || url.pathname !== '/activ_integration_test' ||
        url.username !== 'activ_integration' || !process.env.ACTIV_PG_TEST_MARKER) {
      throw new Error('Isolated test database required');
    }
    db = new Client({ connectionString: url.toString() });
    await db.connect();
    expect((await db.query('SELECT marker FROM activ_integration_guard')).rows[0].marker)
      .toBe(process.env.ACTIV_PG_TEST_MARKER);
  });
  afterAll(async () => { await db?.end(); });

  it('has all durable delivery columns, unique identity, retry index and status constraint', async () => {
    const columns = (await db.query(`SELECT column_name FROM information_schema.columns
      WHERE table_schema='public' AND table_name='email_deliveries' ORDER BY ordinal_position`)).rows.map(row => row.column_name);
    expect(columns).toEqual(['id', 'idempotency_key', 'provider', 'kind', 'payload', 'status', 'attempts',
      'next_attempt_at', 'locked_at', 'expires_at', 'provider_message_id', 'error_code', 'created_at', 'updated_at', 'sent_at']);
    const indexes = (await db.query("SELECT indexname FROM pg_indexes WHERE schemaname='public' AND tablename='email_deliveries'"))
      .rows.map(row => row.indexname);
    expect(indexes).toEqual(expect.arrayContaining(['email_deliveries_pkey',
      'email_deliveries_idempotency_key_key', 'email_deliveries_status_next_attempt_at_idx']));
    const constraints = (await db.query(`SELECT contype, conname FROM pg_constraint
      WHERE conrelid='public.email_deliveries'::regclass`)).rows;
    expect(constraints).toContainEqual(expect.objectContaining({ conname: 'email_deliveries_status_check', contype: 'c' }));
    // Deliberately no partner/venue FK: deletion notices must survive account removal.
    expect(constraints.some(row => row.contype === 'f')).toBe(false);
  });

  it('has OAuth identity/version/status checks and a unique provider/sender identity', async () => {
    const constraints = (await db.query(`SELECT conname FROM pg_constraint
      WHERE conrelid='public.google_oauth_credentials'::regclass`)).rows.map(row => row.conname);
    expect(constraints).toEqual(expect.arrayContaining(['google_oauth_credentials_pkey',
      'google_oauth_credentials_status_check', 'google_oauth_credentials_version_check', 'google_oauth_credentials_identity_check']));
    const indexes = (await db.query("SELECT indexname FROM pg_indexes WHERE schemaname='public' AND tablename='google_oauth_credentials'"))
      .rows.map(row => row.indexname);
    expect(indexes).toContain('google_oauth_credentials_provider_sender_key');
  });

  it('records both actual additive migration files as successfully applied', async () => {
    for (const name of ['20261029000000_email_deliveries', '20261029010000_google_oauth_credentials']) {
      const receipt = (await db.query('SELECT checksum, finished_at, rolled_back_at FROM _prisma_migrations WHERE migration_name=$1', [name])).rows;
      expect(receipt).toHaveLength(1);
      expect(receipt[0].finished_at).not.toBeNull();
      expect(receipt[0].rolled_back_at).toBeNull();
      const sql = readFileSync(resolve(__dirname, '../../prisma/migrations', name, 'migration.sql'));
      expect(receipt[0].checksum).toBe(createHash('sha256').update(sql).digest('hex'));
    }
  });
});
