import { Injectable, Logger, OnModuleInit, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
// Load only Gmail instead of the generated clients for every Google API.
import * as google from 'googleapis/build/src/apis/gmail';
import { createCipheriv, createDecipheriv, createHash, randomBytes, timingSafeEqual } from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import { GoogleCredentialError, GoogleCredentialStore } from './google-credential.store';

type OAuthState = { expiresAt: number; nonce: string; version: number | null; source: string; sender: string; clientId: string };

@Injectable()
export class GoogleOAuthService implements OnModuleInit {
  private readonly logger = new Logger(GoogleOAuthService.name);
  private readonly states = new Map<string, OAuthState>();
  private runtimeRefreshToken?: string;
  private databaseTokenAvailable = false;
  private runtimeVerified = false;
  private runtimeCredentialError?: string;
  private readonly pendingRotations = new Map<string, { version: number; token: string }>();

  constructor(private readonly config: ConfigService, private readonly credentials?: GoogleCredentialStore) {}

  async onModuleInit() {
    if (this.config.get('EMAIL_PROVIDER') === 'gmail' || this.config.get('GOOGLE_OAUTH_SETUP_ENABLED') === 'true' || this.config.get('GOOGLE_TOKEN_SOURCE') === 'database') {
      this.client();
      const source = this.tokenSource();
      if (source === 'file') this.requireFileStorage();
      if (source === 'database') this.store().validateKey();
      try {
        await this.checkSources();
        if (source === 'database') this.databaseTokenAvailable = !!await this.store().load(this.sender(), this.clientId());
      } catch (error) {
        if (!(error instanceof GoogleCredentialError)) throw error;
        // Retain the database row and retry reads on subsequent status/send calls.
        this.logger.warn('Google credential unavailable; inspect protected credential status');
      }
    }
  }

  private tokenSource(): 'file' | 'env' | 'database' {
    const explicit = this.config.get<string>('GOOGLE_TOKEN_SOURCE')?.trim();
    if (explicit && !['file', 'env', 'database'].includes(explicit)) throw new ServiceUnavailableException('GOOGLE_TOKEN_SOURCE must be file, env or database');
    const environment = !!this.config.get<string>('GOOGLE_REFRESH_TOKEN')?.trim();
    const file = fs.existsSync(path.resolve(this.tokenFile()));
    if ((environment && file) || (explicit === 'file' && environment) || (explicit === 'env' && file) ||
        (explicit === 'database' && (environment || file || !!this.config.get<string>('GOOGLE_REFRESH_TOKEN_FILE')?.trim()))) {
      throw new ServiceUnavailableException('Conflicting Google token sources; configure exactly one source');
    }
    return explicit as 'file' | 'env' | 'database' || (environment ? 'env' : 'file');
  }

  private store(): GoogleCredentialStore {
    if (!this.credentials) throw new GoogleCredentialError('DATABASE_STORAGE_REQUIRED');
    return this.credentials;
  }
  private clientId(): string { return this.config.get<string>('GOOGLE_CLIENT_ID')?.trim() || ''; }
  private sender(): string {
    const sender = this.config.get<string>('GOOGLE_SENDER_EMAIL')?.trim().toLowerCase();
    if (!sender || !/^\S+@\S+\.\S+$/.test(sender)) throw new GoogleCredentialError('SENDER_REQUIRED');
    if (this.tokenSource() === 'database' && sender !== 'support@activ.live') throw new GoogleCredentialError('SENDER_MISMATCH');
    return sender;
  }
  private async checkSources() {
    const source = this.tokenSource();
    const row = this.credentials ? await this.credentials.find(this.sender()) : undefined;
    if (row && source !== 'database') throw new ServiceUnavailableException('Conflicting Google token sources; configure exactly one source');
    return row;
  }

  private requireFileStorage() {
    if (!this.storageKey()) throw new ServiceUnavailableException('GOOGLE_REFRESH_TOKEN_STORAGE_KEY must contain at least 32 characters');
    if (this.config.get('APP_ENV') === 'production' && !path.isAbsolute(this.tokenFile())) {
      throw new ServiceUnavailableException('Production GOOGLE_REFRESH_TOKEN_FILE must be an absolute persistent-disk path');
    }
  }

  private refreshToken(): string | undefined {
    const source = this.tokenSource();
    if (source === 'database') return undefined; // Database tokens are never read from disk/env.
    return this.runtimeRefreshToken || (source === 'env'
      ? this.config.get<string>('GOOGLE_REFRESH_TOKEN')?.trim() : this.readStoredRefreshToken());
  }

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
    return this.config.get<string>('GOOGLE_REFRESH_TOKEN_FILE')?.trim() || './.secrets/google-refresh-token.enc';
  }

  private storageKey(): Buffer | null {
    const value = this.config.get<string>('GOOGLE_REFRESH_TOKEN_STORAGE_KEY')?.trim();
    return value && value.length >= 32 ? createHash('sha256').update(value).digest() : null;
  }

  private persistRefreshToken(token: string): void {
    this.requireFileStorage();
    const key = this.storageKey();
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
    const temporary = `${file}.${randomBytes(12).toString('hex')}.tmp`;
    try {
      const descriptor = fs.openSync(temporary, 'wx', 0o600);
      try { fs.writeFileSync(descriptor, record, 'utf8'); fs.fsyncSync(descriptor); }
      finally { fs.closeSync(descriptor); }
      fs.renameSync(temporary, file);
    } catch {
      throw new ServiceUnavailableException('Google token persistence failed; authorization is not ready');
    } finally {
      if (fs.existsSync(temporary)) fs.unlinkSync(temporary);
    }
  }

  private readStoredRefreshToken(): string | undefined {
    const key = this.storageKey();
    if (!key) {
      if (fs.existsSync(path.resolve(this.tokenFile()))) throw new ServiceUnavailableException('Stored Google token requires its storage key');
      return undefined;
    }
    try {
      const record = JSON.parse(fs.readFileSync(path.resolve(process.cwd(), this.tokenFile()), 'utf8'));
      const decipher = createDecipheriv('aes-256-gcm', key, Buffer.from(record.iv, 'base64'));
      decipher.setAuthTag(Buffer.from(record.tag, 'base64'));
      return Buffer.concat([
        decipher.update(Buffer.from(record.value, 'base64')),
        decipher.final(),
      ]).toString('utf8');
    } catch (error) {
      if (error?.code === 'ENOENT') return undefined;
      throw new ServiceUnavailableException('Stored Google token is unreadable; check the storage key and disk');
    }
  }

  private requireSetupKey(setupKey?: string): void {
    const expected = this.config.get<string>('GOOGLE_OAUTH_SETUP_KEY')?.trim();
    if (this.config.get<string>('GOOGLE_OAUTH_SETUP_ENABLED') !== 'true') {
      throw new ServiceUnavailableException('Google OAuth setup is disabled.');
    }
    if (!expected || expected.length < 32 || !setupKey || Buffer.byteLength(setupKey) !== Buffer.byteLength(expected) || !timingSafeEqual(Buffer.from(setupKey), Buffer.from(expected))) {
      throw new ServiceUnavailableException('Invalid Google OAuth setup credential.');
    }
  }

  async createAuthorizationUrl(setupKey: string): Promise<string> {
    this.requireSetupKey(setupKey);
    const source = this.tokenSource();
    if (source === 'env') throw new ServiceUnavailableException('OAuth setup requires file or database token storage; no token export is available');
    if (source === 'file') this.requireFileStorage();
    else this.store().validateKey();
    const row = await this.checkSources();
    for (const [state, value] of this.states) {
      if (value.expiresAt <= Date.now()) this.states.delete(state);
    }
    const state = randomBytes(32).toString('base64url');
    const nonce = randomBytes(32).toString('base64url');
    const sender = this.sender();
    this.states.set(state, { expiresAt: Date.now() + 10 * 60 * 1000, nonce, version: row?.version ?? null, source, sender, clientId: this.clientId() });
    return this.client().generateAuthUrl({
      access_type: 'offline',
      prompt: 'consent',
      scope: ['openid', 'email', 'https://www.googleapis.com/auth/gmail.send'],
      state, nonce,
      ...(sender ? { login_hint: sender } : {}),
    });
  }

  async completeAuthorization(code: string, state: string): Promise<{ email: string; verified: true }> {
    const savedState = this.states.get(state);
    this.states.delete(state);
    if (!savedState || savedState.expiresAt <= Date.now()) {
      throw new ServiceUnavailableException('Invalid or expired Google OAuth state.');
    }
    if (this.config.get('GOOGLE_OAUTH_SETUP_ENABLED') !== 'true') throw new ServiceUnavailableException('Google OAuth setup is disabled.');
    if (savedState.source !== this.tokenSource() || savedState.sender !== this.sender() || savedState.clientId !== this.clientId()) {
      throw new GoogleCredentialError('CONFIGURATION_CHANGED');
    }
    if (!code?.trim()) throw new ServiceUnavailableException('Google did not return an authorization code.');

    const client = this.client();
    let tokens: any;
    try { ({ tokens } = await client.getToken(code)); }
    catch { throw new GoogleCredentialError('AUTHORIZATION_EXCHANGE_FAILED'); }
    if (typeof tokens?.refresh_token !== 'string' || !tokens.refresh_token.trim() || tokens.refresh_token.length > 16384 || /[\x00-\x20]/.test(tokens.refresh_token)) {
      throw new ServiceUnavailableException('Google did not return a refresh token. Re-authorize with consent.');
    }
    if (!tokens.id_token || typeof tokens.scope !== 'string' || !tokens.scope.split(' ').includes('https://www.googleapis.com/auth/gmail.send')) throw new GoogleCredentialError('IDENTITY_OR_SEND_SCOPE_MISSING');
    let identity: any;
    try { identity = (await client.verifyIdToken({ idToken: tokens.id_token, audience: this.clientId() })).getPayload(); }
    catch { throw new GoogleCredentialError('IDENTITY_VERIFICATION_FAILED'); }
    const configuredSender = this.sender();
    const domain = configuredSender.split('@')[1];
    if (!identity?.sub || identity.email_verified !== true || identity.email?.toLowerCase() !== configuredSender || identity.nonce !== savedState.nonce ||
        (domain !== 'gmail.com' && identity.hd !== domain)) {
      throw new GoogleCredentialError('SENDER_IDENTITY_MISMATCH');
    }
    await this.checkSources();
    if (this.tokenSource() === 'database') {
      await this.store().saveVerified(configuredSender, this.clientId(), identity.sub, tokens.refresh_token, savedState.version);
      this.pendingRotations.clear();
      this.databaseTokenAvailable = true;
    } else {
      this.persistRefreshToken(tokens.refresh_token);
      this.runtimeRefreshToken = tokens.refresh_token;
      this.runtimeVerified = true;
    }
    this.runtimeCredentialError = undefined;
    this.logger.log('Google Gmail authorization persisted and account identity verified');
    return { email: configuredSender, verified: true };
  }

  hasRefreshToken(): boolean {
    if (this.tokenSource() === 'database') return this.databaseTokenAvailable;
    return Boolean(this.refreshToken());
  }

  async credentialStatus() {
    // Explicit allowlist: never serialize storage rows, SDK errors or credentials.
    try {
      const source = this.tokenSource();
      await this.checkSources();
      if (source !== 'database') return { source, status: this.runtimeCredentialError || (this.hasRefreshToken() ? 'LEGACY_CONFIGURED' : 'NOT_CONFIGURED'), verified: !!this.runtimeVerified && !this.runtimeCredentialError };
      const current = await this.store().load(this.sender(), this.clientId());
      return { source, status: current ? 'VERIFIED' : 'NOT_CONFIGURED', verified: !!current,
        ...(current ? { sender: current.row.sender, createdAt: current.row.created_at, lastVerifiedAt: current.row.verified_at, version: current.row.version } : {}) };
    } catch (error) {
      return { status: error instanceof GoogleCredentialError ? error.configurationCode : 'CONFIGURATION_ERROR', verified: false };
    }
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
    await this.checkSources();
    const current = this.tokenSource() === 'database' ? await this.store().load(this.sender(), this.clientId()) : undefined;
    if (this.tokenSource() === 'database') this.databaseTokenAvailable = !!current;
    if (current) {
      const pending = this.pendingRotations.get(current.row.id);
      if (pending && pending.version === current.row.version) {
        await this.store().rotate({ ...current.row }, pending.token);
        current.token = pending.token; current.row.version++;
      }
      // A newer database revision wins over an older in-process rotation.
      if (pending) this.pendingRotations.delete(current.row.id);
    }
    const refreshToken = current?.token || this.refreshToken();
    if (!refreshToken) throw new ServiceUnavailableException('Google Gmail refresh token is not configured.');

    const sender = this.config.get<string>('GOOGLE_SENDER_EMAIL')?.trim();
    if (!sender) throw new ServiceUnavailableException('GOOGLE_SENDER_EMAIL is not configured.');
    const client = this.client();
    client.setCredentials({ refresh_token: refreshToken });
    let rotatedToken: string | undefined;
    let persistedToken = refreshToken;
    client.on?.('tokens', tokens => { if (tokens.refresh_token) rotatedToken = tokens.refresh_token; });
    const persistRotation = async () => {
      if (!rotatedToken || rotatedToken === persistedToken) return;
      if (current) {
        try { await this.store().rotate({ ...current.row }, rotatedToken); current.row.version++; }
        catch (error) {
          if (error instanceof GoogleCredentialError && error.configurationCode === 'PERSISTENCE_FAILED') {
            this.pendingRotations.set(current.row.id, { version: current.row.version, token: rotatedToken });
          }
          throw error;
        }
      }
      else if (this.tokenSource() === 'file') { this.persistRefreshToken(rotatedToken); this.runtimeRefreshToken = rotatedToken; }
      else throw new GoogleCredentialError('ENV_TOKEN_ROTATION_REQUIRES_OPERATOR');
      persistedToken = rotatedToken;
      // google-auth-library may restore the old refresh token after emitting
      // its tokens event. Preserve the accepted rotation in the live client too.
      if (client.credentials) client.credentials.refresh_token = persistedToken;
    };
    try {
      // Explicit refresh makes rotation persistence/failure happen BEFORE Gmail send.
      const access = await client.getAccessToken();
      if (!access?.token) throw new GoogleCredentialError('TOKEN_REFRESH_UNAVAILABLE');
      await persistRotation();
      this.runtimeCredentialError = undefined;
    } catch (error) {
      if (error instanceof GoogleCredentialError) throw error;
      if (error?.response?.data?.error === 'invalid_grant') {
        if (current) await this.store().markReauthorizationRequired(current.row);
        this.databaseTokenAvailable = false;
        this.runtimeCredentialError = 'REAUTHORIZATION_REQUIRED';
        throw new GoogleCredentialError('REAUTHORIZATION_REQUIRED');
      }
      throw new GoogleCredentialError('TOKEN_REFRESH_UNAVAILABLE');
    }
    const gmail = google.gmail({ version: 'v1', auth: client });
    // Use Nodemailer's MIME builder for nested alternative/related parts,
    // UTF-8 subjects and safely encoded names/filenames. Gmail receives the
    // resulting message only; this does not open an SMTP connection.
    const MailComposer = require('nodemailer/lib/mail-composer') as typeof import('nodemailer/lib/mail-composer');
    const message = new MailComposer({
      from: { name: 'ACTIV Partner Support', address: sender },
      to: { name: params.recipientName || '', address: params.recipientEmail },
      subject: params.subject, text: params.text, html: params.html,
      replyTo: this.config.get<string>('SUPPORT_EMAIL') || sender,
      attachments: [
        ...(params.inlineImages ?? []),
        ...(params.pdfBuffer && params.filename ? [{ filename: params.filename, content: params.pdfBuffer, contentType: 'application/pdf' }] : []),
      ],
    });
    const raw = (await message.compile().build()).toString('base64url');
    let response: any;
    try {
      response = await gmail.users.messages.send({ userId: 'me', requestBody: { raw } }, { timeout: 30000 });
    } catch (error) {
      // Preserve safe retry classification, never expose Google's request/config/body.
      try { await persistRotation(); }
      catch { throw new Error('Gmail delivery outcome requires operator review'); }
      if (error?.response?.data?.error === 'invalid_grant') {
        if (current) await this.store().markReauthorizationRequired(current.row);
        this.databaseTokenAvailable = false;
        throw new GoogleCredentialError('REAUTHORIZATION_REQUIRED');
      }
      const status = Number(error?.response?.status);
      throw Object.assign(new Error('Gmail delivery was not confirmed'), Number.isFinite(status) && status >= 400 && status <= 599 ? { status } : {});
    }
    // A late SDK refresh can happen during Gmail's request. If persistence now
    // fails, acceptance is uncertain: never classify it as a safe pre-send retry.
    try { await persistRotation(); }
    catch { throw new Error('Gmail delivery outcome requires operator review'); }
    if (!response.data.id) throw new Error('Gmail accepted no message ID');
    return response.data.id;
  }
}
