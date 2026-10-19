import * as google from 'googleapis/build/src/apis/gmail';
import { GoogleOAuthService } from './google-oauth.service';

jest.mock('googleapis/build/src/apis/gmail', () => ({
  auth: { OAuth2: jest.fn() },
  gmail: jest.fn(),
}));

describe('GoogleOAuthService', () => {
  let service: GoogleOAuthService;
  let client: any;
  let gmail: any;
  const config: Record<string, string> = {
    GOOGLE_OAUTH_SETUP_ENABLED: 'true',
    GOOGLE_OAUTH_SETUP_KEY: 'a'.repeat(32),
    GOOGLE_CLIENT_ID: 'client-id',
    GOOGLE_CLIENT_SECRET: 'client-secret',
    GOOGLE_REDIRECT_URI: 'http://localhost:3000/api/v1/auth/google/callback',
    GOOGLE_SENDER_EMAIL: 'jangidlucky444@gmail.com',
  };

  beforeEach(() => {
    config.GOOGLE_OAUTH_SETUP_ENABLED = 'true';
    delete config.GOOGLE_REFRESH_TOKEN;
    client = {
      generateAuthUrl: jest.fn().mockReturnValue('https://accounts.google.com/o/oauth2/v2/auth?state=state'),
      getToken: jest.fn().mockResolvedValue({ tokens: { refresh_token: 'refresh-token' } }),
      setCredentials: jest.fn(),
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

  it('requires setup to be enabled and a strong setup key', () => {
    expect(() => service.createAuthorizationUrl('wrong')).toThrow();
    config.GOOGLE_OAUTH_SETUP_ENABLED = 'false';
    expect(() => service.createAuthorizationUrl('a'.repeat(32))).toThrow();
  });

  it('creates a consent URL with only gmail.send and validates the callback state', async () => {
    service.createAuthorizationUrl('a'.repeat(32));
    expect(client.generateAuthUrl).toHaveBeenCalledWith(expect.objectContaining({
      access_type: 'offline', prompt: 'consent',
      scope: ['https://www.googleapis.com/auth/gmail.send'],
    }));
    const state = [...(service as any).states.keys()][0];
    const result = await service.completeAuthorization('code', state);
    expect(result).toEqual({ email: 'jangidlucky444@gmail.com' });
    expect(client.setCredentials).toHaveBeenCalledWith({ refresh_token: 'refresh-token' });
    expect((result as any).refreshToken).toBeUndefined();
  });

  it('rejects invalid state and missing refresh tokens', async () => {
    await expect(service.completeAuthorization('code', 'not-valid')).rejects.toThrow('Invalid or expired Google OAuth state');
    service.createAuthorizationUrl('a'.repeat(32));
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
    });
  });
});
