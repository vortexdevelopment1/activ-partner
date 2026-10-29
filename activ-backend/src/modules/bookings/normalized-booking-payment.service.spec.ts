import { ConflictException } from '@nestjs/common';
import { NormalizedBookingPaymentService } from './normalized-booking-payment.service';

describe('NormalizedBookingPaymentService', () => {
  const service = new NormalizedBookingPaymentService();
  const evidence = { bookingId: 'booking', provider: 'razorpay', providerOrderId: 'order', providerPaymentId: 'payment', amountPaise: 1000n };

  function tx(overrides: any = {}) {
    return {
      payments: { findUnique: jest.fn().mockResolvedValue(null), findFirst: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue({ id: 'payment-row', booking_id: 'booking', status: 'CAPTURED', amount_paise: 1000n }), updateMany: jest.fn().mockResolvedValue({ count: 1 }), ...overrides.payments },
      booking_attempts: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      bookings: { findUnique: jest.fn().mockResolvedValue({ id: 'booking', slot_id: 'slot', status: 'PENDING_PAYMENT', total_paise: 1000n, payment_deadline: new Date('2030-01-01T11:00:00Z'), booking_attempts: { status: 'CONSUMED', expires_at: new Date('2030-01-01T10:00:00Z') }, slots: {} }), updateMany: jest.fn().mockResolvedValue({ count: 1 }), ...overrides.bookings },
      $queryRaw: jest.fn().mockResolvedValue([]),
    } as any;
  }

  it('records captured payment and confirms a pending booking', async () => {
    const result = await service.confirmCapturedPayment(tx(), { ...evidence, observedAt: new Date('2029-01-01T00:00:00Z') });
    expect(result).toMatchObject({ bookingId: 'booking', paymentId: 'payment-row', paymentStatus: 'CAPTURED' });
  });

  it('rejects an amount mismatch before writing payment state', async () => {
    await expect(service.confirmCapturedPayment(tx(), { ...evidence, amountPaise: 999n })).rejects.toThrow('amount does not match');
  });

  it('routes a late capture to exception review without confirming', async () => {
    const database = tx({ payments: { create: jest.fn().mockResolvedValue({ id: 'review', booking_id: 'booking', status: 'EXCEPTION_REVIEW', amount_paise: 1000n }) } });
    const result = await service.confirmCapturedPayment(database, { ...evidence, observedAt: new Date('2030-01-01T12:00:01Z') });
    expect(result.paymentStatus).toBe('EXCEPTION_REVIEW');
    expect(database.bookings.updateMany).not.toHaveBeenCalled();
  });

  it('rejects pending-payment expiry without a payment deadline contract', async () => {
    await expect(service.refusePendingPaymentExpiry(tx(), 'booking')).rejects.toBeInstanceOf(ConflictException);
  });

  it('connects verified Razorpay evidence to normalized confirmation', async () => {
    const signature = require('crypto').createHmac('sha256', 'secret').update('order|payment').digest('hex');
    const database = tx();
    const result = await service.confirmRazorpayPayment(database, { bookingId: 'booking', orderId: 'order', paymentId: 'payment', signature, keySecret: 'secret', expectedAmountPaise: 1000n, currency: 'INR' });
    expect(result.paymentStatus).toBe('CAPTURED');
  });

  it('requires a live payment deadline before order creation', () => {
    expect(() => service.assertOrderCreationReady({ bookingStatus: 'PENDING_PAYMENT', paymentDeadline: new Date('2020-01-01') })).toThrow('expired');
    expect(() => service.assertOrderCreationReady({ bookingStatus: 'CONFIRMED', paymentDeadline: new Date('2030-01-01') })).toThrow('not payable');
  });

  it('expires an abandoned pending booking and releases its consumed hold once', async () => {
    const database = tx({ bookings: { findUnique: jest.fn().mockResolvedValue({ id: 'booking', slot_id: 'slot', status: 'PENDING_PAYMENT', payment_deadline: new Date('2029-01-01T00:00:00Z'), booking_attempts: { id: 'attempt', status: 'CONSUMED' }, slots: {} }) } });
    expect(await service.expirePendingPayment(database, 'booking', new Date('2030-01-01T00:00:00Z'))).toBe(true);
    expect(database.bookings.updateMany).toHaveBeenCalled();
    expect(database.booking_attempts.updateMany).toHaveBeenCalledWith(expect.objectContaining({ data: { status: 'RELEASED', updated_at: expect.any(Date) } }));
  });
});
