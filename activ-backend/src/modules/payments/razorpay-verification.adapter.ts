import { createHmac, timingSafeEqual } from 'crypto';
import { BadRequestException } from '@nestjs/common';

export type VerifiedRazorpayEvidence = {
  provider: 'razorpay';
  orderId: string;
  paymentId: string;
  amountPaise: bigint;
  currency: 'INR';
  eventId?: string;
};

export function verifyRazorpayPaymentSignature(orderId: string, paymentId: string, signature: string, secret: string): boolean {
  if (!orderId || !paymentId || !signature || !secret) return false;
  return safeEqual(createHmac('sha256', secret).update(`${orderId}|${paymentId}`).digest('hex'), signature);
}

export function verifyRazorpayWebhookSignature(rawBody: string | Buffer, signature: string, webhookSecret: string): boolean {
  if (!signature || !webhookSecret) return false;
  return safeEqual(createHmac('sha256', webhookSecret).update(rawBody).digest('hex'), signature);
}

export function createVerifiedRazorpayEvidence(input: {
  orderId: string; paymentId: string; signature: string; keySecret: string;
  amountPaise: bigint; expectedAmountPaise: bigint; currency: string; eventId?: string;
}): VerifiedRazorpayEvidence {
  if (input.currency !== 'INR' || input.amountPaise !== input.expectedAmountPaise) throw new BadRequestException('Payment amount or currency does not match booking');
  if (!verifyRazorpayPaymentSignature(input.orderId, input.paymentId, input.signature, input.keySecret)) throw new BadRequestException('Invalid payment signature');
  return { provider: 'razorpay', orderId: input.orderId, paymentId: input.paymentId, amountPaise: input.amountPaise, currency: 'INR', eventId: input.eventId };
}

function safeEqual(expected: string, actual: string): boolean {
  const left = Buffer.from(expected, 'utf8');
  const right = Buffer.from(actual, 'utf8');
  return left.length === right.length && timingSafeEqual(left, right);
}
