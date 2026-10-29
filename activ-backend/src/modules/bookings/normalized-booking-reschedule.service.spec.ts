import { ConflictException } from '@nestjs/common';
import { NormalizedBookingRescheduleService } from './normalized-booking-reschedule.service';

describe('NormalizedBookingRescheduleService', () => {
  const service = new NormalizedBookingRescheduleService();
  const booking = { id: 'booking', booking_reference: 'ACT-1', slot_id: 'source', status: 'CONFIRMED', reschedule_count: 0, starts_at: new Date('2030-01-01T10:00:00Z'), slots: { id: 'source' } };
  const tx = (destinationStatus = 'AVAILABLE') => ({
    bookings: { findUnique: jest.fn().mockResolvedValue(booking), findMany: jest.fn().mockResolvedValue([]), updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
    slots: { findUnique: jest.fn().mockResolvedValue({ id: 'destination', facility_id: 'facility', starts_at: new Date('2030-01-01T11:00:00Z'), ends_at: new Date('2030-01-01T12:00:00Z'), capacity: 1, status: destinationStatus }) },
    booking_attempts: { findMany: jest.fn().mockResolvedValue([]) }, partner_walk_in_reservations: { findMany: jest.fn().mockResolvedValue([]) },
    $queryRaw: jest.fn().mockResolvedValue([]),
  }) as any;

  it('moves a confirmed booking while preserving its reference', async () => {
    const database = tx();
    const result = await service.rescheduleConfirmedBooking(database, 'booking', 'destination');
    expect(result).toMatchObject({ bookingId: 'booking', bookingReference: 'ACT-1', destinationSlotId: 'destination', rescheduleCount: 1 });
  });

  it('rejects a blocked destination', async () => {
    await expect(service.rescheduleConfirmedBooking(tx('BLOCKED'), 'booking', 'destination')).rejects.toBeInstanceOf(ConflictException);
  });

  it('returns an idempotent result when destination is already current', async () => {
    const database = tx();
    database.bookings.findUnique.mockResolvedValue({ ...booking, slot_id: 'destination' });
    const result = await service.rescheduleConfirmedBooking(database, 'booking', 'destination');
    expect(result.idempotent).toBe(true);
    expect(database.bookings.updateMany).not.toHaveBeenCalled();
  });
});
