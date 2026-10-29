import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { compareSlotCapacity } from './slot-capacity-shadow';

/**
 * These tests are deliberately opt-in. TEST_DATABASE_URL must point at a
 * disposable non-production PostgreSQL database. They never fall back to
 * DATABASE_URL or DB_* values and perform metadata-only inspection.
 */
const testDatabaseUrl = process.env.TEST_DATABASE_URL;
const expectedDatabaseName = process.env.TEST_DATABASE_NAME;
const allowWrites = process.env.TEST_DATABASE_ALLOW_WRITES === 'true';
const describeDatabase = testDatabaseUrl && expectedDatabaseName ? describe : describe.skip;
const describeWrites = allowWrites ? describe : describe.skip;
const inspectionMode = process.env.ACTIV_DB_INSPECTION_MODE === 'read-only';
const inspectionUrl = process.env.ACTIV_DB_INSPECTION_URL;
const inspectionDatabaseName = process.env.ACTIV_DB_INSPECTION_DATABASE_NAME;
const describeInspection = inspectionMode && inspectionUrl && inspectionDatabaseName ? describe : describe.skip;

type Row = Record<string, any>;

describeDatabase('normalized booking/payment PostgreSQL contract', () => {
  let prisma: PrismaService;

  beforeAll(async () => {
    if (process.env.DATABASE_URL && testDatabaseUrl === process.env.DATABASE_URL) {
      throw new Error('Refusing to run integration tests: TEST_DATABASE_URL matches DATABASE_URL');
    }
    const config = {
      get: (key: string) => key === 'DATABASE_URL' ? testDatabaseUrl : undefined,
    } as unknown as ConfigService;
    prisma = new PrismaService(config);
    await prisma.$connect();
    const identity = await prisma.$queryRaw<Row[]>`SELECT current_database() AS database_name`;
    if (identity[0]?.database_name !== expectedDatabaseName) {
      throw new Error('Refusing to run integration tests: database identity does not match TEST_DATABASE_NAME');
    }
  });

  afterAll(async () => {
    await prisma?.$disconnect();
  });

  const columns = async (table: string) => prisma.$queryRawUnsafe<Row[]>(`
    SELECT column_name, data_type, udt_name, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = '${table}'
    ORDER BY ordinal_position
  `);

  const constraints = async (table: string) => prisma.$queryRawUnsafe<Row[]>(`
    SELECT c.conname, c.contype::text AS constraint_type, pg_get_constraintdef(c.oid) AS definition
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public' AND t.relname = '${table}'
    ORDER BY c.conname
  `);

  const foreignKeys = async (table: string) => prisma.$queryRawUnsafe<Row[]>(`
    SELECT c.conname, pg_get_constraintdef(c.oid) AS definition
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public' AND t.relname = '${table}' AND c.contype = 'f'
    ORDER BY c.conname
  `);

  it.each([
    ['bookings', ['id', 'booking_reference', 'public_code', 'user_id', 'slot_id', 'attempt_id', 'status', 'policy_version', 'subtotal_paise', 'discount_paise', 'total_paise']],
    ['booking_attempts', ['id', 'user_id', 'slot_id', 'quantity', 'status', 'expires_at', 'idempotency_key', 'quote_snapshot']],
    ['slots', ['id', 'facility_id', 'starts_at', 'ends_at', 'capacity', 'booked_quantity', 'status']],
    ['payments', ['id', 'booking_id', 'provider', 'provider_order_id', 'provider_payment_id', 'provider_event_id', 'status', 'amount_paise']],
    ['facilities', ['id', 'venue_id', 'activity_id', 'capacity']],
    ['venues', ['id', 'partner_id', 'policy_version', 'booking_accept']],
    ['partner_walk_in_reservations', ['id', 'venue_id', 'facility_id', 'venue_service_id', 'starts_at', 'ends_at', 'status', 'amount_paise']],
  ] as const)('has required columns: %s', async (table, expected) => {
    const actual = new Set((await columns(table)).map(row => row.column_name));
    for (const column of expected) expect(actual).toContain(column);
  });

  it('has integer paise columns and required booking defaults', async () => {
    const bookingColumns = await columns('bookings');
    const paymentColumns = await columns('payments');
    const byName = (rows: Row[], name: string) => rows.find(row => row.column_name === name);

    for (const name of ['subtotal_paise', 'discount_paise', 'total_paise']) {
      expect(['int8', 'int4', 'int2']).toContain(byName(bookingColumns, name)?.udt_name);
    }
    expect(['int8', 'int4', 'int2']).toContain(byName(paymentColumns, 'amount_paise')?.udt_name);
    expect(byName(bookingColumns, 'booking_reference')?.column_default).toMatch(/generate_booking_reference\s*\(/i);
    expect(byName(bookingColumns, 'public_code')?.is_nullable).toBe('NO');
  });

  it('has the required idempotency and provider uniqueness constraints', async () => {
    const attemptConstraints = (await constraints('booking_attempts')).map(row => String(row.definition));
    const paymentConstraints = (await constraints('payments')).map(row => String(row.definition));
    expect(attemptConstraints.some(definition => /user_id.*idempotency_key|idempotency_key.*user_id/i.test(definition))).toBe(true);
    expect(paymentConstraints.some(definition => /provider.*provider_order_id|provider_order_id.*provider/i.test(definition))).toBe(true);
    expect(paymentConstraints.some(definition => /provider_event_id/i.test(definition))).toBe(true);
  });

  it('has foreign keys for booking, slot, payment and walk-in ownership', async () => {
    const required = [
      ['bookings', /user_id|slot_id/],
      ['booking_attempts', /user_id|slot_id/],
      ['payments', /booking_id/],
      ['slots', /facility_id/],
      ['partner_walk_in_reservations', /partner_id|venue_id/],
    ] as const;
    for (const [table, pattern] of required) {
      const definitions = (await foreignKeys(table)).map(row => String(row.definition));
      expect(definitions.some(definition => pattern.test(definition))).toBe(true);
    }
  });

  it('contains the Prisma enum values required by the contract', async () => {
    const rows = await prisma.$queryRaw<Row[]>`
      SELECT t.typname AS enum_name, e.enumlabel
      FROM pg_type t
      JOIN pg_enum e ON e.enumtypid = t.oid
      JOIN pg_namespace n ON n.oid = t.typnamespace
      WHERE n.nspname = 'public'
        AND t.typname IN ('BookingStatus', 'AttemptStatus', 'PaymentStatus', 'SlotStatus')
      ORDER BY t.typname, e.enumsortorder
    `;
    const values = new Map<string, string[]>();
    for (const row of rows) values.set(row.enum_name, [...(values.get(row.enum_name) ?? []), row.enumlabel]);
    expect(values.get('BookingStatus')).toEqual(expect.arrayContaining(['PENDING_PAYMENT', 'CONFIRMED', 'CANCELLED']));
    expect(values.get('AttemptStatus')).toEqual(expect.arrayContaining(['HELD', 'PAYMENT_PROCESSING', 'CONSUMED', 'EXPIRED', 'RELEASED']));
    expect(values.get('PaymentStatus')).toEqual(expect.arrayContaining(['CREATED', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'REFUND_PENDING', 'REFUNDED']));
    expect(values.get('SlotStatus')).toEqual(expect.arrayContaining(['AVAILABLE', 'BLOCKED', 'ARCHIVED']));
  });

  it('has unique booking reference and public code constraints', async () => {
    const definitions = (await constraints('bookings')).map(row => String(row.definition));
    expect(definitions.some(definition => /booking_reference/i.test(definition))).toBe(true);
    expect(definitions.some(definition => /public_code/i.test(definition))).toBe(true);
  });

  it('documents the current capacity-enforcement gap', async () => {
    const definitions = (await constraints('slots')).map(row => String(row.definition));
    const hasNonNegativeCheck = definitions.some(definition => /booked_quantity\s*>?=\s*0|capacity\s*>?\s*0/i.test(definition));
    if (!hasNonNegativeCheck) {
      throw new Error('CONTRACT GAP: slots has no verified database CHECK constraint for non-negative booked_quantity/capacity; atomic reservation still requires an approved constraint or equivalent locked transaction.');
    }
  });

  describeWrites('explicitly authorized transaction probes', () => {
    it('rolls back a transaction without leaving a temporary record', async () => {
      const marker = `contract-${Date.now()}`;
      await expect(prisma.$transaction(async tx => {
        await tx.$executeRaw`CREATE TEMP TABLE IF NOT EXISTS activ_contract_probe (marker text primary key) ON COMMIT DROP`;
        await tx.$executeRaw`INSERT INTO activ_contract_probe (marker) VALUES (${marker})`;
        throw new Error('intentional contract rollback');
      })).rejects.toThrow('intentional contract rollback');
    });

    it.todo('execute real booking-attempt idempotency writes with disposable fixtures');
    it.todo('execute conditional slot-capacity claims concurrently with disposable fixtures');
  });

  it.todo('prove two concurrent reservations cannot consume the final slot capacity against an isolated PostgreSQL database');
  it.todo('prove walk-in and user reservations share one atomic capacity invariant');
  it.todo('verify public_code generation and collision retry behavior');
  it.todo('verify payment-attempt/order idempotency and late-payment reconciliation');
});

if (!testDatabaseUrl || !expectedDatabaseName) {
  // Make the skip reason visible in normal Jest output without exposing any
  // environment value or attempting a production fallback.
  test('integration database unavailable', () => {
    console.warn('SKIPPED normalized booking contract integration tests: TEST_DATABASE_URL and TEST_DATABASE_NAME are required');
  });
}

/**
 * Main Supabase inspection mode. This is intentionally a separate suite from
 * the disposable-database suite above. It accepts only the explicitly named
 * inspection URL and executes metadata/SELECT statements; no write flag can
 * enable the transaction probes in this mode.
 */
describeInspection('main database read-only booking/payment inspection', () => {
  let prisma: PrismaService;

  beforeAll(async () => {
    if (process.env.DATABASE_URL && inspectionUrl === process.env.DATABASE_URL) {
      // The caller explicitly chose the main URL, but identity still must be
      // verified before any query other than current_database().
    }
    const config = {
      get: (key: string) => key === 'DATABASE_URL' ? inspectionUrl : undefined,
    } as unknown as ConfigService;
    prisma = new PrismaService(config);
    await prisma.$connect();
    const identity = await prisma.$queryRaw<Row[]>`SELECT current_database() AS database_name`;
    if (identity[0]?.database_name !== inspectionDatabaseName) {
      throw new Error('Refusing read-only inspection: database identity does not match ACTIV_DB_INSPECTION_DATABASE_NAME');
    }
  });

  afterAll(async () => {
    await prisma?.$disconnect();
  });

  it('reads the allowlisted booking/payment schema metadata', async () => {
    const result = await prisma.$queryRaw<Row[]>`
      SELECT table_name, column_name, data_type, udt_name, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name IN (
          'bookings', 'booking_attempts', 'slots', 'payments',
          'facilities', 'venues', 'partner_walk_in_reservations'
        )
      ORDER BY table_name, ordinal_position
    `;
    expect(result.length).toBeGreaterThan(0);
  });

  it('reads constraints, indexes, enums, functions and triggers without mutation', async () => {
    const [constraints, indexes, enums, functions, triggers] = await Promise.all([
      prisma.$queryRaw<Row[]>`
        SELECT c.conrelid::regclass::text AS table_name, c.conname,
               c.contype::text AS constraint_type,
               pg_get_constraintdef(c.oid) AS definition
        FROM pg_constraint c
        JOIN pg_namespace n ON n.oid = c.connamespace
        WHERE n.nspname = 'public'
          AND c.conrelid::regclass::text IN ('bookings', 'booking_attempts', 'slots', 'payments', 'partner_walk_in_reservations')
      `,
      prisma.$queryRaw<Row[]>`
        SELECT tablename, indexname, indexdef
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename IN ('bookings', 'booking_attempts', 'slots', 'payments', 'partner_walk_in_reservations')
      `,
      prisma.$queryRaw<Row[]>`
        SELECT t.typname AS enum_name, e.enumlabel
        FROM pg_type t
        JOIN pg_enum e ON e.enumtypid = t.oid
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE n.nspname = 'public'
          AND t.typname IN ('BookingStatus', 'AttemptStatus', 'PaymentStatus', 'SlotStatus')
        ORDER BY t.typname, e.enumsortorder
      `,
      prisma.$queryRaw<Row[]>`
        SELECT n.nspname AS schema_name, p.proname AS function_name,
               pg_get_function_identity_arguments(p.oid) AS arguments
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname IN ('generate_booking_reference')
      `,
      prisma.$queryRaw<Row[]>`
        SELECT event_object_table AS table_name, trigger_name, event_manipulation,
               action_statement
        FROM information_schema.triggers
        WHERE trigger_schema = 'public'
          AND event_object_table IN ('bookings', 'booking_attempts', 'slots', 'payments', 'partner_walk_in_reservations')
      `,
    ]);
    expect(Array.isArray(constraints)).toBe(true);
    expect(Array.isArray(indexes)).toBe(true);
    expect(Array.isArray(enums)).toBe(true);
    expect(Array.isArray(functions)).toBe(true);
    expect(Array.isArray(triggers)).toBe(true);
  });

  it('reads persisted capacity and payment association aggregates only', async () => {
    const [slots, bookings, walkIns, payments] = await Promise.all([
      prisma.$queryRaw<Row[]>`
        SELECT COUNT(*)::int AS slot_count,
               COALESCE(SUM(capacity), 0)::bigint AS total_capacity,
               COALESCE(SUM(booked_quantity), 0)::bigint AS total_booked_quantity,
               COUNT(*) FILTER (WHERE booked_quantity < 0)::int AS negative_booked_rows,
               COUNT(*) FILTER (WHERE booked_quantity > capacity)::int AS over_capacity_rows
        FROM public.slots
      `,
      prisma.$queryRaw<Row[]>`
        SELECT status, COUNT(*)::int AS count
        FROM public.bookings
        GROUP BY status
      `,
      prisma.$queryRaw<Row[]>`
        SELECT status, COUNT(*)::int AS count
        FROM public.partner_walk_in_reservations
        GROUP BY status
      `,
      prisma.$queryRaw<Row[]>`
        SELECT provider, status, COUNT(*)::int AS count
        FROM public.payments
        GROUP BY provider, status
      `,
    ]);
    expect(slots[0]).toBeDefined();
    expect(Array.isArray(bookings)).toBe(true);
    expect(Array.isArray(walkIns)).toBe(true);
    expect(Array.isArray(payments)).toBe(true);
  });

  it('shadow-compares a bounded slot sample without exposing customer data', async () => {
    const now = new Date();
    const rows = await prisma.slots.findMany({
      where: { starts_at: { gte: new Date(now.getTime() - 24 * 60 * 60 * 1000), lte: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000) } },
      orderBy: { starts_at: 'asc' },
      take: 100,
      select: {
        id: true, starts_at: true, ends_at: true, capacity: true, booked_quantity: true, status: true,
        bookings: { select: { id: true, status: true, starts_at: true, slots: { select: { ends_at: true } }, booking_attempts: { select: { id: true } } } },
        booking_attempts: { select: { id: true, status: true, quantity: true, expires_at: true, bookings: { select: { id: true } } } },
        facilities: { select: { partner_walk_in_reservations: { select: { status: true, starts_at: true, ends_at: true, participant_count: true } } } },
      },
    });
    const comparisons = rows.map((row: any) => compareSlotCapacity({
      slot: { id: row.id, startsAt: row.starts_at, endsAt: row.ends_at, capacity: row.capacity, bookedQuantity: row.booked_quantity, status: row.status },
      bookings: row.bookings.map((booking: any) => ({
        id: booking.id, status: booking.status, startsAt: booking.starts_at, endsAt: booking.slots.ends_at,
        quantity: booking.booking_attempts?.id ? 1 : 1, attemptId: booking.booking_attempts?.id ?? null,
      })),
      attempts: row.booking_attempts.map((attempt: any) => ({ status: attempt.status, quantity: attempt.quantity, expiresAt: attempt.expires_at, bookingId: attempt.bookings?.id ?? null })),
      walkIns: row.facilities.partner_walk_in_reservations.map((reservation: any) => ({ status: reservation.status, startsAt: reservation.starts_at, endsAt: reservation.ends_at, participantCount: reservation.participant_count })),
      evaluatedAt: now,
    }));
    const mismatchIndexes = comparisons
      .map((result, index) => ({ result, index, row: rows[index] }))
      .filter(({ result }) => result.difference !== 0 || result.existingAvailable !== result.reservationRowsAvailable);
    const mismatchDiagnostics = mismatchIndexes.map(({ result, index, row }) => {
      const statuses = result.statusCounts;
      const historical = ['COMPLETED', 'NO_SHOW', 'RESCHEDULED'].filter(status => statuses[status]);
      const activeHoldCount = row.booking_attempts.filter((attempt: any) =>
        (attempt.status === 'HELD' || attempt.status === 'PAYMENT_PROCESSING') && attempt.expires_at > now,
      ).length;
      const expiredHoldCount = row.booking_attempts.filter((attempt: any) =>
        (attempt.status === 'HELD' || attempt.status === 'PAYMENT_PROCESSING') && attempt.expires_at <= now,
      ).length;
      const categories: string[] = [];
      if (result.staleBookedQuantity) categories.push('stale_booked_quantity');
      if (historical.length) categories.push('historical_booking_status');
      if (activeHoldCount || expiredHoldCount) categories.push('active_or_expired_hold');
      if (Object.keys(statuses).some(key => key.startsWith('WALK_IN:'))) categories.push('walk_in_status_or_quantity');
      if (!categories.length) categories.push('time_overlap_or_other');
      return {
        sampleIndex: index,
        capacity: row.capacity,
        bookedQuantity: row.booked_quantity,
        existingOccupiedQuantity: result.existingOccupiedQuantity,
        proposedOccupiedQuantity: result.reservationRowOccupiedQuantity,
        difference: result.difference,
        existingAvailable: result.existingAvailable,
        proposedAvailable: result.reservationRowsAvailable,
        bookingStatusCounts: Object.fromEntries(Object.entries(statuses).filter(([key]) => !key.startsWith('WALK_IN:') && !key.startsWith('ATTEMPT:'))),
        walkInStatusCounts: Object.fromEntries(Object.entries(statuses).filter(([key]) => key.startsWith('WALK_IN:'))),
        activeHoldCount,
        expiredHoldCount,
        overlapClassification: {
          slotWindow: `${row.starts_at.toISOString()}..${row.ends_at.toISOString()}`,
          evaluatedAt: now.toISOString(),
          bookingRows: row.bookings.length,
          walkInRows: row.facilities.partner_walk_in_reservations.length,
          note: 'Reservation records were prefiltered by overlap with this slot; no customer or reservation identifiers are emitted.',
        },
        explanationCategories: categories,
      };
    });
    // Keep output aggregate/anonymized: sample index only, never IDs, names, phones, payments, or URLs.
    console.log(`READ_ONLY_SHADOW slots=${comparisons.length} mismatches=${mismatchDiagnostics.length} details=${JSON.stringify(mismatchDiagnostics)}`);
    expect(comparisons.length).toBeLessThanOrEqual(100);
  });
});

if (inspectionMode && (!inspectionUrl || !inspectionDatabaseName)) {
  test('read-only inspection configuration is incomplete', () => {
    throw new Error('SKIPPED: ACTIV_DB_INSPECTION_MODE=read-only requires ACTIV_DB_INSPECTION_URL and ACTIV_DB_INSPECTION_DATABASE_NAME; no database connection was attempted');
  });
}
