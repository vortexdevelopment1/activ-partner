import { ConflictException, NotFoundException } from '@nestjs/common';
import { Prisma } from '../../generated/prisma/client';
import { effectiveSlotOccupancy } from './slot-capacity';
import { lockSlotsForCapacity } from './slot-capacity-coordinator';

type RescheduleTransaction = Prisma.TransactionClient;

export type RescheduleResult = {
  bookingId: string;
  bookingReference: string;
  sourceSlotId: string;
  destinationSlotId: string;
  status: string;
  rescheduleCount: number;
  idempotent: boolean;
};

/** Internal only. Caller owns the transaction and authorization boundary. */
export class NormalizedBookingRescheduleService {
  async rescheduleConfirmedBooking(
    tx: RescheduleTransaction,
    bookingId: string,
    destinationSlotId: string,
    now = new Date(),
  ): Promise<RescheduleResult> {
    const booking = await tx.bookings.findUnique({
      where: { id: bookingId },
      include: { slots: true },
    });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.slot_id === destinationSlotId) return this.map(booking, booking.slot_id, true);
    if (booking.status !== 'CONFIRMED') throw new ConflictException('Only confirmed bookings can be rescheduled');

    await tx.$queryRaw`SELECT id FROM bookings WHERE id = ${booking.id}::uuid FOR UPDATE`;
    const lockedBooking = await tx.bookings.findUnique({ where: { id: booking.id }, include: { slots: true } });
    if (!lockedBooking) throw new NotFoundException('Booking not found');
    if (lockedBooking.slot_id === destinationSlotId) return this.map(lockedBooking, lockedBooking.slot_id, true);
    if (lockedBooking.status !== 'CONFIRMED') throw new ConflictException('Only confirmed bookings can be rescheduled');
    const destination = await tx.slots.findUnique({ where: { id: destinationSlotId }, select: { id: true, facility_id: true, starts_at: true, ends_at: true, capacity: true, status: true } });
    if (!destination) throw new NotFoundException('Destination slot not found');
    await lockSlotsForCapacity(tx, [booking.slot_id, destinationSlotId]);
    if (destination.status !== 'AVAILABLE') throw new ConflictException('Destination slot is not available');

    const [bookings, attempts, walkIns] = await Promise.all([
      tx.bookings.findMany({ where: { slot_id: destination.id }, select: { id: true, attempt_id: true, status: true, starts_at: true, slots: { select: { ends_at: true } } } }),
      tx.booking_attempts.findMany({ where: { slot_id: destination.id }, select: { status: true, quantity: true, expires_at: true, bookings: { select: { id: true } } } }),
      tx.partner_walk_in_reservations.findMany({ where: { facility_id: destination.facility_id }, select: { status: true, participant_count: true, starts_at: true, ends_at: true } }),
    ]);
    const occupancy = effectiveSlotOccupancy({
      bookings: bookings.map(row => ({ id: row.id, attemptId: row.attempt_id, status: row.status, quantity: 1, startsAt: row.starts_at, endsAt: row.slots.ends_at })),
      attempts: attempts.filter(row => row.expires_at > now).map(row => ({ status: row.status, quantity: row.quantity, expiresAt: row.expires_at, bookingId: row.bookings?.id ?? null })),
      walkIns: walkIns.map(row => ({ status: row.status, participantCount: row.participant_count, startsAt: row.starts_at, endsAt: row.ends_at })),
    });
    if (occupancy + 1 > destination.capacity) throw new ConflictException('Destination slot capacity is unavailable');

    const updated = await tx.bookings.updateMany({
      where: { id: lockedBooking.id, status: 'CONFIRMED', slot_id: lockedBooking.slot_id },
      data: { slot_id: destination.id, starts_at: destination.starts_at, reschedule_count: { increment: 1 }, updated_at: now },
    });
    if (updated.count !== 1) throw new ConflictException('Booking changed during rescheduling');
    return this.map({ ...lockedBooking, slot_id: destination.id, starts_at: destination.starts_at, reschedule_count: lockedBooking.reschedule_count + 1 }, lockedBooking.slot_id, false);
  }

  private map(record: any, sourceSlotId: string, idempotent: boolean): RescheduleResult {
    return { bookingId: record.id, bookingReference: record.booking_reference, sourceSlotId, destinationSlotId: record.slot_id, status: record.status, rescheduleCount: record.reschedule_count, idempotent };
  }
}
