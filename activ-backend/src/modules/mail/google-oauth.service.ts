import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
// Load only Gmail instead of the generated clients for every Google API.
import * as google from 'googleapis/build/src/apis/gmail';
import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'crypto';
import * as fs from 'fs';
import * as path from 'path';

type OAuthState = { expiresAt: number };

@Injectable()
export class GoogleOAuthService {
  private readonly logger = new Logger(GoogleOAuthService.name);
  private readonly states = new Map<string, OAuthState>();
  private runtimeRefreshToken?: string;

  constructor(private readonly config: ConfigService) {}

  private redirectUri(): string {
    const configured = this.config.get<string>('GOOGLE_REDIRECT_URI')?.trim();
    if (configured) return configured;
    return this.config.get<string>('APP_ENV') === 'production'
      ? 'https://activ-partner.onrender.com/api/v1/auth/google/callback'
      : 'http://localhost:3000/api/v1/auth/google/callback';
  }

  private client(): any {
    const clientId = this.config.get<string>('GOOGLE_CLIENT_ID')?.trim();
    const clientSecret = this.config.get<string>('GOOGLE_CLIENT_SECRET')?.trim();
    if (!clientId || !clientSecret) {
      throw new ServiceUnavailableException('Google OAuth is not configured on the backend.');
    }
    return new google.auth.OAuth2(clientId, clientSecret, this.redirectUri());
  }

  private tokenFile(): string {
    return this.config.get<string>('GOOGLE_REFRESH_TOKEN_FILE', './.secrets/google-refresh-token.enc');
  }

  private storageKey(): Buffer | null {
    const value = this.config.get<string>('GOOGLE_REFRESH_TOKEN_STORAGE_KEY')?.trim();
    return value && value.length >= 32 ? createHash('sha256').update(value).digest() : null;
  }

  private persistRefreshToken(token: string): void {
    const key = this.storageKey();
    if (!key) return;
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', key, iv);
    const ciphertext = Buffer.concat([cipher.update(token, 'utf8'), cipher.final()]);
    const record = JSON.stringify({
      iv: iv.toString('base64'),
      tag: cipher.getAuthTag().toString('base64'),
      value: ciphertext.toString('base64'),
    });
    const file = path.resolve(process.cwd(), this.tokenFile());
    fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
    fs.writeFileSync(file, record, { encoding: 'utf8', mode: 0o600 });
  }

  private readStoredRefreshToken(): string | undefined {
    const key = this.storageKey();
    if (!key) return undefined;
    try {
      const record = JSON.parse(fs.readFileSync(path.resolve(process.cwd(), this.tokenFile()), 'utf8'));
      const decipher = createDecipheriv('aes-256-gcm', key, Buffer.from(record.iv, 'base64'));
      decipher.setAuthTag(Buffer.from(record.tag, 'base64'));
      return Buffer.concat([
        decipher.update(Buffer.from(record.value, 'base64')),
        decipher.final(),
      ]).toString('utf8');
    } catch {
      return undefined;
    }
  }

  private requireSetupKey(setupKey?: string): void {
    const expected = this.config.get<string>('GOOGLE_OAUTH_SETUP_KEY')?.trim();
    if (!this.config.get<string>('GOOGLE_OAUTH_SETUP_ENABLED')?.toLowerCase().startsWith('true')) {
      throw new ServiceUnavailableException('Google OAuth setup is disabled.');
    }
    if (!expected || expected.length < 32 || !setupKey || setupKey !== expected) {
      throw new ServiceUnavailableException('Invalid Google OAuth setup credential.');
    }
  }

  createAuthorizationUrl(setupKey: string): string {
    this.requireSetupKey(setupKey);
    for (const [state, value] of this.states) {
      if (value.expiresAt <= Date.now()) this.states.delete(state);
    }
    const state = randomBytes(32).toString('base64url');
    this.states.set(state, { expiresAt: Date.now() + 10 * 60 * 1000 });
    const sender = this.config.get<string>('GOOGLE_SENDER_EMAIL')?.trim();
    return this.client().generateAuthUrl({
      access_type: 'offline',
      prompt: 'consent',
      scope: ['https://www.googleapis.com/auth/gmail.send'],
      state,
      ...(sender ? { login_hint: sender } : {}),
    });
  }

