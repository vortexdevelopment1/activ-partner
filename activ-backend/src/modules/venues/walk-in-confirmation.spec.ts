import { VenuesService } from './venues.service';

describe('walk-in booking confirmation', () => {
  function setup(existing = false) {
    const record = {
      id: 'reservation', amount_paise: 15000n, fees_paise: 0n, tax_paise: 0n,
      starts_at: new Date('2026-10-26T09:00:00Z'), ends_at: new Date('2026-10-26T10:00:00Z'),
      status: 'RESERVED', notes: 'Court: Court 01\nIdempotency-Key: request-key', created_at: new Date(),
    };
    const prisma: any = {
      partner_venue_services: { findFirst: jest.fn().mockResolvedValue({
        status: 'APPROVED', facility_id: null, service_category_id: 'basketball',
        venues: { partner_id: 'partner', booking_accept: true },
      }) },
      $executeRaw: jest.fn(),
      partner_venue_availability: { findMany: jest.fn().mockResolvedValue([
        { open_time: '09:00 AM', close_time: '07:00 PM', price_paise: 15000n },
      ]) },
      partner_walk_in_reservations: {
        findFirst: jest.fn().mockResolvedValue(existing ? record : null),
        findMany: jest.fn().mockResolvedValue([]),
        create: jest.fn(async ({ data }) => ({ ...record, ...data })),
      },
    };
    prisma.$transaction = jest.fn(async callback => callback(prisma));
    const service = Object.assign(Object.create(VenuesService.prototype), { prisma }) as VenuesService;
    return { service, prisma };
  }

  for (const existing of [false, true]) {
    it(`${existing ? 'replayed' : 'new'} confirmation serializes amounts safely`, async () => {
      const { service, prisma } = setup(existing);
      const response = await service.createWalkIn('venue', 'activity', 'partner', {
        date: '2026-10-26', court: 'Court 01', slots: [{ startTime: '09:00', endTime: '10:00' }],
        participantName: 'Test Participant', participantPhone: '+919876543210', idempotencyKey: 'request-key',
      });
      expect(() => JSON.stringify({ message: 'Reserved', data: response })).not.toThrow();
      expect(response.reservations[0]).toMatchObject({ amountPaise: '15000', status: 'reserved', idempotencyKey: 'request-key' });
      expect(prisma.partner_walk_in_reservations.create).toHaveBeenCalledTimes(existing ? 0 : 1);
    });
  }
});
