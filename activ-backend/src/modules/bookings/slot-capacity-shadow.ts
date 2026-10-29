export type ShadowSlot = {
  id: string;
  startsAt: Date;
  endsAt: Date;
  capacity: number;
  bookedQuantity: number;
  status: string;
};

export type ShadowBooking = {
  status: string;
  startsAt: Date;
  endsAt: Date;
  quantity?: number | null;
  id?: string;
  attemptId?: string | null;
};

export type ShadowAttempt = {
  status: string;
  expiresAt: Date;
  quantity: number;
  bookingId?: string | null;
};

export type ShadowWalkIn = {
  status: string;
  startsAt: Date;
  endsAt: Date;
  participantCount?: number | null;
};

export type SlotCapacityShadow = {
  slotId: string;
  existingOccupiedQuantity: number;
  reservationRowOccupiedQuantity: number;
  difference: number;
  existingAvailable: boolean;
  reservationRowsAvailable: boolean;
  staleBookedQuantity: boolean;
  statusCounts: Record<string, number>;
};

/** Mirrors the current getActivitySlots ACTIV-booking rule for one slot. */
function currentActivOccupancy(slot: ShadowSlot, bookings: ShadowBooking[]): number {
  return bookings
    .filter(booking => booking.status !== 'CANCELLED' && overlaps(slot.startsAt, slot.endsAt, booking.startsAt, booking.endsAt))
    .reduce((total, booking) => total + positive(booking.quantity), 0);
}

function proposedOccupancy(
  slot: ShadowSlot,
  bookings: ShadowBooking[],
  attempts: ShadowAttempt[],
  walkIns: ShadowWalkIn[],
  evaluatedAt: Date,
): number {
  const activeAttempts = attempts.filter(attempt =>
    attempt.expiresAt > evaluatedAt &&
    (attempt.status === 'HELD' || attempt.status === 'PAYMENT_PROCESSING'),
  );
  const activeBookings = bookings.filter(booking => {
    if (!overlaps(slot.startsAt, slot.endsAt, booking.startsAt, booking.endsAt)) return false;
    if (booking.status === 'CANCELLED' || booking.status === 'RESCHEDULED') return false;
    if (booking.status === 'COMPLETED' || booking.status === 'NO_SHOW') return evaluatedAt < slot.endsAt;
    if (booking.status === 'CONFIRMED') return true;
    if (booking.status !== 'PENDING_PAYMENT') return false;
    return activeAttempts.some(attempt =>
      (booking.id && attempt.bookingId === booking.id) ||
      (booking.attemptId && attempt.bookingId === booking.attemptId),
    );
  });
  const linkedAttemptBookingIds = new Set(activeBookings.map(booking => booking.id).filter(Boolean));
  const unlinkedAttempts = activeAttempts.filter(attempt => !attempt.bookingId || !linkedAttemptBookingIds.has(attempt.bookingId));
  const activeWalkIns = walkIns.filter(walkIn =>
    walkIn.status === 'RESERVED' && overlaps(slot.startsAt, slot.endsAt, walkIn.startsAt, walkIn.endsAt),
  );
  return activeBookings.reduce((total, booking) => total + positive(booking.quantity), 0) +
    unlinkedAttempts.reduce((total, attempt) => total + positive(attempt.quantity), 0) +
    activeWalkIns.reduce((total, walkIn) => total + positive(walkIn.participantCount), 0);
}

/**
 * Compares current availability semantics with the proposed reservation-row
 * semantics. This is pure and intentionally not connected to a controller.
 */
export function compareSlotCapacity(input: {
  slot: ShadowSlot;
  bookings: ShadowBooking[];
  attempts: ShadowAttempt[];
  walkIns: ShadowWalkIn[];
  evaluatedAt?: Date;
}): SlotCapacityShadow {
  const { slot, bookings, attempts, walkIns } = input;
  const evaluatedAt = input.evaluatedAt ?? new Date();
  const currentBookings = currentActivOccupancy(slot, bookings);
  const currentWalkIns = walkIns
    .filter(walkIn => walkIn.status === 'RESERVED' && overlaps(slot.startsAt, slot.endsAt, walkIn.startsAt, walkIn.endsAt))
    .reduce((total, walkIn) => total + positive(walkIn.participantCount), 0);
  const reservationRowOccupancy = proposedOccupancy(slot, bookings, attempts, walkIns, evaluatedAt);

  const statusCounts = bookings.reduce<Record<string, number>>((counts, booking) => {
    counts[booking.status] = (counts[booking.status] ?? 0) + 1;
    return counts;
  }, {});
  for (const walkIn of walkIns) {
    if (!overlaps(slot.startsAt, slot.endsAt, walkIn.startsAt, walkIn.endsAt)) continue;
    statusCounts[`WALK_IN:${walkIn.status}`] = (statusCounts[`WALK_IN:${walkIn.status}`] ?? 0) + 1;
  }
  for (const attempt of attempts) statusCounts[`ATTEMPT:${attempt.status}`] = (statusCounts[`ATTEMPT:${attempt.status}`] ?? 0) + 1;

  // Current getActivitySlots() treats these sources as alternative reasons for
  // unavailability, not additive quantities. Summing them would manufacture
  // mismatches whenever booked_quantity reflects the same ACTIV booking rows.
  const rowOccupiedQuantity = currentBookings + currentWalkIns;
  const existingOccupiedQuantity = Math.max(slot.bookedQuantity, rowOccupiedQuantity);
  return {
    slotId: slot.id,
    existingOccupiedQuantity,
    reservationRowOccupiedQuantity: reservationRowOccupancy,
    difference: reservationRowOccupancy - existingOccupiedQuantity,
    existingAvailable: slot.status === 'AVAILABLE' && existingOccupiedQuantity < slot.capacity,
    reservationRowsAvailable: slot.status === 'AVAILABLE' && reservationRowOccupancy < slot.capacity,
    staleBookedQuantity: slot.bookedQuantity !== 0 && slot.bookedQuantity !== rowOccupiedQuantity,
    statusCounts,
  };
}

function overlaps(aStart: Date, aEnd: Date, bStart: Date, bEnd: Date): boolean {
  return aStart < bEnd && aEnd > bStart;
}

function positive(value: number | null | undefined): number {
  return Number.isInteger(value) && value > 0 ? value : 0;
}
