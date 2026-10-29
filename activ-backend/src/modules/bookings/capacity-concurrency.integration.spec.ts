import { randomUUID } from 'crypto';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { lockSlotsForCapacity } from './slot-capacity-coordinator';
import { effectiveSlotOccupancy } from './slot-capacity';
import { NormalizedBookingHoldService } from './normalized-booking-hold.service';
import { NormalizedBookingPaymentService } from './normalized-booking-payment.service';
import { NormalizedBookingRescheduleService } from './normalized-booking-reschedule.service';

const url = process.env.TEST_DATABASE_URL;
const databaseName = process.env.TEST_DATABASE_NAME;
const writesEnabled = process.env.CAPACITY_INTEGRATION_ALLOW_WRITES === 'true';
let host = '';
try { host = url ? new URL(url).hostname : ''; } catch { host = ''; }
const localHost = host === 'localhost' || host === '127.0.0.1' || host === '::1';
const enabled = Boolean(url && databaseName && writesEnabled && localHost);
const describeIntegration = enabled ? describe : describe.skip;

type Fixture = { partnerId: string; venueId: string; activityId: string; facilityId: string; userId: string; slotIds: string[] };

describeIntegration('disposable PostgreSQL capacity protocol', () => {
  let prisma: PrismaService;
  let fixture: Fixture;
  const holdService = new NormalizedBookingHoldService();
  const paymentService = new NormalizedBookingPaymentService();
  const rescheduleService = new NormalizedBookingRescheduleService();

  beforeAll(async () => {
    if (process.env.DATABASE_URL && url === process.env.DATABASE_URL) throw new Error('Refusing test database equal to DATABASE_URL');
    const config = { get: (key: string) => key === 'DATABASE_URL' ? url : undefined } as unknown as ConfigService;
    prisma = new PrismaService(config);
    await prisma.$connect();
    const identity = await prisma.$queryRaw<Array<{ database_name: string }>>`SELECT current_database() AS database_name`;
    if (identity[0]?.database_name !== databaseName) throw new Error('Refusing test database: identity mismatch');
    fixture = await createFixture(prisma);
  });

  afterAll(async () => {
    if (prisma && fixture) await destroyFixture(prisma, fixture);
    await prisma?.$disconnect();
  });

  beforeEach(async () => {
    await prisma.partner_walk_in_reservations.deleteMany({ where: { partner_id: fixture.partnerId } });
    await prisma.payments.deleteMany({ where: { bookings: { user_id: fixture.userId } } });
    await prisma.bookings.deleteMany({ where: { user_id: fixture.userId } });
    await prisma.booking_attempts.deleteMany({ where: { user_id: fixture.userId } });
    await prisma.slots.updateMany({ where: { id: { in: fixture.slotIds } }, data: { booked_quantity: 0 } });
  });

  async function occupancy(tx: any, slotId: string): Promise<number> {
    const slot = await tx.slots.findUnique({ where: { id: slotId }, select: { starts_at: true, ends_at: true, capacity: true, booked_quantity: true, status: true, facility_id: true } });
    const [bookings, attempts, walkIns] = await Promise.all([
      tx.bookings.findMany({ where: { slot_id: slotId }, select: { id: true, attempt_id: true, status: true, slots: { select: { ends_at: true } } } }),
      tx.booking_attempts.findMany({ where: { slot_id: slotId }, select: { status: true, quantity: true, expires_at: true, bookings: { select: { id: true } } } }),
      tx.partner_walk_in_reservations.findMany({ where: { facility_id: slot.facility_id }, select: { status: true, participant_count: true, starts_at: true, ends_at: true } }),
    ]);
    return effectiveSlotOccupancy({
      bookings: bookings.map((b: any) => ({ id: b.id, attemptId: b.attempt_id, status: b.status, quantity: 1, startsAt: slot.starts_at, endsAt: b.slots.ends_at })),
      attempts: attempts.map((a: any) => ({ status: a.status, quantity: a.quantity, expiresAt: a.expires_at, bookingId: a.bookings?.id ?? null })),
      walkIns: walkIns.map((w: any) => ({ status: w.status, participantCount: w.participant_count, startsAt: w.starts_at, endsAt: w.ends_at })),
    });
  }

  async function claimWalkIn(slotId: string, name: string): Promise<number> {
    return prisma.$transaction(async tx => {
      await lockSlotsForCapacity(tx, [slotId]);
      const slot = await tx.slots.findUnique({ where: { id: slotId }, select: { capacity: true, status: true, facility_id: true, starts_at: true, ends_at: true } });
      const used = await occupancy(tx, slotId);
      if (slot.status !== 'AVAILABLE' || used >= slot.capacity) return 0;
      const row = await tx.partner_walk_in_reservations.create({ data: {
        id: randomUUID(), partner_id: fixture.partnerId, venue_id: fixture.venueId,
        facility_id: slot.facility_id, participant_name: name, participant_count: 1,
        starts_at: slot.starts_at, ends_at: slot.ends_at, status: 'RESERVED', updated_at: new Date(),
      } });
      return row.id ? 1 : 0;
    });
  }

  it('allows only one concurrent walk-in claim for final capacity', async () => {
    const [first, second] = await Promise.all([claimWalkIn(fixture.slotIds[0], 'test-a'), claimWalkIn(fixture.slotIds[0], 'test-b')]);
    expect([first, second].sort()).toEqual([0, 1]);
  });

  it('serializes a walk-in against a user hold', async () => {
    const [walkIn, hold] = await Promise.all([
      claimWalkIn(fixture.slotIds[1], 'test-walk-in'),
      prisma.$transaction(async tx => {
        await lockSlotsForCapacity(tx, [fixture.slotIds[1]]);
        const slot = await tx.slots.findUnique({ where: { id: fixture.slotIds[1] }, select: { capacity: true } });
        const used = await occupancy(tx, fixture.slotIds[1]);
        if (used >= slot.capacity) return 0;
        await tx.booking_attempts.create({ data: { id: randomUUID(), user_id: fixture.userId, slot_id: fixture.slotIds[1], quantity: 1, idempotency_key: `hold-${randomUUID()}`, quote_snapshot: {}, expires_at: new Date(Date.now() + 600000), updated_at: new Date() } });
        return 1;
      }),
    ]);
    expect([walkIn, hold].sort()).toEqual([0, 1]);
  });

  it('enforces duplicate user/idempotency keys', async () => {
    const key = `duplicate-${randomUUID()}`;
    await prisma.booking_attempts.create({ data: { id: randomUUID(), user_id: fixture.userId, slot_id: fixture.slotIds[0], quantity: 1, idempotency_key: key, quote_snapshot: {}, expires_at: new Date(Date.now() + 600000), updated_at: new Date() } });
    await expect(prisma.booking_attempts.create({ data: { id: randomUUID(), user_id: fixture.userId, slot_id: fixture.slotIds[0], quantity: 1, idempotency_key: key, quote_snapshot: {}, expires_at: new Date(Date.now() + 600000), updated_at: new Date() } })).rejects.toThrow();
  });

  it('creates and reuses a normalized booking hold without creating a booking', async () => {
    const key = `hold-${randomUUID()}`;
    const first = await prisma.$transaction(tx => holdService.createHold(tx, fixture.userId, fixture.slotIds[1], key, 1, 10));
    const second = await prisma.$transaction(tx => holdService.createHold(tx, fixture.userId, fixture.slotIds[1], key, 1, 10));
    const databaseNow = (await prisma.$queryRaw<Array<{ now: Date }>>`SELECT NOW() AS now`)[0].now;
    expect(first.status).toBe('HELD');
    expect(first.expiresAt.getTime()).toBeGreaterThan(databaseNow.getTime());
    expect(first.expiresAt.getTime()).toBeLessThanOrEqual(databaseNow.getTime() + 10 * 60 * 1000 + 1000);
    expect(second.id).toBe(first.id);
    expect(second.reused).toBe(true);
    expect(await prisma.bookings.count({ where: { attempt_id: first.id } })).toBe(0);
  });

  it('finalizes a valid hold once into PENDING_PAYMENT and is idempotent', async () => {
    const key = `finalize-${randomUUID()}`;
    const hold = await prisma.$transaction(tx => holdService.createHold(tx, fixture.userId, fixture.slotIds[1], key));
    const first = await prisma.$transaction(tx => holdService.finalizeHoldToPendingBooking(tx, hold.id));
    const second = await prisma.$transaction(tx => holdService.finalizeHoldToPendingBooking(tx, hold.id));
    expect(first.status).toBe('PENDING_PAYMENT');
    expect(first.publicCode).toMatch(/^ACTP-[0-9a-f]{32}$/);
    expect(second.id).toBe(first.id);
    expect(second.reused).toBe(true);
    expect(await prisma.booking_attempts.findUnique({ where: { id: hold.id } })).toMatchObject({ status: 'CONSUMED' });
  });

  it('rejects an expired hold before creating a booking', async () => {
    const hold = await prisma.$transaction(tx => holdService.createHold(tx, fixture.userId, fixture.slotIds[1], `expired-${randomUUID()}`, 1, 1));
    await prisma.booking_attempts.update({ where: { id: hold.id }, data: { expires_at: new Date(Date.now() - 1000) } });
    await expect(prisma.$transaction(tx => holdService.finalizeHoldToPendingBooking(tx, hold.id))).rejects.toThrow('expired or unavailable');
    expect(await prisma.bookings.count({ where: { attempt_id: hold.id } })).toBe(0);
  });

  it('rolls back a reservation row after a transaction failure', async () => {
    const id = randomUUID();
    await expect(prisma.$transaction(async tx => {
      await tx.partner_walk_in_reservations.create({ data: { id, partner_id: fixture.partnerId, venue_id: fixture.venueId, facility_id: fixture.facilityId, starts_at: new Date(), ends_at: new Date(Date.now() + 3600000), status: 'RESERVED', updated_at: new Date() } });
      throw new Error('intentional rollback');
    })).rejects.toThrow('intentional rollback');
    expect(await prisma.partner_walk_in_reservations.findUnique({ where: { id } })).toBeNull();
  });

  it('supports cancellation followed by a new reservation', async () => {
    expect(await claimWalkIn(fixture.slotIds[0], 'cancel-me')).toBe(1);
    const reservation = await prisma.partner_walk_in_reservations.findFirst({ where: { participant_name: 'cancel-me', status: 'RESERVED' } });
    await prisma.partner_walk_in_reservations.update({ where: { id: reservation!.id }, data: { status: 'CANCELLED', updated_at: new Date() } });
    expect(await claimWalkIn(fixture.slotIds[0], 'after-cancel')).toBe(1);
  });

  it('serializes payment confirmation against pending-booking expiry', async () => {
    const booking = await createPendingBooking(prisma, fixture.slotIds[0], new Date(Date.now() + 600000));
    const evidence = { bookingId: booking.id, provider: 'test-provider', providerOrderId: `order-${randomUUID()}`, providerPaymentId: `payment-${randomUUID()}`, amountPaise: 1000n };
    const [confirmation, expiry] = await Promise.all([
      prisma.$transaction(tx => paymentService.confirmCapturedPayment(tx, evidence)),
      prisma.$transaction(tx => paymentService.expirePendingPayment(tx, booking.id, new Date(Date.now() + 1200000))),
    ]);
    const finalBooking = await prisma.bookings.findUnique({ where: { id: booking.id }, select: { status: true } });
    expect(['CONFIRMED', 'CANCELLED']).toContain(finalBooking?.status);
    expect((finalBooking?.status === 'CONFIRMED') === (confirmation.paymentStatus === 'CAPTURED')).toBe(true);
    if (finalBooking?.status === 'CANCELLED') expect((expiry as boolean) || confirmation.paymentStatus === 'EXCEPTION_REVIEW').toBe(true);
  });

  it('serializes competing reschedules and preserves booking/payment history', async () => {
    const booking = await createConfirmedBooking(prisma, fixture.slotIds[0]);
    const payment = await prisma.payments.create({ data: { id: randomUUID(), booking_id: booking.id, provider: 'test-provider', provider_order_id: `order-${randomUUID()}`, provider_payment_id: `payment-${randomUUID()}`, status: 'CAPTURED', amount_paise: 1000n, updated_at: new Date() } });
    const [first, second] = await Promise.all([
      prisma.$transaction(tx => rescheduleService.rescheduleConfirmedBooking(tx, booking.id, fixture.slotIds[1])),
      prisma.$transaction(tx => rescheduleService.rescheduleConfirmedBooking(tx, booking.id, fixture.slotIds[1])),
    ]);
    const successes = [first, second].filter(result => !(result instanceof Error));
    expect(successes).toHaveLength(2);
    expect(successes.filter(result => result.idempotent)).toHaveLength(1);
    const finalBooking = await prisma.bookings.findUnique({ where: { id: booking.id }, include: { payments: true } });
    expect(finalBooking?.slot_id).toBe(fixture.slotIds[1]);
    expect(finalBooking?.booking_reference).toBe(booking.booking_reference);
    expect(finalBooking?.payments.some(row => row.id === payment.id)).toBe(true);
  });

  it('rejects a full destination without moving the booking', async () => {
    const booking = await createConfirmedBooking(prisma, fixture.slotIds[0]);
    await claimWalkIn(fixture.slotIds[1], 'destination-full');
    await expect(prisma.$transaction(tx => rescheduleService.rescheduleConfirmedBooking(tx, booking.id, fixture.slotIds[1]))).rejects.toThrow('capacity');
    expect((await prisma.bookings.findUnique({ where: { id: booking.id }, select: { slot_id: true } }))?.slot_id).toBe(fixture.slotIds[0]);
  });

  async function createPendingBooking(db: PrismaService, slotId: string, deadline: Date) {
    const attemptId = randomUUID();
    return db.$transaction(async tx => {
      await tx.booking_attempts.create({ data: { id: attemptId, user_id: fixture.userId, slot_id: slotId, quantity: 1, status: 'CONSUMED', idempotency_key: `payment-${randomUUID()}`, quote_snapshot: { policyVersion: 'v1', unitPricePaise: '1000' }, expires_at: new Date(Date.now() + 600000), updated_at: new Date() } });
      return tx.bookings.create({ data: { id: randomUUID(), public_code: `ACTP-${randomUUID().replace(/-/g, '')}`, user_id: fixture.userId, slot_id: slotId, attempt_id: attemptId, status: 'PENDING_PAYMENT', policy_version: 'v1', subtotal_paise: 1000n, discount_paise: 0n, total_paise: 1000n, starts_at: new Date(Date.now() + 3600000), payment_deadline: deadline, updated_at: new Date() } });
    });
  }

  async function createConfirmedBooking(db: PrismaService, slotId: string) {
    const booking = await createPendingBooking(db, slotId, new Date(Date.now() + 600000));
    return db.bookings.update({ where: { id: booking.id }, data: { status: 'CONFIRMED', updated_at: new Date() } });
  }

  async function createFixture(db: PrismaService): Promise<Fixture> {
    const ids = { partnerId: randomUUID(), venueId: randomUUID(), activityId: randomUUID(), facilityId: randomUUID(), userId: randomUUID(), slotIds: [randomUUID(), randomUUID()] };
    return db.$transaction(async tx => {
      await tx.partners.create({ data: { id: ids.partnerId, legal_name: 'capacity-test', status: 'ACTIVE', updated_at: new Date() } });
      await tx.venues.create({ data: { id: ids.venueId, public_reference: `TEST-${ids.venueId.slice(0, 8)}`, partner_id: ids.partnerId, name: 'capacity-test', city_code: 'TEST', latitude: 0, longitude: 0, status: 'PUBLISHED', policy_version: 'v1' } });
      await tx.activities.create({ data: { id: ids.activityId, sport_code: `TEST-${ids.activityId.slice(0, 8)}`, name: 'capacity-test', type: 'SINGLE', status: 'PUBLISHED' } });
      await tx.facilities.create({ data: { id: ids.facilityId, venue_id: ids.venueId, activity_id: ids.activityId, name: 'capacity-test', capacity: 1 } });
      await tx.users.create({ data: { id: ids.userId, phone_e164: `+1555${ids.userId.replace(/-/g, '').slice(0, 10)}`, status: 'ACTIVE', updated_at: new Date() } });
      await tx.slots.createMany({ data: ids.slotIds.map((id, index) => ({ id, facility_id: ids.facilityId, starts_at: new Date(Date.now() + (index + 1) * 3600000), ends_at: new Date(Date.now() + (index + 1) * 3600000 + 3600000), capacity: 1, booked_quantity: 0, status: 'AVAILABLE', price_paise: 1000n })) });
      return ids;
    });
  }

  async function destroyFixture(db: PrismaService, ids: Fixture): Promise<void> {
    await db.partner_walk_in_reservations.deleteMany({ where: { partner_id: ids.partnerId } });
    await db.payments.deleteMany({ where: { bookings: { user_id: ids.userId } } });
    await db.bookings.deleteMany({ where: { user_id: ids.userId } });
    await db.booking_attempts.deleteMany({ where: { user_id: ids.userId } });
    await db.slots.deleteMany({ where: { id: { in: ids.slotIds } } });
    await db.users.delete({ where: { id: ids.userId } });
    await db.facilities.delete({ where: { id: ids.facilityId } });
    await db.activities.delete({ where: { id: ids.activityId } });
    await db.venues.delete({ where: { id: ids.venueId } });
    await db.partners.delete({ where: { id: ids.partnerId } });
  }
});

if (!enabled) {
  test('capacity integration is not run without explicit local disposable database opt-in', () => {
    console.warn('SKIPPED capacity integration: configure localhost TEST_DATABASE_URL, TEST_DATABASE_NAME and CAPACITY_INTEGRATION_ALLOW_WRITES=true');
  });
}
