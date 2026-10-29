import { ConflictException, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createCipheriv, createDecipheriv, createHash, randomBytes, randomUUID } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';

export class GoogleCredentialError extends ServiceUnavailableException {
  constructor(readonly configurationCode: string) { super(`Google credential configuration: ${configurationCode}`); }
}

@Injectable()
export class GoogleCredentialStore {
  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService) {}

  private identity(sender: string) { return { provider: 'gmail', sender: sender.trim().toLowerCase() }; }
  private fingerprint(clientId: string) { return createHash('sha256').update(clientId).digest('hex'); }
  validateKey() {
    const key = this.config.get<string>('GOOGLE_REFRESH_TOKEN_STORAGE_KEY')?.trim();
    if (!key || key.length < 32) throw new GoogleCredentialError('STORAGE_KEY_REQUIRED');
    return createHash('sha256').update(key).digest();
  }
  private aad(row: any) { return Buffer.from(JSON.stringify([row.provider, row.sender, row.client_fingerprint, row.account_subject])); }
  private validToken(token: string) {
    if (typeof token !== 'string' || !token.trim() || token !== token.trim() || token.length > 16384 || /[\x00-\x20]/.test(token)) {
      throw new GoogleCredentialError('INVALID_REFRESH_RESPONSE');
    }
  }
  private encrypt(token: string, row: any): string {
    this.validToken(token);
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.validateKey(), iv);
    cipher.setAAD(this.aad(row));
    const value = Buffer.concat([cipher.update(token, 'utf8'), cipher.final()]);
    return JSON.stringify({ version: 1, iv: iv.toString('base64'), tag: cipher.getAuthTag().toString('base64'), value: value.toString('base64') });
  }
  private decrypt(row: any): string {
    try {
      const record = JSON.parse(row.encrypted_refresh_token);
      if (record.version !== 1 || Buffer.from(record.iv, 'base64').length !== 12 || Buffer.from(record.tag, 'base64').length !== 16) throw new Error();
      const cipher = createDecipheriv('aes-256-gcm', this.validateKey(), Buffer.from(record.iv, 'base64'));
      cipher.setAAD(this.aad(row)); cipher.setAuthTag(Buffer.from(record.tag, 'base64'));
      const token = Buffer.concat([cipher.update(Buffer.from(record.value, 'base64')), cipher.final()]).toString('utf8');
      this.validToken(token); return token;
    } catch { throw new GoogleCredentialError('CREDENTIAL_UNREADABLE'); }
  }

  async find(sender: string) {
    try { return await this.prisma.google_oauth_credentials.findUnique({ where: { provider_sender: this.identity(sender) } }); }
    catch { throw new GoogleCredentialError('DATABASE_UNAVAILABLE'); }
  }
  async load(sender: string, clientId: string) {
    const row = await this.find(sender);
    if (!row) return undefined;
    if (row.client_fingerprint !== this.fingerprint(clientId)) throw new GoogleCredentialError('OAUTH_CLIENT_MISMATCH');
    if (row.status !== 'VERIFIED' || !row.verified_at || !row.account_subject) throw new GoogleCredentialError('REAUTHORIZATION_REQUIRED');
    return { row, token: this.decrypt(row) };
  }

  /** Compare-and-set the revision captured by the protected setup request. */
  async saveVerified(sender: string, clientId: string, subject: string, token: string, expectedVersion: number | null) {
    if (!subject || subject.length > 255) throw new GoogleCredentialError('IDENTITY_REQUIRED');
    const identity = this.identity(sender);
    const metadata = { ...identity, client_fingerprint: this.fingerprint(clientId), account_subject: subject };
    const encrypted = this.encrypt(token, metadata);
    try {
      return await this.prisma.$transaction(async tx => {
        if (expectedVersion === null) {
          return tx.google_oauth_credentials.create({ data: { id: randomUUID(), ...metadata,
            encrypted_refresh_token: encrypted, status: 'VERIFIED', verified_at: new Date(), version: 1 } });
        }
        const result = await tx.google_oauth_credentials.updateMany({ where: { ...identity, version: expectedVersion },
          data: { ...metadata, encrypted_refresh_token: encrypted, status: 'VERIFIED', verified_at: new Date(), version: { increment: 1 } } });
        if (result.count !== 1) throw new ConflictException('Google credential changed; start a new protected setup request');
        return tx.google_oauth_credentials.findUnique({ where: { provider_sender: identity } });
      });
    } catch (error) {
      if (error instanceof ConflictException || error?.code === 'P2002') throw new ConflictException('Google credential changed; start a new protected setup request');
      throw new GoogleCredentialError('PERSISTENCE_FAILED');
    }
  }

  async rotate(row: any, token: string) {
    const encrypted = this.encrypt(token, row);
    try {
      const result = await this.prisma.google_oauth_credentials.updateMany({ where: { id: row.id, version: row.version, status: 'VERIFIED' },
        data: { encrypted_refresh_token: encrypted, version: { increment: 1 } } });
      if (result.count !== 1) throw new GoogleCredentialError('CREDENTIAL_CHANGED_RETRY');
    } catch (error) {
      if (error instanceof GoogleCredentialError) throw error;
      throw new GoogleCredentialError('PERSISTENCE_FAILED');
    }
  }
  async markReauthorizationRequired(row: any) {
    try {
      await this.prisma.google_oauth_credentials.updateMany({ where: { id: row.id, version: row.version },
        data: { status: 'REAUTH_REQUIRED', version: { increment: 1 } } });
    } catch { throw new GoogleCredentialError('DATABASE_UNAVAILABLE'); }
  }
}
