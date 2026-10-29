import { effectiveSlotOccupancy, assertSlotCapacity } from './slot-capacity';

describe('shared slot capacity calculation', () => {
  it('counts active walk-ins by participant quantity', () => {
    expect(effectiveSlotOccupancy({
      bookings: [], attempts: [],
      walkIns: [
        { status: 'RESERVED', participantCount: 2 },
        { status: 'CANCELLED', participantCount: 4 },
      ],
    })).toBe(2);
  });

  it('counts pending and confirmed bookings but not historical states', () => {
    expect(effectiveSlotOccupancy({
      bookings: [
        { status: 'PENDING_PAYMENT', quantity: 1 },
        { status: 'CONFIRMED', quantity: 2 },
        { status: 'COMPLETED', quantity: 9 },
        { status: 'CANCELLED', quantity: 9 },
      ], attempts: [], walkIns: [],
    })).toBe(3);
  });

  it('does not double-count an attempt linked to a booking', () => {
    expect(effectiveSlotOccupancy({
      bookings: [{ id: 'booking-1', status: 'PENDING_PAYMENT', quantity: 1, attemptId: 'attempt-1' }],
      attempts: [{ status: 'HELD', quantity: 1, bookingId: 'booking-1' }],
      walkIns: [],
    })).toBe(1);
  });

  it('counts active unlinked holds and ignores expired/released attempts', () => {
    expect(effectiveSlotOccupancy({
      bookings: [],
      attempts: [
        { status: 'HELD', quantity: 1 },
        { status: 'PAYMENT_PROCESSING', quantity: 2 },
        { status: 'EXPIRED', quantity: 8 },
        { status: 'RELEASED', quantity: 8 },
      ],
      walkIns: [],
    })).toBe(3);
  });

  it('rejects invalid or over-capacity reservations', () => {
    expect(() => assertSlotCapacity(2, 1, 1)).not.toThrow();
    expect(() => assertSlotCapacity(2, 2, 1)).toThrow('Slot capacity is unavailable');
    expect(() => assertSlotCapacity(2, -1, 1)).toThrow('Invalid slot occupancy');
    expect(() => assertSlotCapacity(2, 0, 0)).toThrow('Invalid reservation quantity');
  });
});
