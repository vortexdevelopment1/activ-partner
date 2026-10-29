import { Prisma } from '../../generated/prisma/client';

export type CapacityBooking = {
  id?: string;
  status: string;
  quantity?: number | null;
  attemptId?: string | null;
};

export type CapacityAttempt = {
  status: string;
  quantity: number;
  bookingId?: string | null;
};

export type CapacityWalkIn = {
  status: string;
  participantCount?: number | null;
};

/**
 * Computes occupancy from reservation records only. `booked_quantity` is
 * deliberately not an input: until reconciliation and writer migration are
 * complete, adding it would double-count the same reservations.
 */
export function effectiveSlotOccupancy(input: {
  bookings: CapacityBooking[];
  attempts: CapacityAttempt[];
  walkIns: CapacityWalkIn[];
}): number {
  const bookingIds = new Set(
    input.bookings
      .filter(booking => booking.status === 'PENDING_PAYMENT' || booking.status === 'CONFIRMED')
      .map(booking => booking.id)
      .filter((id): id is string => Boolean(id)),
  );

  const bookingQuantity = input.bookings.reduce((total, booking) => {
    if (booking.status !== 'PENDING_PAYMENT' && booking.status !== 'CONFIRMED') return total;
    return total + positiveQuantity(booking.quantity);
  }, 0);

  const unlinkedAttemptQuantity = input.attempts.reduce((total, attempt) => {
    if (attempt.status !== 'HELD' && attempt.status !== 'PAYMENT_PROCESSING') return total;
    if (attempt.bookingId && bookingIds.has(attempt.bookingId)) return total;
    return total + positiveQuantity(attempt.quantity);
  }, 0);

  const walkInQuantity = input.walkIns.reduce((total, reservation) => {
    if (reservation.status !== 'RESERVED') return total;
    return total + positiveQuantity(reservation.participantCount);
  }, 0);

  return bookingQuantity + unlinkedAttemptQuantity + walkInQuantity;
}

function positiveQuantity(value: number | null | undefined): number {
  return Number.isInteger(value) && value > 0 ? value : 0;
}

export function assertSlotCapacity(capacity: number, occupancy: number, requestedQuantity = 1): void {
  if (!Number.isInteger(capacity) || capacity < 0) throw new Error('Invalid slot capacity');
  if (!Number.isInteger(occupancy) || occupancy < 0) throw new Error('Invalid slot occupancy');
  if (!Number.isInteger(requestedQuantity) || requestedQuantity <= 0) throw new Error('Invalid reservation quantity');
  if (occupancy + requestedQuantity > capacity) throw new Error('Slot capacity is unavailable');
}

/**
 * Locks one slot for the duration of a caller-owned transaction. This helper
 * performs no capacity mutation and is intentionally not wired to any route.
 */
export async function lockSlotForCapacity(
  tx: { $queryRaw<T>(query: TemplateStringsArray, ...values: any[]): Promise<T> },
  slotId: string,
): Promise<void> {
  await tx.$queryRaw`SELECT id FROM slots WHERE id = ${slotId}::uuid FOR UPDATE`;
}

export type CapacityTransaction = Prisma.TransactionClient;
