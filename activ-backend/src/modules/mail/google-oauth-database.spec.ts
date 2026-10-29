import * as google from 'googleapis/build/src/apis/gmail';
import { GoogleOAuthService } from './google-oauth.service';
import { GoogleCredentialError } from './google-credential.store';
import { ConfigService } from '@nestjs/config';
import * as fs from 'fs';

jest.mock('googleapis/build/src/apis/gmail', () => ({ auth: { OAuth2: jest.fn() }, gmail: jest.fn() }));

describe('database Gmail OAuth lifecycle (Google APIs mocked)', () => {
  let service: GoogleOAuthService;
  let settings: Record<string, any>;
  let client: any, store: any, identity: any, send: jest.Mock, listener: any;
  const message = { recipientEmail: 'partner@example.invalid', subject: 'Test', text: 'Test' };
  beforeEach(() => {
    settings = { GOOGLE_TOKEN_SOURCE: 'database', GOOGLE_SENDER_EMAIL: 'support@activ.live', GOOGLE_CLIENT_ID: 'mock-client', GOOGLE_CLIENT_SECRET: 'PRIVATE-CLIENT-SECRET',
      GOOGLE_REFRESH_TOKEN_STORAGE_KEY: 'mock-storage-key-'.repeat(3), GOOGLE_OAUTH_SETUP_ENABLED: 'true', GOOGLE_OAUTH_SETUP_KEY: 'mock-setup-key-'.repeat(3) };
    identity = { sub: 'subject', email: 'support@activ.live', email_verified: true, hd: 'activ.live' };
    store = { find: jest.fn().mockResolvedValue(undefined), validateKey: jest.fn(), load: jest.fn().mockResolvedValue(undefined),
      saveVerified: jest.fn().mockResolvedValue({ version: 1 }), rotate: jest.fn(), markReauthorizationRequired: jest.fn() };
    client = { generateAuthUrl: jest.fn().mockReturnValue('https://accounts.google.com/mock'),
      getToken: jest.fn().mockResolvedValue({ tokens: { refresh_token: 'PRIVATE-NEW-TOKEN', id_token: 'PRIVATE-ID-TOKEN', scope: 'openid email https://www.googleapis.com/auth/gmail.send' } }),
      verifyIdToken: jest.fn(async () => ({ getPayload: () => ({ nonce: client.generateAuthUrl.mock.calls.at(-1)[0].nonce, ...identity }) })),
      setCredentials: jest.fn(), getAccessToken: jest.fn().mockResolvedValue({ token: 'PRIVATE-ACCESS-TOKEN' }), on: jest.fn((event, handler) => { listener = handler; }) };
    send = jest.fn().mockResolvedValue({ data: { id: 'mock-message' } });
    (google.auth.OAuth2 as any).mockImplementation(() => client);
    (google.gmail as any).mockReturnValue({ users: { messages: { send } } });
    service = new GoogleOAuthService({ get: (key, fallback) => settings[key] ?? fallback } as ConfigService, store);
  });
  async function start() { await service.createAuthorizationUrl(settings.GOOGLE_OAUTH_SETUP_KEY); return client.generateAuthUrl.mock.calls.at(-1)[0].state; }
  function configured() { store.load.mockResolvedValue({ token: 'PRIVATE-EXISTING-TOKEN', row: { id: 'id', version: 3, sender: 'support@activ.live', created_at: new Date(), verified_at: new Date() } }); }

  it('never creates a credential during startup and reports missing setup', async () => {
    await service.onModuleInit();
    expect(store.saveVerified).not.toHaveBeenCalled();
    expect(client.getToken).not.toHaveBeenCalled();
    expect(await service.credentialStatus()).toMatchObject({ status: 'NOT_CONFIGURED', verified: false });
  });
  it('persists before reporting verified setup, without filesystem writes', async () => {
    const write = jest.spyOn(fs, 'writeFileSync');
    const state = await start();
    const response = await service.completeAuthorization('mock-code', state);
    expect(response).toEqual({ email: 'support@activ.live', verified: true });
    expect(store.saveVerified).toHaveBeenCalledWith('support@activ.live', 'mock-client', 'subject', 'PRIVATE-NEW-TOKEN', null);
    expect(write).not.toHaveBeenCalled(); write.mockRestore();
    expect(JSON.stringify(response)).not.toContain('PRIVATE');
  });
  it.each(['email', 'email_verified', 'hd', 'nonce', 'sub'])('rejects invalid sender identity claim %s without replacing storage', async claim => {
    if (claim === 'email') identity.email = 'wrong@example.invalid';
    else if (claim === 'email_verified') identity.email_verified = false;
    else identity[claim] = '';
    await expect(service.completeAuthorization('mock-code', await start())).rejects.toThrow('SENDER_IDENTITY_MISMATCH');
    expect(store.saveVerified).not.toHaveBeenCalled();
  });
  it('rejects invalid signature/audience verification and missing identity/send scope', async () => {
    client.verifyIdToken.mockRejectedValueOnce(new Error('PRIVATE-ID-TOKEN'));
    await expect(service.completeAuthorization('mock-code', await start())).rejects.toThrow('IDENTITY_VERIFICATION_FAILED');
    client.getToken.mockResolvedValueOnce({ tokens: { refresh_token: 'PRIVATE-NEW-TOKEN' } });
    await expect(service.completeAuthorization('mock-code', await start())).rejects.toThrow('IDENTITY_OR_SEND_SCOPE_MISSING');
    expect(store.saveVerified).not.toHaveBeenCalled();
  });
  it('does not retain a replacement when persistence fails', async () => {
    store.saveVerified.mockRejectedValueOnce(new GoogleCredentialError('PERSISTENCE_FAILED'));
    await expect(service.completeAuthorization('mock-code', await start())).rejects.toThrow('PERSISTENCE_FAILED');
    expect(service.hasRefreshToken()).toBe(false);
    expect((service as any).runtimeRefreshToken).toBeUndefined();
  });
  it('consumes state once, rejects expiry, and disables an already-started callback when setup is turned off', async () => {
    const state = await start(); await service.completeAuthorization('mock-code', state);
    await expect(service.completeAuthorization('mock-code', state)).rejects.toThrow('Invalid or expired');
    const expired = await start(); (service as any).states.get(expired).expiresAt = Date.now() - 1;
    await expect(service.completeAuthorization('mock-code', expired)).rejects.toThrow('Invalid or expired');
    const disabled = await start(); settings.GOOGLE_OAUTH_SETUP_ENABLED = 'false';
    await expect(service.completeAuthorization('mock-code', disabled)).rejects.toThrow('setup is disabled');
  });
  it.each(['environment', 'file', 'database'])('detects a conflicting %s token source', async source => {
    if (source === 'environment') settings.GOOGLE_REFRESH_TOKEN = 'PRIVATE-OLD-TOKEN';
    if (source === 'file') settings.GOOGLE_REFRESH_TOKEN_FILE = '/not-mounted/credential.enc';
    if (source === 'database') { settings.GOOGLE_TOKEN_SOURCE = 'env'; settings.GOOGLE_REFRESH_TOKEN = 'PRIVATE-OLD-TOKEN'; store.find.mockResolvedValue({ version: 1 }); }
    await expect(service.sendEmail(message)).rejects.toThrow('Conflicting Google token sources');
    expect(send).not.toHaveBeenCalled();
  });
  it('recovers from a transient database outage on a later send', async () => {
    store.find.mockRejectedValueOnce(new GoogleCredentialError('DATABASE_UNAVAILABLE'));
    await service.onModuleInit();
    configured(); await expect(service.sendEmail(message)).resolves.toBe('mock-message');
    expect(store.saveVerified).not.toHaveBeenCalled();
  });
  it('preserves storage when a normal refresh omits a replacement token', async () => {
    configured();
    client.getAccessToken.mockImplementationOnce(async () => { listener({ access_token: 'PRIVATE-ACCESS-TOKEN' }); return { token: 'PRIVATE-ACCESS-TOKEN' }; });
    await service.sendEmail(message);
    expect(store.rotate).not.toHaveBeenCalled();
    expect(client.setCredentials).toHaveBeenCalledWith({ refresh_token: 'PRIVATE-EXISTING-TOKEN' });
  });
  it('persists refresh-token rotation before sending', async () => {
    configured();
    client.getAccessToken.mockImplementationOnce(async () => { listener({ refresh_token: 'PRIVATE-ROTATED-TOKEN' }); return { token: 'PRIVATE-ACCESS-TOKEN' }; });
    await service.sendEmail(message);
    expect(store.rotate).toHaveBeenCalledWith(expect.objectContaining({ version: 3 }), 'PRIVATE-ROTATED-TOKEN');
    expect(store.rotate.mock.invocationCallOrder[0]).toBeLessThan(send.mock.invocationCallOrder[0]);
  });
  it('does not send on failed rotation persistence and never leaks provider refresh errors', async () => {
    configured();
    client.getAccessToken.mockImplementationOnce(async () => { listener({ refresh_token: 'PRIVATE-ROTATED-TOKEN' }); return { token: 'PRIVATE-ACCESS-TOKEN' }; });
    store.rotate.mockRejectedValueOnce(new GoogleCredentialError('PERSISTENCE_FAILED'));
    await expect(service.sendEmail(message)).rejects.toThrow('PERSISTENCE_FAILED');
    expect(send).not.toHaveBeenCalled();
    client.getAccessToken.mockRejectedValueOnce(new Error('PRIVATE-CLIENT-SECRET'));
    await expect(service.sendEmail(message)).rejects.toThrow('TOKEN_REFRESH_UNAVAILABLE');
  });
  it('recovers a pending rotation after a transient persistence failure before another send', async () => {
    configured();
    client.getAccessToken.mockImplementationOnce(async () => { listener({ refresh_token: 'PRIVATE-ROTATED-TOKEN' }); return { token: 'PRIVATE-ACCESS-TOKEN' }; });
    store.rotate.mockRejectedValueOnce(new GoogleCredentialError('PERSISTENCE_FAILED'));
    await expect(service.sendEmail(message)).rejects.toThrow('PERSISTENCE_FAILED');
    await expect(service.sendEmail(message)).resolves.toBe('mock-message');
    expect(client.setCredentials).toHaveBeenLastCalledWith({ refresh_token: 'PRIVATE-ROTATED-TOKEN' });
    expect(store.rotate).toHaveBeenCalledTimes(2);
    expect(send).toHaveBeenCalledTimes(1);
  });
  it('treats a late rotation persistence failure after Gmail acceptance as uncertain', async () => {
    configured();
    send.mockImplementationOnce(async () => { listener({ refresh_token: 'PRIVATE-LATE-ROTATION' }); return { data: { id: 'accepted' } }; });
    store.rotate.mockRejectedValueOnce(new GoogleCredentialError('PERSISTENCE_FAILED'));
    const error = await service.sendEmail(message).catch(error => error);
    expect(error.message).toBe('Gmail delivery outcome requires operator review');
    expect(error.status).toBeUndefined(); // Durable delivery must not auto-replay acceptance.
  });
  it('allows empty legacy token env settings in database mode without selecting a file', async () => {
    settings.GOOGLE_REFRESH_TOKEN_FILE = '';
    settings.GOOGLE_REFRESH_TOKEN = '';
    await expect(service.onModuleInit()).resolves.toBeUndefined();
    expect(await service.credentialStatus()).toMatchObject({ status: 'NOT_CONFIGURED', verified: false });
  });
  it('marks only the current credential revoked and requests explicit reauthorization', async () => {
    configured(); client.getAccessToken.mockRejectedValueOnce({ response: { data: { error: 'invalid_grant', error_description: 'PRIVATE-TOKEN' } } });
    await expect(service.sendEmail(message)).rejects.toThrow('REAUTHORIZATION_REQUIRED');
    expect(store.markReauthorizationRequired).toHaveBeenCalledWith(expect.objectContaining({ version: 3 }));
    expect(send).not.toHaveBeenCalled(); expect(client.getToken).not.toHaveBeenCalled();
  });
  it('returns allowlisted status only and sanitizes Gmail delivery errors', async () => {
    configured();
    const status = JSON.stringify(await service.credentialStatus());
    expect(status).toContain('VERIFIED'); expect(status).not.toContain('PRIVATE'); expect(status).not.toContain('encrypted');
    send.mockRejectedValueOnce({ response: { status: 429, data: 'PRIVATE-ERROR-BODY' }, config: { client_secret: 'PRIVATE-CLIENT-SECRET' } });
    await expect(service.sendEmail(message)).rejects.toMatchObject({ message: 'Gmail delivery was not confirmed', status: 429 });
  });
});
