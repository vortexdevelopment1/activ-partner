import { createHmac } from 'crypto';
import { createVerifiedRazorpayEvidence, verifyRazorpayPaymentSignature, verifyRazorpayWebhookSignature } from './razorpay-verification.adapter';

describe('Razorpay verification adapter', () => {
  const secret = 'test-secret';
  const orderId = 'order_test';
  const paymentId = 'pay_test';
  const signature = createHmac('sha256', secret).update(`${orderId}|${paymentId}`).digest('hex');

  it('verifies payment signatures deterministically', () => {
    expect(verifyRazorpayPaymentSignature(orderId, paymentId, signature, secret)).toBe(true);
    expect(verifyRazorpayPaymentSignature(orderId, paymentId, 'bad', secret)).toBe(false);
  });
  it('verifies webhook signatures against the raw body', () => {
    const body = JSON.stringify({ id: 'evt_test' });
    const webhookSignature = createHmac('sha256', secret).update(body).digest('hex');
    expect(verifyRazorpayWebhookSignature(body, webhookSignature, secret)).toBe(true);
    expect(verifyRazorpayWebhookSignature(JSON.stringify({ id: 'changed' }), webhookSignature, secret)).toBe(false);
  });
  it('requires matching INR amount before producing trusted evidence', () => {
    expect(createVerifiedRazorpayEvidence({ orderId, paymentId, signature, keySecret: secret, amountPaise: 1000n, expectedAmountPaise: 1000n, currency: 'INR' }).provider).toBe('razorpay');
    expect(() => createVerifiedRazorpayEvidence({ orderId, paymentId, signature, keySecret: secret, amountPaise: 999n, expectedAmountPaise: 1000n, currency: 'INR' })).toThrow('amount');
  });
});
