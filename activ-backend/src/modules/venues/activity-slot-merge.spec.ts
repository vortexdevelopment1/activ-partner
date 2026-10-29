import { VenuesService } from './venues.service';

describe('merged facility slot availability', () => {
  function setup() {
    const prisma: any = {
      partner_venue_services: { findFirst: jest.fn().mockResolvedValue({
        id: 'activity', facility_id: 'facility', status: 'APPROVED',
        service_category_id: 'category', min_duration_minutes: 60,
        venues: { partner_id: 'partner', booking_accept: true },
      }) },
      partner_venue_availability: { findMany: jest.fn().mockResolvedValue([
        { open_time: '06:00', close_time: '07:00' },
      ]) },
      slots: { findMany: jest.fn().mockResolvedValue([{
        starts_at: new Date('2030-01-01T00:30:00Z'),
        ends_at: new Date('2030-01-01T01:30:00Z'),
        status: 'AVAILABLE', capacity: 1, booked_quantity: 0,
      }]) },
      bookings: { findMany: jest.fn().mockResolvedValue([]) },
      partner_walk_in_reservations: { findMany: jest.fn().mockResolvedValue([]) },
    };
    const service = Object.assign(Object.create(VenuesService.prototype), { prisma }) as VenuesService;
    const load = () => service.getActivitySlots('venue', 'activity', 'partner', '2030-01-01', 'Court 01');
    return { prisma, load };
  }

  it('queries an IST calendar day and displays generated UTC slots in IST', async () => {
    const { prisma, load } = setup();
    expect((await load()).slots).toEqual([{ startTime: '06:00', endTime: '07:00', status: 'available' }]);
    expect(prisma.slots.findMany.mock.calls[0][0].where.starts_at).toEqual({
      gte: new Date('2029-12-31T18:30:00Z'), lt: new Date('2030-01-01T18:30:00Z'),
    });
  });

  it('keeps walk-in reservations unavailable when facility slots exist', async () => {
    const { prisma, load } = setup();
    // Walk-in records store India wall-clock time as the corresponding UTC instant.
    prisma.partner_walk_in_reservations.findMany.mockResolvedValue([{
      id: 'reservation', starts_at: new Date('2030-01-01T00:30:00Z'),
      ends_at: new Date('2030-01-01T01:30:00Z'),
    }]);
    expect((await load()).slots[0]).toMatchObject({ status: 'walk_in_reserved', reservationId: 'reservation' });
  });

  it.each([true, false])('detects ACTIV bookings with generated slots = %s', async (generated) => {
    const { prisma, load } = setup();
    if (!generated) prisma.slots.findMany.mockResolvedValue([]);
    prisma.bookings.findMany.mockResolvedValue([{
      slots: { starts_at: new Date('2030-01-01T00:30:00Z'), ends_at: new Date('2030-01-01T01:30:00Z') },
    }]);
    expect((await load()).slots[0]).toMatchObject({ startTime: '06:00', status: 'activ_booking' });
  });
});
