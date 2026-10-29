import { ConfigService } from '@nestjs/config';
import { VenuesService } from './venues.service';
import { VenueStatus } from '../../common/enums/venue-status.enum';
import { MailService } from '../mail/mail.service';
import { EmailDeliveryService } from '../mail/email-delivery.service';

/** In-memory READ COMMITTED transaction harness: staged writes are discarded on
 * rollback, and explicit row locks serialize requests (not a global test mutex).
 * All provider calls use the real encrypted outbox with a mocked Gmail sender. */
function fixture() {
  const state: any = {
    venues: { venue: { id: 'venue', partner_id: 'partner', name: 'Arena', status: 'DRAFT',
      review_status: 'pending', submitted_at: new Date('2026-10-29T00:00:00Z'), approved_at: null,
      address: 'Existing address', metadata: { existing: true }, booking_accept: true } },
    partners: { partner: { id: 'partner', status: 'PENDING', legal_name: 'Owner',
      partner_business_profiles: { owner_name: 'Business Owner' },
      partner_users: [{ role: 'PARTNER_ADMIN', user_id: 'owner' }] } },
    users: { owner: { id: 'owner', name: 'Owner', email: 'owner@example.com', status: 'ACTIVE', password_hash: null } },
    services: { activity: { id: 'activity', venue_id: 'venue', status: 'PENDING' } },
    deliveries: {}, audits: {}, slots: {},
  };
  const locks = new Map<string, Promise<void>>();
  const events: string[] = [];
  const acquired: string[] = [];
  let fail = '';
  const clone = (value: any) => value == null ? value : structuredClone(value);
  const check = (point: string) => { if (fail === point) throw new Error(`Injected ${point} failure`); };
  function client(staged?: any) {
    const read = (table: string, id: string) => clone(staged?.[table]?.[id] || state[table][id]);
    const all = (table: string) => Object.values({ ...state[table], ...staged?.[table] }) as any[];
    const write = (table: string, row: any) => { (staged || state)[table][row.id] = clone(row); return clone(row); };
    const update = (table: string, where: any, data: any) => {
      const row = read(table, where.id);
      if (!row) throw new Error('Missing row');
      return write(table, { ...row, ...data });
    };
    return {
      venues: { findUnique: jest.fn(async ({ where }) => read('venues', where.id)),
        update: jest.fn(async ({ where, data }) => { check('publication'); return update('venues', where, data); }) },
      partners: { findUnique: jest.fn(async ({ where }) => read('partners', where.id)),
        update: jest.fn(async ({ where, data }) => { check('partner activation'); return update('partners', where, data); }) },
      users: { findUnique: jest.fn(async ({ where }) => read('users', where.id)),
        update: jest.fn(async ({ where, data }) => { check('credentials'); return update('users', where, data); }) },
      partner_venue_services: { updateMany: jest.fn(async ({ where, data }) => {
        check('activities');
        for (const row of all('services').filter(row => row.venue_id === where.venue_id && where.status.in.includes(row.status))) write('services', { ...row, ...data });
        return { count: 1 };
      }) },
      audit_events: { findFirst: jest.fn(async ({ where }) => clone(all('audits').find(row => row.action === where.action && row.entity_id === where.entity_id) || null)),
        create: jest.fn(async ({ data }) => { check('audit'); return write('audits', data); }) },
      email_deliveries: {
        findUnique: jest.fn(async ({ where }) => where.id ? read('deliveries', where.id)
          : clone(all('deliveries').find(row => row.idempotency_key === where.idempotency_key) || null)),
        upsert: jest.fn(async ({ where, create }) => {
          check('email preparation');
          const previous = all('deliveries').find(row => row.idempotency_key === where.idempotency_key);
          if (previous) return clone(previous);
          events.push('email prepared');
          return write('deliveries', { attempts: 0, next_attempt_at: new Date(0), created_at: new Date(), ...create });
        }),
        updateMany: jest.fn(async ({ where, data }) => {
          const row = read('deliveries', where.id);
          if (!row || row.status !== where.status || row.attempts !== where.attempts) return { count: 0 };
          write('deliveries', { ...row, ...data, attempts: data.attempts?.increment ? row.attempts + data.attempts.increment : data.attempts ?? row.attempts });
          return { count: 1 };
        }),
        update: jest.fn(async ({ where, data }) => update('deliveries', where, data)),
      },
      syncSlots: jest.fn(async (id: string) => {
        check('slots'); write('slots', { id, approved: true });
      }),
    };
  }
  const prisma: any = client();
  prisma.$transaction = jest.fn(async (callback, options) => {
    expect(options.isolationLevel).toBe('ReadCommitted');
    const staged = Object.fromEntries(Object.keys(state).map(key => [key, {}]));
    const release: (() => void)[] = [];
    const held = new Set<string>();
    const tx: any = client(staged);
    tx.$queryRaw = jest.fn(async (sql: TemplateStringsArray, id: string) => {
      const table = sql.join('').match(/FROM (\w+)/)![1];
      const key = `${table}:${id}`;
      if (held.has(key)) return [];
      const previous = locks.get(key) || Promise.resolve();
      let unlock: () => void;
      const next = new Promise<void>(resolve => { unlock = resolve; });
      locks.set(key, previous.then(() => next));
      await previous;
      held.add(key); release.push(unlock!); acquired.push(key);
      return [];
    });
    try {
      const result = await callback(tx);
      check('commit');
      for (const table of Object.keys(state)) Object.assign(state[table], staged[table]);
      events.push('commit');
      return result;
    } finally { for (const unlock of release.reverse()) unlock(); }
  });
  const settings: Record<string, any> = { EMAIL_PROVIDER: 'gmail', GOOGLE_SENDER_EMAIL: 'support@activ.live',
    EMAIL_DELIVERY_STORAGE_KEY: 'approval-test-encryption-key-'.repeat(3) };
  // Keep fixture configuration local: ConfigService.set also changes process.env.
  const config = { get: (key: string, fallback?: any) => settings[key] ?? fallback,
    set: (key: string, value: any) => { settings[key] = value; } } as ConfigService;
  const gmail = { sendEmail: jest.fn(async (_message: any) => { events.push('provider'); return 'gmail-message'; }) };
  const deliveries = new EmailDeliveryService(prisma, config);
  const mail = new MailService(config, gmail as any, deliveries);
  mail.onModuleInit();
  const service = Object.assign(Object.create(VenuesService.prototype), {
    prisma, mailService: mail, generatePassword: jest.fn().mockReturnValue('Only-Test@123'),
    notificationsService: { notify: jest.fn() }, pushNotificationsService: { sendToPartner: jest.fn() },
    logger: { warn: jest.fn(), error: jest.fn() },
    syncLegacyActivitySlotsInTransaction: jest.fn((tx, id) => tx.syncSlots(id)),
    findOne: jest.fn(async id => ({ ...clone(state.venues[id]), status: state.venues[id].status === 'PUBLISHED' ? 'approved' : 'pending' })),
  }) as any;
  const approve = (id = 'venue', admin = 'admin') => service.processApproval(id, { status: VenueStatus.APPROVED }, admin);
  return { state, service, gmail, deliveries, mail, config, prisma, events, acquired, approve, setFailure: (point: string) => { fail = point; } };
}

