import { ConfigService } from '@nestjs/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../../src/generated/prisma/client';
import { GoogleCredentialStore } from '../../src/modules/mail/google-credential.store';
import { GoogleOAuthService } from '../../src/modules/mail/google-oauth.service';
import * as google from 'googleapis/build/src/apis/gmail';
import { execFile } from 'child_process';
import { promisify } from 'util';

jest.mock('googleapis/build/src/apis/gmail', () => ({ auth: { OAuth2: jest.fn() }, gmail: jest.fn() }));
const sender = 'support@activ.live', clientId = 'postgres-oauth-test-client', token = 'SYNTHETIC-OAUTH-REFRESH-TOKEN';
const key = 'synthetic-postgres-google-storage-key-'.repeat(2);
describe('real PostgreSQL encrypted OAuth credentials', () => {
  let db: PrismaClient, store: GoogleCredentialStore, service: GoogleOAuthService, client: any;
  let config: ConfigService;
  beforeAll(async () => {
    const url = new URL(process.env.ACTIV_PG_TEST_URL || '');
    if (url.hostname !== '127.0.0.1' || url.pathname !== '/activ_integration_test' || url.username !== 'activ_integration' || !process.env.ACTIV_PG_TEST_MARKER) throw new Error('Isolated database required');
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: url.toString() }) });
    const rows = await db.$queryRaw<any[]>`SELECT marker FROM activ_integration_guard`;
    expect(rows[0]?.marker).toBe(process.env.ACTIV_PG_TEST_MARKER);
  });
  beforeEach(async () => {
    await db.google_oauth_credentials.deleteMany(); // Only this newly created, guarded cluster.
    const settings = { GOOGLE_TOKEN_SOURCE: 'database', GOOGLE_SENDER_EMAIL: sender, GOOGLE_CLIENT_ID: clientId,
      GOOGLE_CLIENT_SECRET: 'synthetic-secret', GOOGLE_REFRESH_TOKEN_STORAGE_KEY: key, GOOGLE_OAUTH_SETUP_ENABLED: 'true', GOOGLE_OAUTH_SETUP_KEY: key };
    config = { get: (name, fallback) => settings[name] ?? fallback } as ConfigService;
    store = new GoogleCredentialStore(db as any, config);
    client = { generateAuthUrl: jest.fn().mockReturnValue('https://accounts.google.com/mocked-not-opened'),
      getToken: jest.fn().mockResolvedValue({ tokens: { refresh_token: token, id_token: 'synthetic-id-token', scope: 'openid email https://www.googleapis.com/auth/gmail.send' } }),
      verifyIdToken: jest.fn(async () => ({ getPayload: () => ({ sub: 'google-subject', email: sender, email_verified: true, hd: 'activ.live', nonce: client.generateAuthUrl.mock.calls.slice(-1)[0][0].nonce }) })) };
    (google.auth.OAuth2 as any).mockImplementation(() => client);
    service = new GoogleOAuthService(config, store);
  });
  afterAll(async () => { await db?.$disconnect(); });
  async function connect() { await service.createAuthorizationUrl(key); return client.generateAuthUrl.mock.calls.slice(-1)[0][0].state; }

  it('applies both additive migrations and does not persist credentials during startup', async () => {
    const receipts = await db.$queryRaw<any[]>`SELECT migration_name FROM _prisma_migrations WHERE migration_name IN ('20261029000000_email_deliveries', '20261029010000_google_oauth_credentials') AND finished_at IS NOT NULL`;
    expect(receipts).toHaveLength(2);
    await service.onModuleInit();
    expect(await db.google_oauth_credentials.count()).toBe(0);
    expect(await service.credentialStatus()).toMatchObject({ status: 'NOT_CONFIGURED', verified: false });
  });
  it('persists verified encrypted credentials through the real callback service and recovers in a fresh OS process', async () => {
    await service.completeAuthorization('synthetic-code', await connect());
    const row = await db.google_oauth_credentials.findFirst();
    expect(row.status).toBe('VERIFIED'); expect(JSON.stringify(row)).not.toContain(token);
    expect((await store.load(sender, clientId)).token).toBe(token);
    const result = await promisify(execFile)(process.execPath, ['test/postgres/restart-google-worker.cjs'], {
      cwd: process.cwd(), windowsHide: true, env: { ...process.env, ACTIV_PG_GOOGLE_KEY: key, ACTIV_PG_GOOGLE_EXPECTED: token },
    });
    expect(result.stdout).toContain('Verified database credential recovered in fresh process');
    expect(result.stdout).not.toContain(token);
    expect(await db.google_oauth_credentials.count()).toBe(1);
  });
  it('uses real unique constraints and compare-and-set revisions for concurrent creates and updates', async () => {
    const initial = await Promise.allSettled([store.saveVerified(sender, clientId, 'google-subject', token, null), store.saveVerified(sender, clientId, 'google-subject', token, null)]);
    expect(initial.filter(result => result.status === 'fulfilled')).toHaveLength(1);
    const updates = await Promise.allSettled(['synthetic-update-A', 'synthetic-update-B'].map(value => store.saveVerified(sender, clientId, 'google-subject', value, 1)));
    expect(updates.filter(result => result.status === 'fulfilled')).toHaveLength(1);
    expect(await db.google_oauth_credentials.count()).toBe(1);
    expect((await store.load(sender, clientId)).row.version).toBe(2);
  });
  it('does not replace the valid credential when sender verification fails', async () => {
    await store.saveVerified(sender, clientId, 'google-subject', token, null);
    client.verifyIdToken.mockResolvedValueOnce({ getPayload: () => ({ sub: 'unexpected', email: 'wrong@example.invalid', email_verified: true }) });
    await expect(service.completeAuthorization('synthetic-code', await connect())).rejects.toThrow('SENDER_IDENTITY_MISMATCH');
    expect((await store.load(sender, clientId)).token).toBe(token);
    expect((await store.load(sender, clientId)).row.version).toBe(1);
  });
  it('fails closed on PostgreSQL write failure without damaging an existing grant', async () => {
    await store.saveVerified(sender, clientId, 'google-subject', token, null);
    const readOnly = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.ACTIV_PG_TEST_URL, options: '-c default_transaction_read_only=on' }) });
    try {
      const protectedService = new GoogleOAuthService(config, new GoogleCredentialStore(readOnly as any, config));
      await protectedService.createAuthorizationUrl(key);
      const state = client.generateAuthUrl.mock.calls.slice(-1)[0][0].state;
      await expect(protectedService.completeAuthorization('synthetic-code', state)).rejects.toThrow('PERSISTENCE_FAILED');
      expect((await store.load(sender, clientId)).token).toBe(token);
      expect((await store.load(sender, clientId)).row.version).toBe(1);
    } finally { await readOnly.$disconnect(); }
  });
  it('rejects ciphertext tampering and wrong keys after real persistence', async () => {
    const row = await store.saveVerified(sender, clientId, 'google-subject', token, null);
    const wrongKey = new GoogleCredentialStore(db as any, { get: () => 'another-wrong-storage-key-'.repeat(3) } as any);
    await expect(wrongKey.load(sender, clientId)).rejects.toThrow('CREDENTIAL_UNREADABLE');
    await db.google_oauth_credentials.update({ where: { id: row.id }, data: { account_subject: 'tampered-subject' } });
    await expect(store.load(sender, clientId)).rejects.toThrow('CREDENTIAL_UNREADABLE');
  });
  it('preserves the rotated credential against an invalid_grant from an older request', async () => {
    const row = await store.saveVerified(sender, clientId, 'google-subject', token, null);
    await store.rotate(row, 'synthetic-rotated-token');
    await store.markReauthorizationRequired(row);
    const current = await store.load(sender, clientId);
    expect(current.token).toBe('synthetic-rotated-token'); expect(current.row.status).toBe('VERIFIED');
    await store.markReauthorizationRequired(current.row);
    await expect(store.load(sender, clientId)).rejects.toThrow('REAUTHORIZATION_REQUIRED');
    expect((await db.google_oauth_credentials.findFirst()).encrypted_refresh_token).toBeTruthy();
  });
});
