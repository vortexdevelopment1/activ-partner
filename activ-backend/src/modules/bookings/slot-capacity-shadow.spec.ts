import { compareSlotCapacity } from './slot-capacity-shadow';

const slot = (overrides: Partial<Parameters<typeof compareSlotCapacity>[0]['slot']> = {}) => ({
  id: 'slot-1',
  startsAt: new Date('2026-10-29T10:00:00Z'),
  endsAt: new Date('2026-10-29T11:00:00Z'),
  capacity: 2,
  bookedQuantity: 0,
  status: 'AVAILABLE',
  ...overrides,
});

const booking = (status: string, quantity = 1, overrides: Partial<Parameters<typeof compareSlotCapacity>[0]['bookings'][number]> = {}) => ({
  status,
  quantity,
  startsAt: new Date('2026-10-29T10:00:00Z'),
  endsAt: new Date('2026-10-29T11:00:00Z'),
  ...overrides,
});

describe('slot capacity shadow comparison', () => {
  it('compares an empty slot consistently', () => {
    const result = compareSlotCapacity({ slot: slot(), bookings: [], attempts: [], walkIns: [] });
    expect(result.existingOccupiedQuantity).toBe(0);
    expect(result.reservationRowOccupiedQuantity).toBe(0);
    expect(result.existingAvailable).toBe(true);
  });

  it('exposes stale counter differences without changing availability', () => {
    const result = compareSlotCapacity({ slot: slot({ bookedQuantity: 1 }), bookings: [], attempts: [], walkIns: [] });
    expect(result.staleBookedQuantity).toBe(true);
    expect(result.existingOccupiedQuantity).toBe(1);
    expect(result.reservationRowOccupiedQuantity).toBe(0);
    expect(result.difference).toBe(-1);
  });

  it('keeps linked attempts from being double-counted', () => {
    const result = compareSlotCapacity({
      slot: slot({ capacity: 1 }),
      bookings: [booking('PENDING_PAYMENT', 1, { id: 'booking-1', attemptId: 'attempt-1' })],
      attempts: [{ status: 'HELD', quantity: 1, bookingId: 'booking-1', expiresAt: new Date('2026-10-29T10:05:00Z') }],
      walkIns: [],
      evaluatedAt: new Date('2026-10-29T10:01:00Z'),
    });
    expect(result.reservationRowOccupiedQuantity).toBe(1);
  });

  it('uses time overlap and excludes expired attempts', () => {
    const result = compareSlotCapacity({
      slot: slot({ capacity: 1 }),
      bookings: [
        booking('CONFIRMED'),
        booking('CONFIRMED', 1, { startsAt: new Date('2026-10-29T12:00:00Z'), endsAt: new Date('2026-10-29T13:00:00Z') }),
      ],
      attempts: [{ status: 'HELD', quantity: 1, expiresAt: new Date('2026-10-29T09:00:00Z') }],
      walkIns: [],
      evaluatedAt: new Date('2026-10-29T10:30:00Z'),
    });
    expect(result.reservationRowOccupiedQuantity).toBe(1);
  });

  it('shows current-versus-proposed differences for completed, no-show and rescheduled states', () => {
    const result = compareSlotCapacity({
      slot: slot({ capacity: 3 }),
      bookings: [booking('COMPLETED'), booking('NO_SHOW'), booking('RESCHEDULED')],
      attempts: [], walkIns: [],
      evaluatedAt: new Date('2026-10-29T10:30:00Z'),
    });
    expect(result.existingOccupiedQuantity).toBe(3);
    expect(result.reservationRowOccupiedQuantity).toBe(2);
    expect(result.statusCounts).toEqual({ COMPLETED: 1, NO_SHOW: 1, RESCHEDULED: 1 });
  });

  it('releases completed and no-show capacity after the slot ends', () => {
    const result = compareSlotCapacity({
      slot: slot({ capacity: 1 }),
      bookings: [booking('COMPLETED'), booking('NO_SHOW')],
      attempts: [], walkIns: [],
      evaluatedAt: new Date('2026-10-29T11:01:00Z'),
    });
    expect(result.reservationRowOccupiedQuantity).toBe(0);
  });

  it('requires a valid active hold for pending-payment occupancy', () => {
    const result = compareSlotCapacity({
      slot: slot({ capacity: 2 }),
      bookings: [booking('PENDING_PAYMENT')],
      attempts: [
        { status: 'HELD', quantity: 1, expiresAt: new Date('2026-10-29T09:00:00Z') },
      ],
      walkIns: [],
      evaluatedAt: new Date('2026-10-29T10:01:00Z'),
    });
    expect(result.reservationRowOccupiedQuantity).toBe(0);
  });

  it('counts walk-in participants and blocked slots remain unavailable', () => {
    const result = compareSlotCapacity({
      slot: slot({ status: 'BLOCKED', capacity: 3 }), bookings: [], attempts: [],
      walkIns: [{ status: 'RESERVED', participantCount: 2, startsAt: slot().startsAt, endsAt: slot().endsAt }],
    });
    expect(result.reservationRowOccupiedQuantity).toBe(2);
    expect(result.existingAvailable).toBe(false);
    expect(result.reservationRowsAvailable).toBe(false);
  });

  it('classifies confirmed booking plus NO_SHOW walk-ins plus a stale counter', () => {
    const result = compareSlotCapacity({
      slot: slot({ capacity: 1, bookedQuantity: 1 }),
      bookings: [booking('CONFIRMED')],
      attempts: [],
      walkIns: [
        { status: 'NO_SHOW', participantCount: 1, startsAt: slot().startsAt, endsAt: slot().endsAt },
        { status: 'NO_SHOW', participantCount: 1, startsAt: new Date('2026-10-29T12:00:00Z'), endsAt: new Date('2026-10-29T13:00:00Z') },
      ],
      evaluatedAt: new Date('2026-10-29T00:13:44Z'),
    });
    // Existing availability uses the counter and row occupancy as alternative
    // signals; the comparator must not double-count the same booking.
    expect(result.existingOccupiedQuantity).toBe(1);
    expect(result.reservationRowOccupiedQuantity).toBe(1);
    expect(result.difference).toBe(0);
    expect(result.staleBookedQuantity).toBe(false);
    expect(result.statusCounts['WALK_IN:NO_SHOW']).toBe(1);
  });
});
