import { ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Prisma } from '../../generated/prisma/client';
import { effectiveSlotOccupancy } from './slot-capacity';
import { lockSlotsForCapacity } from './slot-capacity-coordinator';

type HoldTransaction = Prisma.TransactionClient;

export type BookingHoldResult = {
  id: string;
  userId: string;
  slotId: string;
  quantity: number;
  status: string;
  expiresAt: Date;
  policyVersion: string;
  unitPricePaise: bigint;
  reused: boolean;
};

export type PendingBookingResult = {
  id: string;
  bookingReference: string;
  publicCode: string;
  attemptId: string;
  userId: string;
  slotId: string;
  status: string;
  policyVersion: string;
  totalPaise: bigint;
  reused: boolean;
};

/** Internal only. No controller or module currently exposes this service. */
export class NormalizedBookingHoldService {
  async createHold(
    tx: HoldTransaction,
    userId: string,
    slotId: string,
    idempotencyKey: string,
    quantity = 1,
    holdMinutes = 10,
    now = new Date(),
    expectedOwnership?: { venueId: string; serviceId: string },
  ): Promise<BookingHoldResult> {
    if (!userId || !slotId || !idempotencyKey.trim()) throw new ConflictException('Invalid booking hold request');
    if (!Number.isInteger(quantity) || quantity <= 0) throw new ConflictException('Invalid reservation quantity');
    if (!Number.isInteger(holdMinutes) || holdMinutes <= 0) throw new ConflictException('Invalid hold duration');

    await lockSlotsForCapacity(tx, [slotId]);
    const databaseNow = await tx.$queryRaw<Array<{ now: Date }>>`SELECT NOW() AS now`;
    const effectiveNow = databaseNow[0]?.now ?? now;
    const slot = await tx.slots.findUnique({
      where: { id: slotId },
      select: {
        id: true, status: true, capacity: true, price_paise: true, starts_at: true, ends_at: true,
        facilities: { select: { id: true, venue_id: true, venues: { select: { id: true, policy_version: true, status: true, booking_accept: true } } } },
      },
    });
    if (!slot) throw new NotFoundException('Slot not found');
    if (expectedOwnership) {
      const ownedService = await tx.partner_venue_services.findFirst({ where: { id: expectedOwnership.serviceId, venue_id: expectedOwnership.venueId, facility_id: slot.facilities.id, is_active: true }, select: { id: true } });
      if (!ownedService || slot.facilities.venue_id !== expectedOwnership.venueId) throw new ForbiddenException('Slot does not belong to the requested venue or service');
    }
    if (slot.status !== 'AVAILABLE' || !slot.facilities.venues.booking_accept) throw new ForbiddenException('Slot is not available');
    if (!slot.facilities.venues.policy_version?.trim()) throw new ConflictException('Booking policy version is missing');

    const existing = await tx.booking_attempts.findUnique({ where: { user_id_idempotency_key: { user_id: userId, idempotency_key: idempotencyKey } } });
    if (existing) {
      const snapshot = (existing.quote_snapshot ?? {}) as Record<string, any>;
      if (existing.slot_id !== slotId || existing.quantity !== quantity || snapshot.policyVersion !== slot.facilities.venues.policy_version) {
        throw new ConflictException('Idempotency key was already used for a different booking request');
      }
      if ((existing.status === 'HELD' || existing.status === 'PAYMENT_PROCESSING') && existing.expires_at > effectiveNow) {
        return this.map(existing, slot.facilities.venues.policy_version, BigInt(snapshot.unitPricePaise ?? slot.price_paise), true);
      }
      throw new ConflictException('Booking hold has expired or is no longer reusable');
    }

    const [bookings, attempts, walkIns] = await Promise.all([
      tx.bookings.findMany({ where: { slot_id: slotId }, select: { id: true, attempt_id: true, status: true, starts_at: true, slots: { select: { ends_at: true } } } }),
      tx.booking_attempts.findMany({
        where: { slot_id: slotId, status: { in: ['HELD', 'PAYMENT_PROCESSING'] }, expires_at: { gt: effectiveNow } },
        select: { status: true, quantity: true, expires_at: true, bookings: { select: { id: true } } },
      }),
      tx.partner_walk_in_reservations.findMany({ where: { facility_id: slot.facilities.id }, select: { status: true, participant_count: true, starts_at: true, ends_at: true } }),
    ]);
    const occupancy = effectiveSlotOccupancy({
      bookings: bookings.map(booking => ({ id: booking.id, attemptId: booking.attempt_id, status: booking.status, quantity: 1, startsAt: booking.starts_at, endsAt: booking.slots.ends_at })),
      attempts: attempts.map(attempt => ({ status: attempt.status, quantity: attempt.quantity, expiresAt: attempt.expires_at, bookingId: attempt.bookings?.id ?? null })),
      walkIns: walkIns.map(walkIn => ({ status: walkIn.status, participantCount: walkIn.participant_count, startsAt: walkIn.starts_at, endsAt: walkIn.ends_at })),
    });
    if (occupancy + quantity > slot.capacity) throw new ConflictException('Slot capacity is unavailable');

    const expiresAt = new Date(effectiveNow.getTime() + holdMinutes * 60_000);
    const created = await tx.booking_attempts.create({ data: {
      id: randomUUID(), user_id: userId, slot_id: slotId, quantity,
      status: 'HELD', expires_at: expiresAt, idempotency_key: idempotencyKey,
      quote_snapshot: {
        slotId, facilityId: slot.facilities.id, venueId: slot.facilities.venue_id,
        policyVersion: slot.facilities.venues.policy_version, unitPricePaise: slot.price_paise.toString(),
        quantity, holdMinutes,
      },
      updated_at: effectiveNow,
    } });
    return this.map(created, slot.facilities.venues.policy_version, slot.price_paise, false);
  }

