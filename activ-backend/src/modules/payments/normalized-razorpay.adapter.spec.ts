import { createHmac } from 'crypto';
import { verifyRazorpayCapturedWebhook, verifyRazorpayPaymentForBooking } from './normalized-razorpay.adapter';

describe('inactive normalized Razorpay adapter', () => {
  const secret = 'secret';
  const booking = { bookingId: 'booking', providerOrderId: 'order_test', amountPaise: 1250n, currency: 'INR' as const };
  const paymentSignature = createHmac('sha256', secret).update('order_test|pay_test').digest('hex');

  it('requires the server-created order association', () => {
    expect(() => verifyRazorpayPaymentForBooking({ booking, orderId: 'other', paymentId: 'pay_test', signature: paymentSignature, keySecret: secret })).toThrow('associated');
  });

  it('verifies the signed payment against the normalized booking amount', () => {
    expect(verifyRazorpayPaymentForBooking({ booking, orderId: 'order_test', paymentId: 'pay_test', signature: paymentSignature, keySecret: secret })).toMatchObject({ orderId: 'order_test', amountPaise: 1250n });
  });

  it('validates raw captured webhook payloads and rejects mismatches', () => {
    const body = JSON.stringify({ id: 'evt_1', event: 'payment.captured', payload: { payment: { entity: { order_id: 'order_test', id: 'pay_test', amount: 1250, currency: 'INR' } } } });
    const signature = createHmac('sha256', secret).update(body).digest('hex');
    expect(verifyRazorpayCapturedWebhook({ rawBody: body, signature, webhookSecret: secret, expectedBooking: booking })).toMatchObject({ eventId: 'evt_1', paymentId: 'pay_test' });
    expect(() => verifyRazorpayCapturedWebhook({ rawBody: body, signature: 'bad', webhookSecret: secret, expectedBooking: booking })).toThrow('signature');
  });
});
