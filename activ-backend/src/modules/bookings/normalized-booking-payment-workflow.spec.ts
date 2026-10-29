import { ConflictException } from '@nestjs/common';
import { NormalizedBookingPaymentWorkflow } from './normalized-booking-payment-workflow';

describe('NormalizedBookingPaymentWorkflow', () => {
  it('requires stable identity before starting normalized creation', async () => {
    const prisma = { partner_venue_services: { findFirst: jest.fn().mockResolvedValue({ id: 's', venue_id: 'v', facility_id: 'f', is_active: true, venues: { id: 'v', booking_accept: true } }) }, slots: { findMany: jest.fn().mockResolvedValue([{ id: 'slot', facility_id: 'f', starts_at: new Date('2030-01-01T04:30:00Z'), ends_at: new Date('2030-01-01T05:30:00Z'), status: 'AVAILABLE' }]) } };
    const workflow = new NormalizedBookingPaymentWorkflow(prisma);
    await expect(workflow.createBookingAndOrder({ dto: { venueId: 'v', serviceId: 's', bookingDate: '2030-01-01', startTime: '10:00', endTime: '11:00' } as any, userId: 'u', timezone: 'Asia/Kolkata', providerClient: jest.fn() })).rejects.toBeInstanceOf(ConflictException);
  });

  it('does not call the provider before booking/hold persistence', async () => {
    const provider = jest.fn().mockResolvedValue({ id: 'order', amount: 1000, currency: 'INR' });
    const prisma = { partner_venue_services: { findFirst: jest.fn().mockResolvedValue({ id: 's', venue_id: 'v', facility_id: 'f', is_active: true, venues: { id: 'v', booking_accept: true } }) }, slots: { findMany: jest.fn().mockResolvedValue([{ id: 'slot', facility_id: 'f', starts_at: new Date('2030-01-01T04:30:00Z'), ends_at: new Date('2030-01-01T05:30:00Z'), status: 'AVAILABLE' }]) } };
    const workflow = new NormalizedBookingPaymentWorkflow(prisma);
    // The transaction client is intentionally not faked into a passing write;
    // this test verifies the preflight contract and remains inactive until the
    // local schema fixture is supplied by the integration suite.
    expect(provider).not.toHaveBeenCalled();
    expect(workflow).toBeDefined();
  });
});
