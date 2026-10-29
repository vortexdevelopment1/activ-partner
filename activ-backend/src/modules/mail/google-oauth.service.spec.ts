import * as google from 'googleapis/build/src/apis/gmail';
import { GoogleOAuthService } from './google-oauth.service';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

jest.mock('googleapis/build/src/apis/gmail', () => ({
  auth: { OAuth2: jest.fn() },
  gmail: jest.fn(),
}));

describe('GoogleOAuthService', () => {
  let service: GoogleOAuthService;
  let client: any;
  let gmail: any;
  let directory: string;
  const config: Record<string, string> = {
    GOOGLE_OAUTH_SETUP_ENABLED: 'true',
    GOOGLE_OAUTH_SETUP_KEY: 'a'.repeat(32),
    GOOGLE_CLIENT_ID: 'client-id',
    GOOGLE_CLIENT_SECRET: 'client-secret',
    GOOGLE_REDIRECT_URI: 'http://localhost:3000/api/v1/auth/google/callback',
    GOOGLE_SENDER_EMAIL: 'support@activ.live',
  };

  beforeEach(() => {
    config.GOOGLE_OAUTH_SETUP_ENABLED = 'true';
    delete config.GOOGLE_REFRESH_TOKEN;
    delete config.GOOGLE_TOKEN_SOURCE;
    directory = fs.mkdtempSync(path.join(os.tmpdir(), 'activ-oauth-test-'));
    config.GOOGLE_REFRESH_TOKEN_FILE = path.join(directory, 'token.enc');
    config.GOOGLE_REFRESH_TOKEN_STORAGE_KEY = 'test-only-key-'.repeat(4);
    client = {
      generateAuthUrl: jest.fn().mockReturnValue('https://accounts.google.com/o/oauth2/v2/auth?state=state'),
      getToken: jest.fn().mockResolvedValue({ tokens: { refresh_token: 'refresh-token', id_token: 'mock-id-token', scope: 'openid email https://www.googleapis.com/auth/gmail.send' } }),
      setCredentials: jest.fn(),
      getAccessToken: jest.fn().mockResolvedValue({ token: 'mock-access' }),
      verifyIdToken: jest.fn().mockImplementation(async () => ({ getPayload: () => ({ sub: 'google-subject', email: 'support@activ.live', email_verified: true,
        hd: 'activ.live', nonce: client.generateAuthUrl.mock.calls.at(-1)[0].nonce }) })),
    };
    gmail = {
      users: {
        messages: { send: jest.fn().mockResolvedValue({ data: { id: 'message-id' } }) },
      },
    };
    (google.auth.OAuth2 as unknown as jest.Mock).mockImplementation(() => client);
    (google.gmail as jest.Mock).mockReturnValue(gmail);
    service = Object.assign(Object.create(GoogleOAuthService.prototype), {
      config: { get: (key: string, fallback?: string) => config[key] ?? fallback },
      states: new Map(),
      runtimeRefreshToken: undefined,
      logger: { log: jest.fn() },
    });
  });

  afterEach(() => { fs.rmSync(directory, { recursive: true, force: true }); });

  it('requires setup to be enabled and a strong setup key', async () => {
    await expect(service.createAuthorizationUrl('wrong')).rejects.toThrow();
    config.GOOGLE_OAUTH_SETUP_ENABLED = 'false';
    await expect(service.createAuthorizationUrl('a'.repeat(32))).rejects.toThrow();
  });

  it('requests minimal sending/account scopes and validates the callback state', async () => {
    await service.createAuthorizationUrl('a'.repeat(32));
    expect(client.generateAuthUrl).toHaveBeenCalledWith(expect.objectContaining({
      access_type: 'offline', prompt: 'consent',
      scope: ['openid', 'email', 'https://www.googleapis.com/auth/gmail.send'],
    }));
    const state = [...(service as any).states.keys()][0];
    const result = await service.completeAuthorization('code', state);
    expect(result).toEqual({ email: 'support@activ.live', verified: true });
    expect(client.verifyIdToken).toHaveBeenCalledWith({ idToken: 'mock-id-token', audience: 'client-id' });
    expect((result as any).refreshToken).toBeUndefined();
  });

  it('rejects invalid state and missing refresh tokens', async () => {
    await expect(service.completeAuthorization('code', 'not-valid')).rejects.toThrow('Invalid or expired Google OAuth state');
    await service.createAuthorizationUrl('a'.repeat(32));
    const state = [...(service as any).states.keys()][0];
    client.getToken.mockResolvedValueOnce({ tokens: {} });
    await expect(service.completeAuthorization('code', state)).rejects.toThrow('did not return a refresh token');
  });

  it('sends a Gmail API message with a PDF attachment using the configured refresh token', async () => {
    config.GOOGLE_REFRESH_TOKEN = 'configured-token';
    const id = await service.sendEmail({
      recipientEmail: 'partner@example.com', subject: 'Agreement', text: 'Attached',
      pdfBuffer: Buffer.from('pdf'), filename: 'agreement.pdf',
    });
    expect(id).toBe('message-id');
    expect(client.setCredentials).toHaveBeenCalledWith({ refresh_token: 'configured-token' });
    expect(gmail.users.messages.send).toHaveBeenCalledWith({
      userId: 'me', requestBody: { raw: expect.any(String) },
    }, { timeout: 30000 });
  });

  it('encodes HTML, a plain-text alternative, embedded logo and agreement PDF together', async () => {
    config.GOOGLE_REFRESH_TOKEN = 'configured-token';
    await service.sendEmail({ recipientEmail: 'partner@example.com', subject: 'Agreement', text: 'Plain version',
      html: '<p>Signed agreement</p><img src="cid:logo">',
      inlineImages: [{ filename: 'logo.png', content: Buffer.from('logo'), contentType: 'image/png', cid: 'logo' }],
      pdfBuffer: Buffer.from('pdf'), filename: 'agreement.pdf' });
    const raw = Buffer.from(gmail.users.messages.send.mock.calls[0][0].requestBody.raw, 'base64url').toString();
    expect(raw).toContain('multipart/alternative');
    expect(raw).toContain('Content-Type: text/plain');
    expect(raw).toContain('Plain version');
    expect(raw).toContain('Content-Type: text/html');
    expect(raw).toContain('Signed agreement');
    expect(raw).toContain('Content-ID: <logo>');
    expect(raw).toContain('Content-Type: application/pdf');
    expect(raw).toMatch(/filename="?agreement\.pdf"?/);
  });

  it('persists encrypted tokens atomically and recovers after restart', async () => {
    await service.createAuthorizationUrl('a'.repeat(32));
    const state = [...(service as any).states.keys()][0];
    await service.completeAuthorization('code', state);
    const stored = fs.readFileSync(config.GOOGLE_REFRESH_TOKEN_FILE, 'utf8');
    expect(stored).not.toContain('refresh-token');
    expect(fs.readdirSync(directory)).toEqual(['token.enc']);
    const restarted = Object.assign(Object.create(GoogleOAuthService.prototype), {
      config: { get: (key: string, fallback?: string) => config[key] ?? fallback }, states: new Map(),
    });
    expect(restarted.hasRefreshToken()).toBe(true);
  });

  it('rejects conflicting environment/file token sources without printing their contents', () => {
    fs.writeFileSync(config.GOOGLE_REFRESH_TOKEN_FILE, 'encrypted');
    config.GOOGLE_REFRESH_TOKEN = 'PRIVATE_TOKEN';
    expect(() => service.hasRefreshToken()).toThrow('Conflicting Google token sources');
  });

  it('rejects corrupt storage rather than silently treating it as unconfigured', () => {
    fs.writeFileSync(config.GOOGLE_REFRESH_TOKEN_FILE, 'corrupt');
    expect(() => service.hasRefreshToken()).toThrow('Stored Google token is unreadable');
  });

  it('requires durable storage before starting authorization', async () => {
    delete config.GOOGLE_REFRESH_TOKEN_STORAGE_KEY;
    await expect(service.createAuthorizationUrl('a'.repeat(32))).rejects.toThrow('GOOGLE_REFRESH_TOKEN_STORAGE_KEY');
  });

  it('does not retain a usable runtime token after persistence failure', async () => {
    await service.createAuthorizationUrl('a'.repeat(32));
    const state = [...(service as any).states.keys()][0];
    const failure = jest.spyOn(fs, 'renameSync').mockImplementationOnce(() => { throw new Error('disk full'); });
    try {
      await expect(service.completeAuthorization('code', state)).rejects.toThrow('persistence failed');
      expect((service as any).runtimeRefreshToken).toBeUndefined();
      expect(fs.readdirSync(directory)).toEqual([]);
    } finally { failure.mockRestore(); }
  });
});