  async completeAuthorization(code: string, state: string): Promise<{ email: string }> {
    const savedState = this.states.get(state);
    this.states.delete(state);
    if (!savedState || savedState.expiresAt <= Date.now()) {
      throw new ServiceUnavailableException('Invalid or expired Google OAuth state.');
    }
    if (!code?.trim()) throw new ServiceUnavailableException('Google did not return an authorization code.');

    const client = this.client();
    const { tokens } = await client.getToken(code);
    if (!tokens.refresh_token) {
      throw new ServiceUnavailableException('Google did not return a refresh token. Re-authorize with consent.');
    }
    const configuredSender = this.config.get<string>('GOOGLE_SENDER_EMAIL')?.trim().toLowerCase();
    if (!configuredSender) throw new ServiceUnavailableException('GOOGLE_SENDER_EMAIL is not configured.');
    client.setCredentials({ refresh_token: tokens.refresh_token });

    // With only gmail.send, Gmail does not expose an identity/profile endpoint.
    // The administrator must complete consent using this configured sender account.
    // Keep the token only in process memory until it is copied into the protected
    // deployment environment. Never log or return it in HTTP.
    this.runtimeRefreshToken = tokens.refresh_token;
    this.persistRefreshToken(tokens.refresh_token);
    this.logger.log('Google Gmail authorization completed for the configured sender account');
    return { email: configuredSender };
  }

  hasRefreshToken(): boolean {
    return Boolean(this.runtimeRefreshToken || this.config.get<string>('GOOGLE_REFRESH_TOKEN')?.trim() || this.readStoredRefreshToken());
  }

  async sendEmail(params: {
    recipientEmail: string;
    recipientName?: string;
    subject: string;
    text: string;
    html?: string;
    inlineImages?: { filename: string; content: Buffer; contentType: string; cid: string }[];
    pdfBuffer?: Buffer;
    filename?: string;
  }): Promise<string> {
    if (!/^\S+@\S+\.\S+$/.test(params.recipientEmail)) {
      throw new Error('Invalid recipient email address');
    }
    const refreshToken = this.runtimeRefreshToken || this.config.get<string>('GOOGLE_REFRESH_TOKEN')?.trim() || this.readStoredRefreshToken();
    if (!refreshToken) throw new ServiceUnavailableException('Google Gmail refresh token is not configured.');

    const sender = this.config.get<string>('GOOGLE_SENDER_EMAIL')?.trim();
    if (!sender) throw new ServiceUnavailableException('GOOGLE_SENDER_EMAIL is not configured.');
    const client = this.client();
    client.setCredentials({ refresh_token: refreshToken });
    const gmail = google.gmail({ version: 'v1', auth: client });
    // Use Nodemailer's MIME builder for nested alternative/related parts,
    // UTF-8 subjects and safely encoded names/filenames. Gmail receives the
    // resulting message only; this does not open an SMTP connection.
    const MailComposer = require('nodemailer/lib/mail-composer') as typeof import('nodemailer/lib/mail-composer');
    const message = new MailComposer({
      from: { name: 'ACTIV Partner Support', address: sender },
      to: { name: params.recipientName || '', address: params.recipientEmail },
      subject: params.subject, text: params.text, html: params.html,
      attachments: [
        ...(params.inlineImages ?? []),
        ...(params.pdfBuffer && params.filename ? [{ filename: params.filename, content: params.pdfBuffer, contentType: 'application/pdf' }] : []),
      ],
    });
    const raw = (await message.compile().build()).toString('base64url');
    const response = await gmail.users.messages.send({
      userId: 'me',
      requestBody: { raw },
    });
    if (!response.data.id) throw new Error('Gmail accepted no message ID');
    return response.data.id;
  }
}
