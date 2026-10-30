import { ConflictException, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Prisma } from '../../generated/prisma/client';

type PaymentOrderTransaction = Prisma.TransactionClient;
export type RazorpayOrderResponse = { id: string; amount: number; currency: string };
export type RazorpayOrderClient = (input: { amountPaise: number; currency: 'INR'; receipt: string }) => Promise<RazorpayOrderResponse>;
export type RazorpayOrderLookup = (orderId: string) => Promise<{ id: string; amount: number; currency: string; status?: string } | null>;

export class NormalizedRazorpayOrderService {
  async reconcileUncertainOrder(
    tx: PaymentOrderTransaction,
    paymentIntentKey: string,
    providerOrderId: string,
    lookup: RazorpayOrderLookup,
    now = new Date(),
  ) {
    const intent = await tx.payments.findUnique({ where: { payment_intent_key: paymentIntentKey } });
    if (!intent) throw new NotFoundException('Payment intent not found');
    if (intent.order_status !== 'UNCERTAIN') throw new ConflictException('Payment intent is not awaiting reconciliation');
    const providerOrder = await lookup(providerOrderId);
    if (!providerOrder || providerOrder.id !== providerOrderId || providerOrder.currency !== intent.currency || BigInt(providerOrder.amount) !== intent.amount_paise) {
      return { payment: intent, reconciled: false, manualReviewRequired: true };
    }
    const updated = await tx.payments.updateMany({ where: { payment_intent_key: paymentIntentKey, order_status: 'UNCERTAIN' }, data: { provider_order_id: providerOrder.id, order_status: 'CREATED', updated_at: now } });
    if (updated.count !== 1) throw new ConflictException('Payment intent changed during reconciliation');
    return { payment: await tx.payments.findUniqueOrThrow({ where: { payment_intent_key: paymentIntentKey } }), reconciled: true, manualReviewRequired: false };
  }

  async createOrderWithProvider(
    prisma: { $transaction<T>(callback: (tx: PaymentOrderTransaction) => Promise<T>): Promise<T> },
    input: { bookingId: string; userId: string; provider: string; amountPaise: bigint; currency: string; paymentDeadline: Date | null; now?: Date; providerClient: RazorpayOrderClient },
  ) {
    const reserved = await prisma.$transaction(tx => this.createOrder(tx, input));
    if (reserved.reused) return reserved;
    try {
      const providerOrder = await input.providerClient({ amountPaise: Number(input.amountPaise), currency: 'INR', receipt: reserved.intentKey! });
      const payment = await prisma.$transaction(tx => this.persistProviderOrder(tx, reserved.intentKey!, providerOrder, input.now));
      return { payment, reused: false };
    } catch (error) {
      await prisma.$transaction(tx => this.markProviderUncertain(tx, reserved.intentKey!, input.now));
      throw error;
    }
  }

  async createOrder(
    tx: PaymentOrderTransaction,
    input: { bookingId: string; userId: string; provider: string; amountPaise: bigint; currency: string; paymentDeadline: Date | null; now?: Date; providerClient: RazorpayOrderClient },
  ) {
    const now = input.now ?? new Date();
    if (input.currency !== 'INR') throw new ConflictException('Only INR payments are supported');
    if (!input.paymentDeadline || input.paymentDeadline <= now) throw new ConflictException('Payment deadline has expired');
    const booking = await tx.bookings.findUnique({ where: { id: input.bookingId }, select: { id: true, user_id: true, status: true, total_paise: true } });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.user_id !== input.userId) throw new ConflictException('Booking does not belong to user');
    if (booking.status !== 'PENDING_PAYMENT' || booking.total_paise !== input.amountPaise) throw new ConflictException('Booking is not payable');

    const intentKey = `booking:${booking.id}`;
    // The User App predates payment_intent_key and can already have created a
    // Razorpay order for this booking. Reuse one exact legacy provider order
    // instead of creating a second gateway order. Never mutate that record or
    // claim it as this writer's intent.
    const legacyPayments = await tx.payments.findMany({
      where: { booking_id: booking.id, provider: input.provider },
      orderBy: { created_at: 'asc' },
      select: { id: true, amount_paise: true, currency: true, order_status: true, status: true, provider_order_id: true, provider_payment_id: true, payment_intent_key: true },
    });
    const legacyProviderOrders = legacyPayments.filter(payment => payment.provider_order_id && !payment.payment_intent_key);
    if (legacyProviderOrders.length > 1) throw new ConflictException('Multiple payment orders exist for this booking; manual reconciliation is required');
    const legacyOrder = legacyProviderOrders[0];
    if (legacyOrder) {
      if (legacyOrder.amount_paise !== input.amountPaise || legacyOrder.currency !== 'INR') throw new ConflictException('Existing payment order does not match booking');
      if (legacyOrder.status === 'CAPTURED' || legacyOrder.provider_payment_id) throw new ConflictException('Payment is already captured; order creation is not allowed');
      // A User App row created before the additive migration has no
      // order_status; after the column is added its default is PENDING. The
      // legacy status CREATED plus a persisted provider order is the only
      // accepted compatibility evidence, and this branch does not rewrite it.
      if (legacyOrder.order_status !== 'CREATED' && !(legacyOrder.order_status === 'PENDING' && legacyOrder.status === 'CREATED')) {
        throw new ConflictException('Existing payment order is not ready for reuse');
      }
      return { payment: legacyOrder, reused: true };
    }
    if (legacyPayments.some(payment => !payment.payment_intent_key && !payment.provider_order_id)) {
      throw new ConflictException('An existing payment record requires reconciliation before a new order can be created');
    }
    const existing = await tx.payments.findUnique({ where: { payment_intent_key: intentKey } });
    if (existing) {
      if (existing.amount_paise !== input.amountPaise || existing.currency !== 'INR') throw new ConflictException('Payment intent does not match booking');
      if (existing.order_status === 'CREATED' && existing.provider_order_id) return { payment: existing, reused: true };
      if (existing.order_status === 'PENDING' || existing.order_status === 'UNCERTAIN') throw new ConflictException('Payment order creation is already in progress or uncertain');
      throw new ConflictException('Payment order creation previously failed; reconcile before retrying');
    }
    const intent = await tx.payments.create({ data: { id: randomUUID(), booking_id: booking.id, provider: input.provider, payment_intent_key: intentKey, currency: 'INR', order_status: 'PENDING', status: 'CREATED', amount_paise: input.amountPaise, updated_at: now } });
    return { payment: intent, reused: false, intentKey };
  }

  async persistProviderOrder(tx: PaymentOrderTransaction, paymentIntentKey: string, response: RazorpayOrderResponse, now = new Date()) {
    if (response.currency !== 'INR' || !Number.isSafeInteger(response.amount) || response.amount <= 0) throw new ConflictException('Invalid provider order response');
    const updated = await tx.payments.updateMany({ where: { payment_intent_key: paymentIntentKey, order_status: 'PENDING', amount_paise: BigInt(response.amount) }, data: { provider_order_id: response.id, order_status: 'CREATED', updated_at: now } });
    if (updated.count !== 1) throw new ConflictException('Payment order intent changed during provider persistence');
    return tx.payments.findUniqueOrThrow({ where: { payment_intent_key: paymentIntentKey } });
  }

  async markProviderUncertain(tx: PaymentOrderTransaction, paymentIntentKey: string, now = new Date()) {
    await tx.payments.updateMany({ where: { payment_intent_key: paymentIntentKey, order_status: 'PENDING' }, data: { order_status: 'UNCERTAIN', updated_at: now } });
  }
}
