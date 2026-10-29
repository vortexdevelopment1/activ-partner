import { ConflictException, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Prisma } from '../../generated/prisma/client';
import { lockSlotsForCapacity } from './slot-capacity-coordinator';
import { createVerifiedRazorpayEvidence } from '../payments/razorpay-verification.adapter';

type PaymentTransaction = Prisma.TransactionClient;

export type VerifiedCapturedPayment = {
  bookingId: string;
  provider: string;
  providerOrderId: string;
  providerPaymentId: string;
  providerEventId?: string;
  amountPaise: bigint;
  observedAt?: Date;
};

export type PaymentConfirmationResult = {
  bookingId: string;
  paymentId: string;
  bookingStatus: string;
  paymentStatus: string;
  idempotent: boolean;
};

/** Internal only. The caller must obtain provider verification before invoking this service. */
export class NormalizedBookingPaymentService {
  async confirmRazorpayPayment(
    tx: PaymentTransaction,
    input: { bookingId: string; orderId: string; paymentId: string; signature: string; keySecret: string; expectedAmountPaise: bigint; currency: string; eventId?: string },
  ): Promise<PaymentConfirmationResult> {
    const evidence = createVerifiedRazorpayEvidence({
      orderId: input.orderId,
      paymentId: input.paymentId,
      signature: input.signature,
      keySecret: input.keySecret,
      amountPaise: input.expectedAmountPaise,
      expectedAmountPaise: input.expectedAmountPaise,
      currency: input.currency,
      eventId: input.eventId,
    });
    const booking = await tx.bookings.findUnique({ where: { id: input.bookingId }, select: { id: true, total_paise: true } });
    if (!booking || booking.total_paise !== evidence.amountPaise) throw new ConflictException('Payment amount does not match booking');
    return this.confirmCapturedPayment(tx, { bookingId: booking.id, provider: evidence.provider, providerOrderId: evidence.orderId, providerPaymentId: evidence.paymentId, providerEventId: evidence.eventId, amountPaise: evidence.amountPaise });
  }

  /**
   * Order creation must be supplied by an approved Razorpay client. This
   * boundary deliberately refuses to fabricate order IDs or hold a database
   * transaction across the provider network call.
   */
  assertOrderCreationReady(input: { bookingStatus: string; paymentDeadline: Date | null; now?: Date }): void {
    const now = input.now ?? new Date();
    if (input.bookingStatus !== 'PENDING_PAYMENT') throw new ConflictException('Booking is not payable');
    if (!input.paymentDeadline || input.paymentDeadline <= now) throw new ConflictException('Payment deadline has expired');
  }

