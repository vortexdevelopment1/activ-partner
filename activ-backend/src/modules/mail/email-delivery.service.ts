import { BadRequestException, Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createCipheriv, createDecipheriv, createHash, randomBytes, randomUUID } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { DeliveryResult, deserializeJob, EmailJob, serializeJob } from './email-job';

@Injectable()
export class EmailDeliveryService implements OnModuleDestroy {
  private readonly logger = new Logger(EmailDeliveryService.name);
  private sender?: (job: EmailJob) => Promise<string>;
  private timer?: ReturnType<typeof setInterval>;
  private running = false;

  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService) {}

  enabled(provider: string): boolean {
    // Preserve legacy deployments until the additive migration/key are installed.
    // Explicit Gmail/SMTP must always use durable tracking.
    if (provider !== 'legacy') return true;
    return this.config.get<string>('EMAIL_DELIVERY_ENABLED') === 'true';
  }

  private key(): Buffer {
    const value = this.config.get<string>('EMAIL_DELIVERY_STORAGE_KEY')?.trim();
    if (!value || value.length < 32) throw new Error('EMAIL_DELIVERY_STORAGE_KEY must contain at least 32 characters');
    return createHash('sha256').update(value).digest();
  }

  configure(sender: (job: EmailJob) => Promise<string>, enabled: boolean) {
    this.sender = sender;
    if (!enabled) return;
    this.key();
    if (this.config.get<string>('EMAIL_RETRY_WORKER_ENABLED') === 'true') {
      this.timer = setInterval(() => void this.tick(), 30000);
      this.timer.unref();
    }
  }

  onModuleDestroy() { if (this.timer) clearInterval(this.timer); }

  private encrypt(id: string, job: EmailJob): string {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key(), iv);
    cipher.setAAD(Buffer.from(id));
    const value = Buffer.concat([cipher.update(serializeJob(job), 'utf8'), cipher.final()]);
    return JSON.stringify({ iv: iv.toString('base64'), tag: cipher.getAuthTag().toString('base64'), value: value.toString('base64') });
  }

  private decrypt(id: string, payload: string): EmailJob {
    const record = JSON.parse(payload);
    const cipher = createDecipheriv('aes-256-gcm', this.key(), Buffer.from(record.iv, 'base64'));
    cipher.setAAD(Buffer.from(id));
    cipher.setAuthTag(Buffer.from(record.tag, 'base64'));
    return deserializeJob(Buffer.concat([cipher.update(Buffer.from(record.value, 'base64')), cipher.final()]).toString('utf8'));
  }

  private identity(job: EmailJob): string {
    // A welcome notice belongs to a venue, independently of provider or later
    // owner-address changes. This identity must stay stable across deployments.
    if (job.method === 'approval' && job.eventKey) return `approval:${job.eventKey}`;
    const identity = job.eventKey
      ? `${job.provider}:${job.method}:${job.recipient.toLowerCase()}:${job.eventKey}`
      : serializeJob(job);
    return identity;
  }

  async findApproval(venueId: string, database: Pick<PrismaService, 'email_deliveries'> = this.prisma) {
    const key = createHash('sha256').update(`approval:venue-approved:${venueId}`).digest('hex');
    return database.email_deliveries.findUnique({ where: { idempotency_key: key } });
  }

  async enqueue(job: EmailJob, database: Pick<PrismaService, 'email_deliveries'> = this.prisma, alreadySent = false) {
    const id = randomUUID();
    const idempotencyKey = createHash('sha256').update(this.identity(job)).digest('hex');
    return database.email_deliveries.upsert({
      where: { idempotency_key: idempotencyKey }, update: {},
      create: {
        id, idempotency_key: idempotencyKey, provider: job.provider, kind: job.method === 'template' ? job.params.id : job.method,
        payload: alreadySent ? null : this.encrypt(id, job), expires_at: job.expiresAt ? new Date(job.expiresAt) : null,
        status: alreadySent ? 'SENT' : 'PENDING', sent_at: alreadySent ? new Date() : null,
        provider_message_id: alreadySent ? 'historical-audit-receipt' : null,
      },
    });
  }

  async send(job: EmailJob): Promise<DeliveryResult> {
    const row = await this.enqueue(job);
    const result = await this.deliver(row.id);
    if (result.sent) return result;
    const current = await this.prisma.email_deliveries.findUnique({ where: { id: row.id } });
    return { ...result, queued: !!current && ['PENDING', 'RETRY', 'PROCESSING'].includes(current.status) };
  }

  async deliver(id: string): Promise<DeliveryResult> {
    const row = await this.prisma.email_deliveries.findUnique({ where: { id } });
    if (!row) throw new BadRequestException('Email delivery not found');
    if (row.status === 'SENT') return { sent: true, messageId: row.provider_message_id };
    if (!['PENDING', 'RETRY'].includes(row.status) || row.next_attempt_at > new Date()) return { sent: false };
    if (row.expires_at && row.expires_at <= new Date()) {
      await this.prisma.email_deliveries.updateMany({ where: { id, status: { in: ['PENDING', 'RETRY'] } },
        data: { status: 'EXPIRED', payload: null, error_code: 'EXPIRED' } });
      return { sent: false };
    }
    const claimed = await this.prisma.email_deliveries.updateMany({
      where: { id, status: row.status, attempts: row.attempts, next_attempt_at: { lte: new Date() } },
      data: { status: 'PROCESSING', attempts: { increment: 1 }, locked_at: new Date(), updated_at: new Date() },
    });
    if (claimed.count !== 1) return { sent: false };
    let job: EmailJob;
    try { job = this.decrypt(id, row.payload); }
    catch {
      await this.finishFailure(id, 'FAILED', 'PAYLOAD_UNAVAILABLE');
      return { sent: false };
    }
    let messageId: string;
    try {
      if (job.method === 'reset' && job.params.challengeKey) {
        const current = await this.prisma.otp_challenges.findFirst({
          where: { phone_e164: job.params.challengeKey }, orderBy: { created_at: 'desc' },
        });
        if (!current || current.consumed_at || current.expires_at <= new Date() || job.eventKey !== `password-reset:${current.id}`) {
          await this.prisma.email_deliveries.update({ where: { id }, data: {
            status: 'EXPIRED', error_code: 'RESET_SUPERSEDED', payload: null, locked_at: null, updated_at: new Date(),
          } });
          return { sent: false };
        }
      }
      if (!this.sender) throw Object.assign(new Error('Sender unavailable'), { code: 'EMAIL_CONFIG' });
      messageId = await this.sender(job);
    } catch (error) {
      // Only known rejections are safe to retry. Network/timeout/5xx outcomes may
      // have been accepted: hold them for provider-log review, never blind retry.
      const status = Number(error?.response?.status || error?.status || error?.code);
      const configuration = error?.code === 'EMAIL_CONFIG' || error?.status === 503;
      const retryable = status === 429 || configuration;
      const rejected = status >= 400 && status < 500;
      const outcome = retryable && row.attempts + 1 < 5 ? 'RETRY' : retryable || rejected ? 'FAILED' : 'UNCERTAIN';
      await this.finishFailure(id, outcome, configuration ? 'CONFIGURATION' : status === 429 ? 'RATE_LIMITED' : rejected ? 'PROVIDER_REJECTED' : 'PROVIDER_OUTCOME_UNKNOWN', row.attempts + 1);
      return { sent: false };
    }
    try {
      await this.prisma.email_deliveries.update({ where: { id }, data: {
        status: 'SENT', provider_message_id: messageId, sent_at: new Date(), updated_at: new Date(),
        error_code: null, payload: null, locked_at: null,
      } });
    } catch {
      // Do not turn an acknowledgement-storage failure into a second send.
      this.logger.error(`Email acknowledgement could not be recorded; review delivery ${id}`);
      return { sent: false };
    }
    return { sent: true, messageId };
  }

  private async finishFailure(id: string, status: string, errorCode: string, attempts = 1) {
    await this.prisma.email_deliveries.update({ where: { id }, data: {
      status, error_code: errorCode, locked_at: null, updated_at: new Date(),
      next_attempt_at: new Date(Date.now() + Math.min(3600000, 60000 * 2 ** (attempts - 1))),
    } });
    this.logger.warn(`Email ${id}: ${errorCode}`);
  }

  async retry(id: string, confirmUnknown = false): Promise<DeliveryResult> {
    const row = await this.prisma.email_deliveries.findUnique({ where: { id } });
    if (!row) throw new BadRequestException('Email delivery not found');
    if (!['FAILED', 'RETRY', 'UNCERTAIN'].includes(row.status)) throw new BadRequestException('This delivery cannot be retried');
    if (row.status === 'UNCERTAIN' && !confirmUnknown) throw new BadRequestException('Check provider logs first; explicitly confirm an unknown outcome');
    await this.prisma.email_deliveries.updateMany({ where: { id, status: row.status, attempts: row.attempts },
      data: { status: 'RETRY', attempts: 0, next_attempt_at: new Date(), updated_at: new Date() } });
    return this.deliver(id);
  }

  list() {
    return this.prisma.email_deliveries.findMany({ take: 100, orderBy: { created_at: 'desc' },
      select: { id: true, provider: true, kind: true, status: true, attempts: true,
        error_code: true, provider_message_id: true, created_at: true, sent_at: true, next_attempt_at: true } });
  }

  async tick() {
    if (this.running) return;
    this.running = true;
    try {
      await this.prisma.email_deliveries.updateMany({ where: { status: 'PROCESSING', locked_at: { lt: new Date(Date.now() - 300000) } },
        data: { status: 'UNCERTAIN', error_code: 'WORKER_INTERRUPTED', locked_at: null, updated_at: new Date() } });
      const rows = await this.prisma.email_deliveries.findMany({ where: {
        status: { in: ['PENDING', 'RETRY'] }, next_attempt_at: { lte: new Date() },
      }, orderBy: { created_at: 'asc' }, take: 10, select: { id: true } });
      for (const row of rows) await this.deliver(row.id);
    } catch { this.logger.error('Email retry worker unavailable; check database and encryption configuration'); }
    finally { this.running = false; }
  }
}
