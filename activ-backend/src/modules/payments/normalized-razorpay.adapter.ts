import { BadRequestException, ConflictException } from '@nestjs/common';
import { createVerifiedRazorpayEvidence, verifyRazorpayWebhookSignature, VerifiedRazorpayEvidence } from './razorpay-verification.adapter';

export type NormalizedPaymentOrder = { bookingId: string; providerOrderId: string; amountPaise: bigint; currency: 'INR' };

/** Inactive boundary: callers must supply the server-created order association. */
export function verifyRazorpayPaymentForBooking(input: {
  booking: NormalizedPaymentOrder;
  orderId: string;
  paymentId: string;
  signature: string;
  keySecret: string;
}): VerifiedRazorpayEvidence {
  if (input.orderId !== input.booking.providerOrderId) throw new ConflictException('Payment order is not associated with this booking');
  return createVerifiedRazorpayEvidence({
    orderId: input.orderId, paymentId: input.paymentId, signature: input.signature,
    keySecret: input.keySecret, amountPaise: input.booking.amountPaise,
    expectedAmountPaise: input.booking.amountPaise, currency: input.booking.currency,
  });
}

export function verifyRazorpayCapturedWebhook(input: {
  rawBody: Buffer | string;
  signature: string;
  webhookSecret: string;
  expectedBooking: NormalizedPaymentOrder;
}): VerifiedRazorpayEvidence {
  if (!verifyRazorpayWebhookSignature(input.rawBody, input.signature, input.webhookSecret)) throw new BadRequestException('Invalid webhook signature');
  let payload: any;
  try { payload = JSON.parse(input.rawBody.toString()); } catch { throw new BadRequestException('Invalid webhook payload'); }
  if (payload?.event !== 'payment.captured') throw new ConflictException('Unsupported Razorpay webhook event');
  const entity = payload?.payload?.payment?.entity;
  if (!entity?.order_id || !entity?.id || entity.order_id !== input.expectedBooking.providerOrderId) throw new ConflictException('Webhook payment is not associated with this booking');
  const amountPaise = BigInt(entity.amount);
  if (entity.currency !== input.expectedBooking.currency || amountPaise !== input.expectedBooking.amountPaise) throw new ConflictException('Webhook amount or currency does not match booking');
  return { provider: 'razorpay', orderId: entity.order_id, paymentId: entity.id, amountPaise, currency: 'INR', eventId: payload.id };
}
