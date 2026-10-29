import { randomBytes } from 'crypto';

/**
 * Generates a future normalized booking public code. This is intentionally
 * not wired into booking creation until the database contract is approved.
 * The database unique constraint remains the final collision authority.
 */
export function generateCandidatePublicCode(random = randomBytes): string {
  const entropy = random(16).toString('base64url');
  return `ACTP-${entropy}`;
}

/** A missing venue policy is a contract error, never a reason to invent v1. */
export function resolveBookingPolicyVersion(policyVersion: string | null | undefined): string {
  const normalized = policyVersion?.trim();
  if (!normalized) throw new Error('Booking policy version is missing');
  return normalized;
}

export function canReserveCapacity(
  capacity: number,
  bookedQuantity: number,
  quantity = 1,
): boolean {
  return Number.isInteger(capacity) && capacity >= 0 &&
    Number.isInteger(bookedQuantity) && bookedQuantity >= 0 &&
    Number.isInteger(quantity) && quantity > 0 &&
    bookedQuantity + quantity <= capacity;
}

export function nextBookedQuantity(
  capacity: number,
  bookedQuantity: number,
  quantity = 1,
): number {
  if (!canReserveCapacity(capacity, bookedQuantity, quantity)) {
    throw new Error('Slot capacity is unavailable');
  }
  return bookedQuantity + quantity;
}
