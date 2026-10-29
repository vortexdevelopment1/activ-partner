import { ConflictException } from '@nestjs/common';
import { CreateBookingDto } from './dto/create-booking.dto';
import { PendingBookingResult } from './normalized-booking-hold.service';
import { VerifiedCapturedPayment } from './normalized-booking-payment.service';
import type { ResolvedLegacySlot } from './legacy-slot-resolver';

export type NormalizedHoldInput = {
  userId: string;
  slotId: string;
  idempotencyKey: string;
  quantity: number;
  holdMinutes: number;
};

/**
 * Pure compatibility mapping. It is intentionally not called by a controller.
 * The legacy create DTO identifies a venue/service/time range, while the
 * normalized writer requires one concrete slot. Guessing a slot would risk
 * booking the wrong activity, so the adapter fails explicitly.
 */
export function mapLegacyCreateBookingToHoldInput(
  dto: CreateBookingDto,
  userId: string,
  options: { slotId?: string; idempotencyKey?: string; holdMinutes?: number },
): NormalizedHoldInput {
  if (!options.slotId) throw new ConflictException('Normalized booking requires an explicit slotId');
  if (!options.idempotencyKey?.trim()) throw new ConflictException('Normalized booking requires an idempotency key');
  return { userId, slotId: options.slotId, idempotencyKey: options.idempotencyKey, quantity: 1, holdMinutes: options.holdMinutes ?? 10 };
}

export function mapResolvedSlotToHoldInput(
  resolved: ResolvedLegacySlot,
  userId: string,
  idempotencyKey: string,
  holdMinutes = 10,
): NormalizedHoldInput {
  if (!resolved.slotId || !idempotencyKey.trim()) throw new ConflictException('Normalized booking mapping is incomplete');
  return { userId, slotId: resolved.slotId, idempotencyKey, quantity: 1, holdMinutes };
}

export function mapPendingBookingToLegacyResponse(result: PendingBookingResult) {
  return {
    id: result.id,
    bookingReference: result.bookingReference,
    publicCode: result.publicCode,
    status: result.status,
    userId: result.userId,
    slotId: result.slotId,
    amount: Number(result.totalPaise) / 100,
    amountPaise: result.totalPaise.toString(),
    paymentStatus: 'pending',
  };
}

/** Provider verification must happen before this boundary. */
export function mapVerifiedProviderEvidence(input: {
  bookingId: string;
  provider: string;
  orderId: string;
  paymentId: string;
  eventId?: string;
  amountPaise: bigint;
  signatureVerified: boolean;
}): VerifiedCapturedPayment {
  if (!input.signatureVerified) throw new ConflictException('Payment provider evidence is not verified');
  if (!input.orderId || !input.paymentId || input.amountPaise < 0n) throw new ConflictException('Incomplete payment provider evidence');
  return { bookingId: input.bookingId, provider: input.provider, providerOrderId: input.orderId, providerPaymentId: input.paymentId, providerEventId: input.eventId, amountPaise: input.amountPaise };
}
