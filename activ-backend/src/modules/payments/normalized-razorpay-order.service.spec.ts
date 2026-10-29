import { ConflictException } from '@nestjs/common';
import { NormalizedRazorpayOrderService } from './normalized-razorpay-order.service';

describe('NormalizedRazorpayOrderService', () => {
  const service = new NormalizedRazorpayOrderService();
  const booking = { id: 'booking', user_id: 'user', status: 'PENDING_PAYMENT', total_paise: 1000n };
  const tx = (existing: any = null) => ({
    bookings: { findUnique: jest.fn().mockResolvedValue(booking) },
    payments: { findUnique: jest.fn().mockResolvedValue(existing), create: jest.fn().mockResolvedValue({ id: 'payment', booking_id: 'booking', amount_paise: 1000n, currency: 'INR', order_status: 'PENDING' }), updateMany: jest.fn().mockResolvedValue({ count: 1 }), findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'payment', provider_order_id: 'order' }) },
  } as any);
  const input: any = { bookingId: 'booking', userId: 'user', provider: 'razorpay', amountPaise: 1000n, currency: 'INR', paymentDeadline: new Date('2030-01-01T11:00:00Z'), now: new Date('2030-01-01T10:00:00Z'), providerClient: jest.fn() };

  it('reserves one local payment intent without calling the provider', async () => {
    const database = tx();
    const result = await service.createOrder(database, input);
    expect(result.reused).toBe(false);
    expect(input.providerClient).not.toHaveBeenCalled();
  });
  it('reuses a persisted provider order', async () => {
    const result = await service.createOrder(tx({ amount_paise: 1000n, currency: 'INR', order_status: 'CREATED', provider_order_id: 'order' }), input);
    expect(result.reused).toBe(true);
  });
  it('does not retry an uncertain external outcome', async () => {
    await expect(service.createOrder(tx({ amount_paise: 1000n, currency: 'INR', order_status: 'UNCERTAIN' }), input)).rejects.toBeInstanceOf(ConflictException);
  });
  it('conditionally persists a provider order', async () => {
    const result = await service.persistProviderOrder(tx(), 'booking:booking', { id: 'order', amount: 1000, currency: 'INR' });
    expect(result.provider_order_id).toBe('order');
  });
  it('reconciles an uncertain intent only from matching provider data', async () => {
    const database = tx({ payment_intent_key: 'booking:booking', amount_paise: 1000n, currency: 'INR', order_status: 'UNCERTAIN' });
    const result = await service.reconcileUncertainOrder(database, 'booking:booking', 'order_1', async () => ({ id: 'order_1', amount: 1000, currency: 'INR' }));
    expect(result.reconciled).toBe(true);
    expect(database.payments.updateMany).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ order_status: 'CREATED' }) }));
  });
  it('keeps an unmatched uncertain intent in manual review', async () => {
    const database = tx({ payment_intent_key: 'booking:booking', amount_paise: 1000n, currency: 'INR', order_status: 'UNCERTAIN' });
    const result = await service.reconcileUncertainOrder(database, 'booking:booking', 'order_1', async () => null);
    expect(result).toMatchObject({ reconciled: false, manualReviewRequired: true });
    expect(database.payments.updateMany).not.toHaveBeenCalled();
  });
});
