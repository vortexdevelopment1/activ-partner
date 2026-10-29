import { assertSlotCapacity } from './slot-capacity';

export type CapacityTransactionClient = {
  $queryRaw<T>(query: TemplateStringsArray, ...values: any[]): Promise<T>;
};

/**
 * Locks slots in deterministic UUID order for caller-owned transactions.
 * This helper only establishes serialization; it does not mutate counters or
 * reservation rows and is intentionally not wired into production writers.
 */
export async function lockSlotsForCapacity(
  tx: CapacityTransactionClient,
  slotIds: string[],
): Promise<void> {
  const uniqueIds = [...new Set(slotIds)].sort();
  for (const slotId of uniqueIds) {
    await tx.$queryRaw`SELECT id FROM slots WHERE id = ${slotId}::uuid FOR UPDATE`;
  }
}

/**
 * Validates a reservation against occupancy already read while the slot row
 * is locked. The caller must calculate occupancy from reservation records and
 * must not add booked_quantity to those same records.
 */
export function assertLockedSlotCapacity(
  capacity: number,
  reservationRowOccupancy: number,
  quantity = 1,
  status = 'AVAILABLE',
): void {
  if (status !== 'AVAILABLE') throw new Error('Slot is not available');
  assertSlotCapacity(capacity, reservationRowOccupancy, quantity);
}
