import { randomUUID } from 'crypto';
import { execFile } from 'child_process';
import { promisify } from 'util';
import { ConfigService } from '@nestjs/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../../src/generated/prisma/client';
import { VenuesService } from '../../src/modules/venues/venues.service';
import { VenueStatus } from '../../src/common/enums/venue-status.enum';
import { MailService } from '../../src/modules/mail/mail.service';
import { LegacyMailService } from '../../src/modules/mail/legacy-mail.service';
import { EmailDeliveryService } from '../../src/modules/mail/email-delivery.service';

const storageKey = 'isolated-postgres-integration-encryption-key-only';
const url = process.env.ACTIV_PG_TEST_URL;
function guardedClient() {
  if (!url || !process.env.ACTIV_PG_TEST_MARKER) throw new Error('Use npm run test:postgres; no external database is accepted');
  const parsed = new URL(url);
  if (parsed.hostname !== '127.0.0.1' || parsed.pathname !== '/activ_integration_test' || parsed.username !== 'activ_integration') {
    throw new Error('Integration database target rejected');
  }
  return new PrismaClient({ adapter: new PrismaPg({ connectionString: url }) });
}

describe('real PostgreSQL venue approval', () => {
  let db: PrismaClient;
  beforeAll(async () => {
    db = guardedClient();
    const guard = await db.$queryRaw<Array<{ marker: string }>>`SELECT marker FROM activ_integration_guard`;
    expect(guard).toEqual([{ marker: process.env.ACTIV_PG_TEST_MARKER }]);
  });
  afterAll(async () => { await db?.$disconnect(); });
  afterEach(() => jest.restoreAllMocks());

  async function fixture(provider = 'gmail', secondVenue = false) {
    const partner = randomUUID(), owner = randomUUID(), admin = randomUUID(), venue = randomUUID(), category = randomUUID();
    await db.users.createMany({ data: [
      { id: owner, phone_e164: `+test-${owner}`, email: 'owner@example.invalid', name: 'Test Owner', updated_at: new Date() },
      { id: admin, phone_e164: `+test-${admin}`, is_admin: true, updated_at: new Date() },
    ] });
    await db.partners.create({ data: { id: partner, legal_name: 'Integration Partner', updated_at: new Date() } });
    await db.partner_users.create({ data: { id: randomUUID(), partner_id: partner, user_id: owner, role: 'PARTNER_ADMIN' } });
    const venueData = { partner_id: partner, name: 'Integration Arena', city_code: 'TEST', latitude: 1, longitude: 1,
      policy_version: 'test', review_status: 'pending', submitted_at: new Date(), metadata: { preserved: true } };
    await db.venues.create({ data: { ...venueData, id: venue } });
    const second = secondVenue ? randomUUID() : undefined;
    if (second) await db.venues.create({ data: { ...venueData, id: second } });
    await db.partner_service_categories.create({ data: { id: category, slug: category, name: 'Test Sport', updated_at: new Date() } });
    await db.activities.create({ data: { id: randomUUID(), sport_code: category, name: 'Test Sport', status: 'PUBLISHED' } });
    await db.partner_venue_services.create({ data: { id: randomUUID(), venue_id: venue, service_category_id: category,
      title: 'Test Sport', status: 'PENDING', updated_at: new Date() } });
    await db.partner_venue_availability.create({ data: { id: randomUUID(), venue_id: venue, service_category_id: category,
      day: 'monday', open_time: '10:00', close_time: '11:00', capacity: 1, price_paise: 10000 } });
    const settings = { EMAIL_PROVIDER: provider, EMAIL_DELIVERY_ENABLED: 'false', EMAIL_RETRY_WORKER_ENABLED: 'false',
      GOOGLE_SENDER_EMAIL: 'support@activ.live', EMAIL_DELIVERY_STORAGE_KEY: storageKey };
    const config = { get: (key: string, fallback?: any) => settings[key] ?? fallback } as ConfigService;
    const gmail = { sendEmail: jest.fn().mockResolvedValue('mock-gmail-id') };
    const deliveries = new EmailDeliveryService(db as any, config);
    const mail = new MailService(config, gmail as any, deliveries);
    mail.onModuleInit();
    const service = Object.assign(Object.create(VenuesService.prototype), { prisma: db, mailService: mail,
      notificationsService: { notify: jest.fn() }, pushNotificationsService: { sendToPartner: jest.fn() },
      logger: { warn: jest.fn(), error: jest.fn() }, generatePassword: jest.fn().mockReturnValue('Integration@Test123'),
    }) as VenuesService;
    const approve = (id = venue) => service.processApproval(id, { status: VenueStatus.APPROVED }, admin);
    const delivery = () => deliveries.findApproval(venue);
    return { partner, owner, venue, second, admin, gmail, deliveries, mail, settings, service, approve, delivery };
  }

  it('applies the actual migration with a unique key and status constraint', async () => {
    const rows = await db.$queryRaw<any[]>`SELECT migration_name, finished_at FROM _prisma_migrations WHERE migration_name = '20261029000000_email_deliveries'`;
    expect(rows).toHaveLength(1);
    expect(rows[0].finished_at).toBeTruthy();
    await expect(db.email_deliveries.create({ data: { id: randomUUID(), idempotency_key: randomUUID(),
      provider: 'gmail', kind: 'approval', status: 'INVALID' } })).rejects.toThrow();
  });

  it('rolls back publication, credentials, activities, slots and outbox when the final audit write fails', async () => {
    const f = await fixture();
    // A real FK error in the final write, after all preceding transaction effects.
    await expect(f.service.processApproval(f.venue, { status: VenueStatus.APPROVED }, randomUUID())).rejects.toThrow();
    expect((await db.venues.findUnique({ where: { id: f.venue } })).status).toBe('DRAFT');
    expect((await db.partners.findUnique({ where: { id: f.partner } })).status).toBe('PENDING');
    expect((await db.users.findUnique({ where: { id: f.owner } })).password_hash).toBeNull();
    expect(await f.delivery()).toBeNull();
    expect(await db.facilities.count({ where: { venue_id: f.venue } })).toBe(0);
    expect(await db.partner_venue_services.findFirst({ where: { venue_id: f.venue } })).toMatchObject({ status: 'PENDING', facility_id: null });
    expect(f.gmail.sendEmail).not.toHaveBeenCalled();
    await f.approve();
    expect((await f.delivery()).status).toBe('SENT');
    expect(await db.slots.count({ where: { facilities: { venue_id: f.venue } } })).toBeGreaterThan(0);
  });

  it('does not publish if durable payload encryption fails', async () => {
    const f = await fixture();
    f.settings.EMAIL_DELIVERY_STORAGE_KEY = '';
    await expect(f.approve()).rejects.toThrow('EMAIL_DELIVERY_STORAGE_KEY');
    expect((await db.venues.findUnique({ where: { id: f.venue } })).status).toBe('DRAFT');
    expect((await db.users.findUnique({ where: { id: f.owner } })).password_hash).toBeNull();
    expect(await f.delivery()).toBeNull();
  });

  it('serializes concurrent approvals and rejects duplicate delivery keys', async () => {
    const f = await fixture();
    const results = await Promise.all([f.approve(), f.approve(), f.approve()]);
    expect(results.every(row => row.status === VenueStatus.APPROVED)).toBe(true);
    expect(f.service['generatePassword']).toHaveBeenCalledTimes(1);
    expect(f.gmail.sendEmail).toHaveBeenCalledTimes(1);
    expect(await db.audit_events.count({ where: { action: 'venue.approved', entity_id: f.venue } })).toBe(1);
    const row = await f.delivery();
    await expect(db.email_deliveries.create({ data: { id: randomUUID(), idempotency_key: row.idempotency_key,
      provider: 'gmail', kind: 'approval' } })).rejects.toThrow();
    const hash = (await db.users.findUnique({ where: { id: f.owner } })).password_hash;
    await f.approve();
    expect((await db.users.findUnique({ where: { id: f.owner } })).password_hash).toBe(hash);
    expect(f.gmail.sendEmail).toHaveBeenCalledTimes(1);
  });

  it('serializes two venues of the same owner without competing passwords', async () => {
    const f = await fixture('gmail', true);
    await Promise.all([f.approve(), f.approve(f.second)]);
    expect(f.service['generatePassword']).toHaveBeenCalledTimes(1);
    expect(f.gmail.sendEmail).toHaveBeenCalledTimes(2);
    expect(f.gmail.sendEmail.mock.calls.filter(([message]) => message.text.includes('Integration@Test123'))).toHaveLength(1);
    expect(await f.deliveries.findApproval(f.second)).toBeTruthy();
  });

  it('requires durable approval even in legacy mode with general delivery disabled', async () => {
    const legacy = jest.spyOn(LegacyMailService.prototype, 'sendPartnerApprovalEmail').mockResolvedValue(true);
    const f = await fixture('legacy');
    await f.approve();
    expect(await f.delivery()).toMatchObject({ provider: 'legacy', status: 'SENT', attempts: 1 });
    expect(legacy).toHaveBeenCalledTimes(1);
    expect(f.gmail.sendEmail).not.toHaveBeenCalled();
  });

  it('keeps committed credentials when delivery fails and retries only the saved email', async () => {
    const f = await fixture();
    f.gmail.sendEmail.mockRejectedValueOnce({ response: { status: 429 } });
    await f.approve();
    const row = await f.delivery();
    expect(row).toMatchObject({ status: 'RETRY', attempts: 1 });
    expect(row.payload).not.toContain('Integration@Test123');
    const hash = (await db.users.findUnique({ where: { id: f.owner } })).password_hash;
    expect((await db.venues.findUnique({ where: { id: f.venue } })).status).toBe('PUBLISHED');
    await f.deliveries.retry(row.id);
    expect((await f.delivery()).status).toBe('SENT');
    expect((await db.users.findUnique({ where: { id: f.owner } })).password_hash).toBe(hash);
    expect(f.gmail.sendEmail.mock.calls[1]).toEqual(f.gmail.sendEmail.mock.calls[0]);
  });

  it('recovers a committed pending payload in a fresh OS process with the same encryption key', async () => {
    const f = await fixture();
    jest.spyOn(f.mail, 'deliverPreparedEmail').mockResolvedValue(false); // Crash window: commit succeeded, dispatch not attempted.
    await f.approve();
    expect((await f.delivery()).status).toBe('PENDING');
    const hash = (await db.users.findUnique({ where: { id: f.owner } })).password_hash;
    const result = await promisify(execFile)(process.execPath, ['test/postgres/restart-worker.cjs'], {
      cwd: process.cwd(), windowsHide: true, env: { ...process.env, ACTIV_PG_TEST_STORAGE_KEY: storageKey },
    });
    expect(result.stdout).toContain('Recovered 1 pending approval');
    expect((await f.delivery()).status).toBe('SENT');
    expect((await db.users.findUnique({ where: { id: f.owner } })).password_hash).toBe(hash);
    expect(f.gmail.sendEmail).not.toHaveBeenCalled();
  });
});