  async expireHold(tx: HoldTransaction, holdId: string, now = new Date()): Promise<boolean> {
    const hold = await tx.booking_attempts.findUnique({ where: { id: holdId }, select: { slot_id: true } });
    if (!hold) return false;
    await lockSlotsForCapacity(tx, [hold.slot_id]);
    const updated = await tx.booking_attempts.updateMany({
      where: { id: holdId, status: 'HELD', expires_at: { lte: now } },
      data: { status: 'EXPIRED', updated_at: now },
    });
    return updated.count === 1;
  }

  /**
   * Converts a valid hold into a pending-payment booking. It deliberately does
   * not create a payment or mark anything paid/confirmed.
   */
  async finalizeHoldToPendingBooking(
    tx: HoldTransaction,
    holdId: string,
    now = new Date(),
    paymentDeadline?: Date,
  ): Promise<PendingBookingResult> {
    const attempt = await tx.booking_attempts.findUnique({
      where: { id: holdId },
      include: { bookings: true, slots: { include: { facilities: { include: { venues: true } } } } },
    });
    if (!attempt) throw new NotFoundException('Booking hold not found');
    await lockSlotsForCapacity(tx, [attempt.slot_id]);

    if (attempt.bookings) {
      if (attempt.bookings.status !== 'PENDING_PAYMENT') throw new ConflictException('Booking hold is already finalized');
      return this.mapPendingBooking(attempt.bookings, true);
    }
    const databaseNow = await tx.$queryRaw<Array<{ now: Date }>>`SELECT NOW() AS now`;
    const effectiveNow = databaseNow[0]?.now ?? now;
    if (attempt.status !== 'HELD' || attempt.expires_at <= effectiveNow) {
      if (attempt.status === 'HELD' && attempt.expires_at <= effectiveNow) {
        await tx.booking_attempts.updateMany({ where: { id: holdId, status: 'HELD', expires_at: { lte: effectiveNow } }, data: { status: 'EXPIRED', updated_at: effectiveNow } });
      }
      throw new ConflictException('Booking hold is expired or unavailable');
    }
    const snapshot = (attempt.quote_snapshot ?? {}) as Record<string, any>;
    const policyVersion = String(snapshot.policyVersion ?? attempt.slots.facilities.venues.policy_version ?? '').trim();
    if (!policyVersion) throw new ConflictException('Booking policy version is missing');
    const unitPricePaise = BigInt(snapshot.unitPricePaise ?? 0);
    const subtotalPaise = unitPricePaise * BigInt(attempt.quantity);
    const discountPaise = BigInt(snapshot.discountPaise ?? 0);
    const totalPaise = subtotalPaise - discountPaise;
    if (totalPaise < 0n) throw new ConflictException('Invalid booking quote');

    let booking: any;
    for (let attemptNumber = 0; attemptNumber < 3; attemptNumber++) {
      try {
        booking = await tx.bookings.create({ data: {
          id: randomUUID(), public_code: generatePublicCode(), user_id: attempt.user_id,
          slot_id: attempt.slot_id, attempt_id: attempt.id, status: 'PENDING_PAYMENT',
          policy_version: policyVersion, subtotal_paise: subtotalPaise, discount_paise: discountPaise,
          total_paise: totalPaise, starts_at: attempt.slots.starts_at, payment_deadline: paymentDeadline,
          updated_at: effectiveNow,
        } });
        break;
      } catch (error) {
        if ((error as any)?.code !== 'P2002' || !String((error as any)?.meta?.target ?? '').includes('public_code') || attemptNumber === 2) throw error;
      }
    }
    const consumed = await tx.booking_attempts.updateMany({ where: { id: attempt.id, status: 'HELD', expires_at: { gt: effectiveNow } }, data: { status: 'CONSUMED', updated_at: effectiveNow } });
    if (consumed.count !== 1) throw new ConflictException('Booking hold changed during finalization');
    return this.mapPendingBooking(booking, false);
  }

  private map(record: any, policyVersion: string, unitPricePaise: bigint, reused: boolean): BookingHoldResult {
    return { id: record.id, userId: record.user_id, slotId: record.slot_id, quantity: record.quantity,
      status: record.status, expiresAt: record.expires_at, policyVersion, unitPricePaise, reused };
  }

  private mapPendingBooking(record: any, reused: boolean): PendingBookingResult {
    return { id: record.id, bookingReference: record.booking_reference, publicCode: record.public_code,
      attemptId: record.attempt_id, userId: record.user_id, slotId: record.slot_id, status: record.status,
      policyVersion: record.policy_version, totalPaise: record.total_paise, reused };
  }
}

function generatePublicCode(): string {
  return `ACTP-${randomUUID().replace(/-/g, '')}`;
}
