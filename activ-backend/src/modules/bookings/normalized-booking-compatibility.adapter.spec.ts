import { ConflictException } from '@nestjs/common';
import { mapLegacyCreateBookingToHoldInput, mapPendingBookingToLegacyResponse, mapVerifiedProviderEvidence } from './normalized-booking-compatibility.adapter';

describe('normalized booking compatibility adapters', () => {
  const dto: any = { venueId: 'venue', serviceId: 'service', bookingDate: '2030-01-01', startTime: '10:00', endTime: '11:00' };

  it('rejects legacy booking requests without an explicit slot', () => {
    expect(() => mapLegacyCreateBookingToHoldInput(dto, 'user', { idempotencyKey: 'key' })).toThrow(ConflictException);
  });

  it('maps a legacy-compatible hold request without resolving a slot implicitly', () => {
    expect(mapLegacyCreateBookingToHoldInput(dto, 'user', { slotId: 'slot', idempotencyKey: 'key' })).toEqual({ userId: 'user', slotId: 'slot', idempotencyKey: 'key', quantity: 1, holdMinutes: 10 });
  });

  it('preserves reference and converts paise for the legacy response', () => {
    const response = mapPendingBookingToLegacyResponse({ id: 'b', bookingReference: 'ACT-1', publicCode: 'ACTP-1', attemptId: 'a', userId: 'u', slotId: 's', status: 'PENDING_PAYMENT', policyVersion: 'v1', totalPaise: 1250n, reused: false });
    expect(response).toMatchObject({ bookingReference: 'ACT-1', amount: 12.5, amountPaise: '1250', paymentStatus: 'pending' });
  });

  it('requires provider verification before producing payment evidence', () => {
    expect(() => mapVerifiedProviderEvidence({ bookingId: 'b', provider: 'razorpay', orderId: 'o', paymentId: 'p', amountPaise: 100n, signatureVerified: false })).toThrow('not verified');
  });
});