  async confirmCapturedPayment(
    tx: PaymentTransaction,
    evidence: VerifiedCapturedPayment,
  ): Promise<PaymentConfirmationResult> {
    if (!evidence.bookingId || !evidence.provider || !evidence.providerOrderId ||
      !evidence.providerPaymentId || evidence.amountPaise < 0n) {
      throw new ConflictException('Invalid verified payment evidence');
    }

    if (evidence.providerEventId) {
      const priorEvent = await tx.payments.findUnique({ where: { provider_event_id: evidence.providerEventId } });
      if (priorEvent) return this.map(priorEvent, priorEvent.status === 'CAPTURED');
    }

    const booking = await tx.bookings.findUnique({
      where: { id: evidence.bookingId },
      include: { booking_attempts: true, slots: true },
    });
    if (!booking) throw new NotFoundException('Booking not found');
    await lockSlotsForCapacity(tx, [booking.slot_id]);
    await tx.$queryRaw`SELECT id FROM bookings WHERE id = ${booking.id}::uuid FOR UPDATE`;

    const existingPayment = await tx.payments.findFirst({
      where: { booking_id: booking.id, provider: evidence.provider, provider_order_id: evidence.providerOrderId },
      orderBy: { created_at: 'asc' },
    });
    if (existingPayment) {
      // Order creation intentionally has no provider payment ID yet.  Attach
      // the first verified capture to that CREATED order; reject only a
      // genuinely conflicting already-recorded provider payment ID.
      if ((existingPayment.provider_payment_id && existingPayment.provider_payment_id !== evidence.providerPaymentId) || existingPayment.amount_paise !== evidence.amountPaise) {
        throw new ConflictException('Payment evidence does not match the existing payment');
      }
      if (existingPayment.status === 'CAPTURED' && booking.status === 'CONFIRMED') return this.map(existingPayment, true);
    }

    if (booking.total_paise !== evidence.amountPaise) throw new ConflictException('Payment amount does not match booking total');

    const now = evidence.observedAt ?? new Date();
    const attempt = booking.booking_attempts;
    const late = booking.status === 'CANCELLED' || booking.status === 'COMPLETED' || booking.status === 'NO_SHOW' ||
      booking.status === 'RESCHEDULED' || !attempt || attempt.status !== 'CONSUMED' || !booking.payment_deadline || booking.payment_deadline <= now;
    if (late) {
      const review = existingPayment ?? await tx.payments.create({ data: {
        id: randomUUID(), booking_id: booking.id, provider: evidence.provider,
        provider_order_id: evidence.providerOrderId, provider_payment_id: evidence.providerPaymentId,
        provider_event_id: evidence.providerEventId, status: 'EXCEPTION_REVIEW', amount_paise: evidence.amountPaise,
        updated_at: now,
      } });
      return this.map(review, false);
    }

    if (booking.status !== 'PENDING_PAYMENT') throw new ConflictException('Booking cannot accept payment confirmation');

    const payment = existingPayment ?? await tx.payments.create({ data: {
      id: randomUUID(), booking_id: booking.id, provider: evidence.provider,
      provider_order_id: evidence.providerOrderId, provider_payment_id: evidence.providerPaymentId,
      provider_event_id: evidence.providerEventId, status: 'CAPTURED', amount_paise: evidence.amountPaise,
      updated_at: now,
    } });
    if (payment.status !== 'CAPTURED') {
      await tx.payments.updateMany({ where: { id: payment.id, status: { in: ['CREATED', 'AUTHORIZED'] } }, data: {
        status: 'CAPTURED', provider_payment_id: evidence.providerPaymentId,
        provider_event_id: evidence.providerEventId, updated_at: now,
      } });
    }
    const confirmed = await tx.bookings.updateMany({ where: { id: booking.id, status: 'PENDING_PAYMENT' }, data: { status: 'CONFIRMED', updated_at: now } });
    if (confirmed.count !== 1) throw new ConflictException('Booking changed during payment confirmation');
    return this.map({ ...payment, status: 'CAPTURED' }, false);
  }

  async refusePendingPaymentExpiry(tx: PaymentTransaction, bookingId: string): Promise<never> {
    const booking = await tx.bookings.findUnique({ where: { id: bookingId }, select: { id: true, status: true, booking_attempts: { select: { expires_at: true, status: true } } } });
    if (!booking) throw new NotFoundException('Booking not found');
    throw new ConflictException('Pending-payment expiry requires an approved payment deadline and reconciliation policy');
  }

  async expirePendingPayment(tx: PaymentTransaction, bookingId: string, now = new Date()): Promise<boolean> {
    const booking = await tx.bookings.findUnique({
      where: { id: bookingId },
      include: { booking_attempts: true, slots: true },
    });
    if (!booking) throw new NotFoundException('Booking not found');
    await lockSlotsForCapacity(tx, [booking.slot_id]);
    await tx.$queryRaw`SELECT id FROM bookings WHERE id = ${booking.id}::uuid FOR UPDATE`;
    if (booking.status !== 'PENDING_PAYMENT' || !booking.payment_deadline || booking.payment_deadline > now) return false;
    const uncertain = await tx.payments.findFirst({ where: { booking_id: booking.id, status: { in: ['AUTHORIZED', 'CAPTURED', 'EXCEPTION_REVIEW'] } } });
    if (uncertain) return false;
    const changed = await tx.bookings.updateMany({ where: { id: booking.id, status: 'PENDING_PAYMENT', payment_deadline: { lte: now } }, data: { status: 'CANCELLED', updated_at: now } });
    if (changed.count !== 1) return false;
    if (booking.booking_attempts?.status === 'CONSUMED') {
      await tx.booking_attempts.updateMany({ where: { id: booking.booking_attempts.id, status: 'CONSUMED' }, data: { status: 'RELEASED', updated_at: now } });
    }
    return true;
  }

  private map(payment: any, idempotent: boolean): PaymentConfirmationResult {
    return { bookingId: payment.booking_id, paymentId: payment.id, bookingStatus: idempotent ? 'CONFIRMED' : 'CONFIRMED', paymentStatus: payment.status, idempotent };
  }
}
