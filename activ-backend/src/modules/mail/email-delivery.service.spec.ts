import { ConfigService } from '@nestjs/config';
import { EmailDeliveryService } from './email-delivery.service';
import { EmailJob } from './email-job';

describe('durable encrypted email delivery', () => {
  let rows: Map<string, any>;
  let store: any;
  let service: EmailDeliveryService;
  let sender: jest.Mock;
  const job: EmailJob = { provider: 'gmail', method: 'approval', recipient: 'owner@example.com',
    eventKey: 'venue-approved:venue-1', params: { password: 'PRIVATE-TEST-PASSWORD', venueName: 'Arena' } };

  beforeEach(() => {
    rows = new Map();
    store = {
      upsert: jest.fn(async ({ where, create }) => {
        const found = [...rows.values()].find(row => row.idempotency_key === where.idempotency_key);
        if (found) return { ...found };
        const row = { ...create, status: create.status || 'PENDING', attempts: 0, next_attempt_at: new Date(0) };
        rows.set(row.id, row); return { ...row };
      }),
      findUnique: jest.fn(async ({ where }) => {
        const row = where.id ? rows.get(where.id) : [...rows.values()].find(row => row.idempotency_key === where.idempotency_key);
        return row ? { ...row } : null;
      }),
      updateMany: jest.fn(async ({ where, data }) => {
        const row = rows.get(where.id);
        if (!row || (typeof where.status === 'string' && row.status !== where.status) ||
          (where.status?.in && !where.status.in.includes(row.status)) ||
          (where.attempts !== undefined && row.attempts !== where.attempts)) return { count: 0 };
        Object.assign(row, { ...data, ...(data.attempts?.increment ? { attempts: row.attempts + data.attempts.increment } : {}) });
        return { count: 1 };
      }),
      update: jest.fn(async ({ where, data }) => { Object.assign(rows.get(where.id), data); return rows.get(where.id); }),
      findMany: jest.fn(async () => []),
    };
    service = new EmailDeliveryService({ email_deliveries: store } as any,
      new ConfigService({ EMAIL_DELIVERY_STORAGE_KEY: 'test-only-storage-key-'.repeat(3) }));
    sender = jest.fn().mockResolvedValue('gmail-message-1');
    service.configure(sender, true);
  });

  it('encrypts credentials and sends a repeated business event only once', async () => {
    const record = await service.enqueue(job);
    expect(record.payload).not.toContain('PRIVATE-TEST-PASSWORD');
    expect(record.payload).not.toContain('owner@example.com');
    expect(await service.send(job)).toEqual({ sent: true, messageId: 'gmail-message-1' });
    expect(await service.send({ ...job, params: { password: 'different' } })).toEqual({ sent: true, messageId: 'gmail-message-1' });
    expect(sender).toHaveBeenCalledTimes(1);
    expect(sender).toHaveBeenCalledWith(job);
    expect(rows.get(record.id).payload).toBeNull();
  });

  it('atomically claims one email when two workers race', async () => {
    const row = await service.enqueue(job);
    await Promise.all([service.deliver(row.id), service.deliver(row.id)]);
    expect(sender).toHaveBeenCalledTimes(1);
  });

  it('keeps one approval record across provider and recipient changes', async () => {
    const first = await service.enqueue(job);
    const second = await service.enqueue({ ...job, provider: 'legacy', recipient: 'updated-owner@example.com' });
    expect(second.id).toBe(first.id);
    expect((await service.findApproval('venue-1')).id).toBe(first.id);
    expect(rows.size).toBe(1);
  });

  it('records a historical acceptance without storing or resending credentials', async () => {
    const row = await service.enqueue(job, { email_deliveries: store } as any, true);
    expect(row).toMatchObject({ status: 'SENT', payload: null, provider_message_id: 'historical-audit-receipt' });
    expect(await service.deliver(row.id)).toMatchObject({ sent: true });
    expect(sender).not.toHaveBeenCalled();
  });

  it('retries known rate-limit rejections without recreating the payload', async () => {
    sender.mockRejectedValueOnce({ response: { status: 429 }, message: 'SECRET RESPONSE' });
    const result = await service.send(job);
    expect(result).toEqual({ sent: false, queued: true });
    const row = [...rows.values()][0];
    expect(row).toMatchObject({ status: 'RETRY', attempts: 1, error_code: 'RATE_LIMITED' });
    expect(JSON.stringify(row)).not.toContain('SECRET RESPONSE');
    expect(await service.deliver(row.id)).toEqual({ sent: false });
    await service.retry(row.id);
    expect(sender).toHaveBeenCalledTimes(2);
    expect(sender.mock.calls[1][0].params.password).toBe('PRIVATE-TEST-PASSWORD');
  });

  it('holds uncertain network outcomes until an admin confirms provider-log review', async () => {
    sender.mockRejectedValueOnce(new Error('timeout containing sensitive information'));
    await service.send(job);
    const row = [...rows.values()][0];
    expect(row.status).toBe('UNCERTAIN');
    await expect(service.retry(row.id)).rejects.toThrow('Check provider logs');
    await service.deliver(row.id);
    expect(sender).toHaveBeenCalledTimes(1);
    await service.retry(row.id, true);
    expect(sender).toHaveBeenCalledTimes(2);
  });

  it('expires reset emails and does not send obsolete codes', async () => {
    const row = await service.enqueue({ ...job, method: 'reset', expiresAt: new Date(0).toISOString() });
    expect(await service.deliver(row.id)).toEqual({ sent: false });
    expect(rows.get(row.id)).toMatchObject({ status: 'EXPIRED', payload: null });
    expect(sender).not.toHaveBeenCalled();
  });

  it('does not resend when provider acceptance could not be written to the database', async () => {
    store.update.mockRejectedValueOnce(new Error('database interrupted'));
    await service.send(job);
    const row = [...rows.values()][0];
    expect(row.status).toBe('PROCESSING');
    await service.deliver(row.id);
    expect(sender).toHaveBeenCalledTimes(1);
  });

  it('recovers pending encrypted payloads after service restart', async () => {
    const row = await service.enqueue(job);
    const restarted = new EmailDeliveryService({ email_deliveries: store } as any,
      new ConfigService({ EMAIL_DELIVERY_STORAGE_KEY: 'test-only-storage-key-'.repeat(3) }));
    restarted.configure(sender, true);
    expect(await restarted.deliver(row.id)).toMatchObject({ sent: true });
  });

  it('fails safely with an incorrect payload key', async () => {
    const row = await service.enqueue(job);
    const restarted = new EmailDeliveryService({ email_deliveries: store } as any,
      new ConfigService({ EMAIL_DELIVERY_STORAGE_KEY: 'another-test-key-'.repeat(3) }));
    restarted.configure(sender, true);
    await restarted.deliver(row.id);
    expect(rows.get(row.id)).toMatchObject({ status: 'FAILED', error_code: 'PAYLOAD_UNAVAILABLE' });
    expect(sender).not.toHaveBeenCalled();
  });

  it.each([true, false])('requires a strong encryption key at startup (delivery enabled: %s)', enabled => {
    const invalid = new EmailDeliveryService({} as any, new ConfigService({}));
    expect(() => invalid.configure(sender, enabled)).toThrow('EMAIL_DELIVERY_STORAGE_KEY');
  });

  it('stops automatic retries after five known rejections', async () => {
    sender.mockRejectedValue({ response: { status: 429 } });
    await service.send(job);
    const row = [...rows.values()][0];
    for (let attempt = 1; attempt < 5; attempt++) {
      row.next_attempt_at = new Date(0);
      await service.deliver(row.id);
    }
    expect(row).toMatchObject({ status: 'FAILED', attempts: 5 });
    await service.deliver(row.id);
    expect(sender).toHaveBeenCalledTimes(5);
  });

  it('does not send a superseded or consumed reset challenge on retry', async () => {
    (service as any).prisma.otp_challenges = { findFirst: jest.fn().mockResolvedValue({
      id: 'new-challenge', consumed_at: null, expires_at: new Date(Date.now() + 600000),
    }) };
    const row = await service.enqueue({ ...job, method: 'reset', eventKey: 'password-reset:old-challenge',
      params: { code: '1234', challengeKey: 'password-reset:user' } });
    await service.deliver(row.id);
    expect(rows.get(row.id)).toMatchObject({ status: 'EXPIRED', error_code: 'RESET_SUPERSEDED', payload: null });
    expect(sender).not.toHaveBeenCalled();
  });
});