describe('atomic venue approval', () => {
  it('commits publication, activation, credentials, activities, slots, audit and encrypted email before transport', async () => {
    const f = fixture();
    expect(await f.approve()).toMatchObject({ status: 'approved', address: 'Existing address', metadata: { existing: true } });
    expect(f.state.partners.partner.status).toBe('ACTIVE');
    expect(f.state.users.owner.password_hash).toBeTruthy();
    expect(f.state.services.activity.status).toBe('APPROVED');
    expect(f.state.slots.venue).toEqual({ id: 'venue', approved: true });
    expect(Object.values(f.state.audits)).toHaveLength(1);
    expect(Object.values(f.state.deliveries)).toHaveLength(1);
    expect(f.events.indexOf('commit')).toBeLessThan(f.events.indexOf('provider'));
    expect(f.gmail.sendEmail).toHaveBeenCalledWith(expect.objectContaining({ recipientEmail: 'owner@example.com', recipientName: 'Owner',
      html: expect.stringContaining('Arena'), inlineImages: [expect.objectContaining({ cid: 'activ-partner-logo' })] }));
    expect(f.acquired).toEqual(['partners:partner', 'venues:venue', 'users:owner']);
  });

  it.each(['credentials', 'partner activation', 'email preparation', 'publication', 'activities', 'slots', 'audit', 'commit'])('rolls back every database effect on %s failure', async point => {
    const f = fixture();
    const before = structuredClone(f.state);
    f.setFailure(point);
    await expect(f.approve()).rejects.toThrow(`Injected ${point} failure`);
    expect(f.state).toEqual(before);
    expect(f.gmail.sendEmail).not.toHaveBeenCalled();
    expect(f.service.notificationsService.notify).not.toHaveBeenCalled();
    expect(f.service.pushNotificationsService.sendToPartner).not.toHaveBeenCalled();
    f.setFailure('');
    await f.approve();
    expect(f.state.venues.venue.status).toBe('PUBLISHED');
    expect(Object.values(f.state.deliveries)).toHaveLength(1);
  });

  it('fails closed on missing encryption configuration even in legacy mode', async () => {
    const f = fixture();
    f.config.set('EMAIL_PROVIDER', 'legacy');
    f.config.set('EMAIL_DELIVERY_STORAGE_KEY', '');
    await expect(f.approve()).rejects.toThrow('EMAIL_DELIVERY_STORAGE_KEY');
    expect(f.state.venues.venue.status).toBe('DRAFT');
    expect(f.state.partners.partner.status).toBe('PENDING');
    expect(f.state.users.owner.password_hash).toBeNull();
    expect(Object.values(f.state.deliveries)).toHaveLength(0);
  });

  it('creates a durable approval record in legacy mode even when general durable delivery is disabled', async () => {
    const f = fixture();
    f.config.set('EMAIL_PROVIDER', 'legacy');
    f.config.set('EMAIL_DELIVERY_ENABLED', 'false');
    jest.spyOn(f.mail, 'deliverPreparedEmail').mockResolvedValueOnce(false);
    await f.approve();
    expect(Object.values(f.state.deliveries)[0]).toMatchObject({ provider: 'legacy', status: 'PENDING', kind: 'approval' });
    expect(f.state.venues.venue.status).toBe('PUBLISHED');
    expect(f.gmail.sendEmail).not.toHaveBeenCalled();
  });

  it('keeps a committed approval and its original password when Gmail fails, then retries only the email', async () => {
    const f = fixture();
    f.gmail.sendEmail.mockRejectedValueOnce({ response: { status: 429 } });
    await expect(f.approve()).resolves.toMatchObject({ status: 'approved' });
    const hash = f.state.users.owner.password_hash;
    const row: any = Object.values(f.state.deliveries)[0];
    expect(row.status).toBe('RETRY');
    expect(row.payload).not.toContain('Only-Test@123');
    await f.approve();
    expect(f.gmail.sendEmail).toHaveBeenCalledTimes(1);
    expect(f.service.generatePassword).toHaveBeenCalledTimes(1);
    await f.deliveries.retry(row.id);
    expect(f.gmail.sendEmail).toHaveBeenCalledTimes(2);
    expect(f.gmail.sendEmail.mock.calls[1]).toEqual(f.gmail.sendEmail.mock.calls[0]);
    expect(f.state.users.owner.password_hash).toBe(hash);
    expect(Object.values(f.state.deliveries)).toHaveLength(1);
    expect(f.service.notificationsService.notify).toHaveBeenCalledTimes(1);
  });

  it('holds uncertain outcomes rather than sending again on duplicate approval', async () => {
    const f = fixture();
    f.gmail.sendEmail.mockRejectedValueOnce(new Error('ambiguous network timeout'));
    await f.approve();
    const row: any = Object.values(f.state.deliveries)[0];
    expect(row.status).toBe('UNCERTAIN');
    await f.approve();
    expect(f.gmail.sendEmail).toHaveBeenCalledTimes(1);
    await expect(f.deliveries.retry(row.id)).rejects.toThrow('Check provider logs');
  });

  it('does not reset an existing password or resend a successful approval', async () => {
    const f = fixture();
    f.state.users.owner.password_hash = 'existing-hash';
    await f.approve();
    const date = f.state.venues.venue.approved_at;
    await f.approve('venue', 'another-admin');
    expect(f.state.users.owner.password_hash).toBe('existing-hash');
    expect(f.service.generatePassword).not.toHaveBeenCalled();
    expect(f.state.venues.venue.approved_at).toEqual(date);
    expect(f.state.venues.venue.approved_by).toBe('admin');
    expect(f.gmail.sendEmail).toHaveBeenCalledTimes(1);
    expect(Object.values(f.state.audits)).toHaveLength(1);
  });

  it('serializes concurrent approvals of one venue with one credential and one delivery', async () => {
    const f = fixture();
    const result = await Promise.all([f.approve(), f.approve('venue', 'another-admin'), f.approve()]);
    expect(result.every(row => row.status === 'approved')).toBe(true);
    expect(f.service.generatePassword).toHaveBeenCalledTimes(1);
    expect(Object.values(f.state.deliveries)).toHaveLength(1);
    expect(Object.values(f.state.audits)).toHaveLength(1);
    expect(f.gmail.sendEmail).toHaveBeenCalledTimes(1);
    expect(f.service.notificationsService.notify).toHaveBeenCalledTimes(1);
    expect(f.service.pushNotificationsService.sendToPartner).toHaveBeenCalledTimes(1);
  });

  it('serializes two venues of the same partner without generating two passwords', async () => {
    const f = fixture();
    f.state.venues.second = { ...structuredClone(f.state.venues.venue), id: 'second', name: 'Second Arena' };
    await Promise.all([f.approve(), f.approve('second')]);
    expect(f.service.generatePassword).toHaveBeenCalledTimes(1);
    expect(Object.values(f.state.deliveries)).toHaveLength(2);
    expect(f.gmail.sendEmail).toHaveBeenCalledTimes(2);
    const messages = f.gmail.sendEmail.mock.calls.map(call => call[0]);
    expect(messages.filter(message => message.text.includes('Only-Test@123'))).toHaveLength(1);
  });

  it('uses the venue profile display name in the personalized approval email', async () => {
    const f = fixture();
    f.state.venues.venue.partner_venue_profiles = { display_name: 'Partner Arena' };
    await f.approve();
    expect(f.gmail.sendEmail).toHaveBeenCalledWith(expect.objectContaining({ html: expect.stringContaining('Partner Arena') }));
    expect(f.state.venues.venue.name).toBe('Arena');
  });

  it('imports a historical accepted-email receipt without sending another welcome', async () => {
    const f = fixture();
    f.state.users.owner.password_hash = 'existing-hash';
    f.state.audits.historical = { id: 'historical', action: 'partner_approval.email_sent', entity_id: 'venue' };
    await f.approve();
    expect(Object.values(f.state.deliveries)[0]).toMatchObject({ status: 'SENT', payload: null, provider_message_id: 'historical-audit-receipt' });
    expect(f.gmail.sendEmail).not.toHaveBeenCalled();
  });

  it.each(['missing owner', 'missing email', 'deleted owner', 'suspended partner'])('rejects %s before publication', async scenario => {
    const f = fixture();
    if (scenario === 'missing owner') f.state.partners.partner.partner_users = [];
    if (scenario === 'missing email') f.state.users.owner.email = null;
    if (scenario === 'deleted owner') f.state.users.owner.status = 'DELETED';
    if (scenario === 'suspended partner') f.state.partners.partner.status = 'SUSPENDED';
    await expect(f.approve()).rejects.toThrow();
    expect(f.state.venues.venue.status).toBe('DRAFT');
    expect(Object.values(f.state.deliveries)).toHaveLength(0);
  });

  it('does not fail the approved response when post-commit transport or notification dispatch throws', async () => {
    const f = fixture();
    jest.spyOn(f.mail, 'deliverPreparedEmail').mockRejectedValueOnce(new Error('database unavailable after commit'));
    f.service.notificationsService.notify.mockRejectedValueOnce(new Error('notification unavailable'));
    f.service.pushNotificationsService.sendToPartner.mockRejectedValueOnce(new Error('push unavailable'));
    await expect(f.approve()).resolves.toMatchObject({ status: 'approved' });
    expect(Object.values(f.state.deliveries)[0]).toMatchObject({ status: 'PENDING' });
  });

  it('lets a waiting approval succeed after the first preparation rolls back', async () => {
    const f = fixture();
    jest.spyOn(f.mail, 'preparePartnerApprovalEmail').mockRejectedValueOnce(new Error('preparation unavailable'));
    const result = await Promise.allSettled([f.approve(), f.approve()]);
    expect(result.filter(row => row.status === 'fulfilled')).toHaveLength(1);
    expect(result.filter(row => row.status === 'rejected')).toHaveLength(1);
    expect(f.state.venues.venue.status).toBe('PUBLISHED');
    expect(Object.values(f.state.deliveries)).toHaveLength(1);
    expect(f.gmail.sendEmail).toHaveBeenCalledTimes(1);
  });

  it('rejects a stale moderation request after a concurrent approval', async () => {
    const f = fixture();
    const stale = structuredClone(f.state.venues.venue);
    await f.approve();
    f.prisma.venues.findUnique.mockResolvedValueOnce(stale);
    await expect(f.service.processApproval('venue', { status: VenueStatus.REJECTED, reason: 'Old decision' }, 'another-admin'))
      .rejects.toThrow('Venue review changed');
    expect(f.state.venues.venue.status).toBe('PUBLISHED');
    expect(f.state.services.activity.status).toBe('APPROVED');
    expect(f.gmail.sendEmail).toHaveBeenCalledTimes(1);
  });

  it('does not repeat approval after a committed response could not be read', async () => {
    const f = fixture();
    f.service.findOne.mockRejectedValueOnce(new Error('response read failed'));
    await expect(f.approve()).rejects.toThrow('response read failed');
    const hash = f.state.users.owner.password_hash;
    await f.approve();
    expect(f.state.users.owner.password_hash).toBe(hash);
    expect(f.service.generatePassword).toHaveBeenCalledTimes(1);
    expect(f.gmail.sendEmail).toHaveBeenCalledTimes(1);
  });
});
