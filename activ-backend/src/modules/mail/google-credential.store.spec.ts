import { ConfigService } from '@nestjs/config';
import { GoogleCredentialStore } from './google-credential.store';

describe('encrypted Google credential store', () => {
  let row: any;
  let table: any;
  let store: GoogleCredentialStore;
  const settings = { GOOGLE_REFRESH_TOKEN_STORAGE_KEY: 'oauth-test-separate-key-'.repeat(3) };
  beforeEach(() => {
    row = undefined;
    settings.GOOGLE_REFRESH_TOKEN_STORAGE_KEY = 'oauth-test-separate-key-'.repeat(3);
    table = {
      findUnique: jest.fn(async () => row && structuredClone(row)),
      create: jest.fn(async ({ data }) => {
        if (row) throw { code: 'P2002' };
        row = { ...data, created_at: new Date(), updated_at: new Date() }; return structuredClone(row);
      }),
      updateMany: jest.fn(async ({ where, data }) => {
        if (!row || row.version !== where.version || (where.status && row.status !== where.status)) return { count: 0 };
        row = { ...row, ...data, version: row.version + 1 }; return { count: 1 };
      }),
    };
    const db: any = { google_oauth_credentials: table };
    db.$transaction = async callback => callback(db);
    store = new GoogleCredentialStore(db, { get: key => settings[key] } as ConfigService);
  });
  const save = () => store.saveVerified('support@activ.live', 'client-id', 'subject', 'PRIVATE-REFRESH-TOKEN', null);

  it('uses a versioned authenticated envelope and decrypts only in memory', async () => {
    await save();
    expect(JSON.parse(row.encrypted_refresh_token)).toMatchObject({ version: 1, iv: expect.any(String), tag: expect.any(String) });
    expect(JSON.stringify(row)).not.toContain('PRIVATE-REFRESH-TOKEN');
    expect((await store.load('support@activ.live', 'client-id')).token).toBe('PRIVATE-REFRESH-TOKEN');
    expect(Object.keys(row)).not.toEqual(expect.arrayContaining(['access_token', 'client_secret', 'authorization_code']));
  });
  it.each(['ciphertext', 'subject', 'version', 'key'])('rejects tampered %s without disclosing values', async part => {
    await save();
    if (part === 'ciphertext') { const value = JSON.parse(row.encrypted_refresh_token); value.value = Buffer.from('tampered').toString('base64'); row.encrypted_refresh_token = JSON.stringify(value); }
    if (part === 'subject') row.account_subject = 'another-subject';
    if (part === 'version') { const value = JSON.parse(row.encrypted_refresh_token); value.version = 99; row.encrypted_refresh_token = JSON.stringify(value); }
    if (part === 'key') settings.GOOGLE_REFRESH_TOKEN_STORAGE_KEY = 'incorrect-separate-key-'.repeat(3);
    await expect(store.load('support@activ.live', 'client-id')).rejects.toThrow('CREDENTIAL_UNREADABLE');
  });
  it.each(['', ' ', 'incomplete response', undefined])('rejects an invalid replacement', async token => {
    await save(); const before = structuredClone(row);
    await expect(store.saveVerified('support@activ.live', 'client-id', 'subject', token, 1)).rejects.toThrow();
    expect(row).toEqual(before);
  });
  it('requires the matching OAuth client and exposes missing storage as missing', async () => {
    expect(await store.load('support@activ.live', 'client-id')).toBeUndefined();
    await save();
    await expect(store.load('support@activ.live', 'other-client')).rejects.toThrow('OAUTH_CLIENT_MISMATCH');
  });
  it('sanitizes database errors and leaves an existing credential intact', async () => {
    await save(); const before = structuredClone(row);
    table.findUnique.mockRejectedValueOnce(new Error('PRIVATE-CONNECTION-PASSWORD'));
    await expect(store.find('support@activ.live')).rejects.toThrow('DATABASE_UNAVAILABLE');
    table.updateMany.mockRejectedValueOnce(new Error('PRIVATE-QUERY-ARGS'));
    await expect(store.saveVerified('support@activ.live', 'client-id', 'subject', 'replacement-token', 1)).rejects.toThrow('PERSISTENCE_FAILED');
    expect(row).toEqual(before);
  });
  it('accepts only one concurrent initial credential and one versioned update', async () => {
    const initial = await Promise.allSettled([save(), save()]);
    expect(initial.filter(result => result.status === 'fulfilled')).toHaveLength(1);
    const snapshot = structuredClone(row);
    const updates = await Promise.allSettled(['rotation-A', 'rotation-B'].map(token => store.rotate(snapshot, token)));
    expect(updates.filter(result => result.status === 'fulfilled')).toHaveLength(1);
    expect(row.version).toBe(2);
    expect((await store.load('support@activ.live', 'client-id')).token).toBe('rotation-A');
  });
  it('never marks a newer credential revoked using a stale revision', async () => {
    await save(); const old = structuredClone(row);
    await store.rotate(old, 'replacement-token');
    await store.markReauthorizationRequired(old);
    expect(row.status).toBe('VERIFIED');
    await store.markReauthorizationRequired(row);
    expect(row.status).toBe('REAUTH_REQUIRED');
    expect(row.encrypted_refresh_token).toBeTruthy();
    await expect(store.load('support@activ.live', 'client-id')).rejects.toThrow('REAUTHORIZATION_REQUIRED');
  });
});
