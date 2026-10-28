import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { BookingsService } from './bookings.service';

describe('current-schema booking attendance actions', () => {
  function setup(source: 'WALK_IN' | 'ACTIV', status?: string) {
    const walkIn = { id: 'booking', status: status ?? 'RESERVED', amount_paise: 50000n,
      notes: 'Court: Court 01\nIdempotency-Key: request', venues: { partner_id: 'owner' } };
    const booking = { id: 'booking', status: status ?? 'CONFIRMED', total_paise: 50000n,
      slots: { facilities: { venues: { partner_id: 'owner' } } } };
    const events: any[] = [];
    const prisma: any = {
      $executeRaw: jest.fn(),
      partner_walk_in_reservations: {
        findUnique: jest.fn(async () => source === 'WALK_IN' ? walkIn : null),
        updateMany: jest.fn(async ({ data }) => { Object.assign(walkIn, data); return { count: 1 }; }),
      },
      bookings: {
        findUnique: jest.fn(async () => source === 'ACTIV' ? booking : null),
        updateMany: jest.fn(async ({ data }) => { Object.assign(booking, data); return { count: 1 }; }),
      },
      booking_events: {
        findFirst: jest.fn(async () => events.at(-1) ?? null),
        create: jest.fn(async ({ data }) => { events.push(data); return data; }),
      },
    };
    prisma.$transaction = jest.fn(async callback => callback(prisma));
    const bookingRepository = { findOne: jest.fn(), save: jest.fn() };
    const service = Object.assign(Object.create(BookingsService.prototype), { prisma, bookingRepository }) as BookingsService;
    return { service, prisma, walkIn, booking, events, bookingRepository };
  }

  for (const source of ['WALK_IN', 'ACTIV'] as const) {
    for (const [method, expected] of [
      ['markNoShow', 'no_show'], ['checkIn', 'ongoing'], ['complete', 'completed'],
    ] as const) {
      it(`${source} ${method} uses the current schema, persists once, and returns JSON-safe data`, async () => {
        const { service, prisma, walkIn, booking, events, bookingRepository } = setup(source);
        const result = await service[method]('booking', 'owner');
        expect(result).toEqual({ id: 'booking', status: expected, source });
        expect(() => JSON.stringify(result)).not.toThrow();
        await service[method]('booking', 'owner');
        expect(bookingRepository.findOne).not.toHaveBeenCalled();
        if (source === 'WALK_IN') {
          expect(prisma.partner_walk_in_reservations.updateMany).toHaveBeenCalledTimes(1);
          if (method === 'checkIn') expect(walkIn.notes).toMatch(/^Checked-in: /m);
          else expect(walkIn.status).toBe(method === 'markNoShow' ? 'NO_SHOW' : 'COMPLETED');
          expect(walkIn.notes).toContain('Idempotency-Key: request');
        } else {
          expect(prisma.bookings.updateMany).toHaveBeenCalledTimes(1);
          expect(events).toHaveLength(1);
          expect(events[0].to_status).toBe(method === 'checkIn' ? 'CHECKED_IN' : method === 'markNoShow' ? 'NO_SHOW' : 'COMPLETED');
          expect(booking.status).toBe(method === 'complete' ? 'COMPLETED' : 'CONFIRMED');
        }
      });
      it(`${source} rejects another partner's ${method} before writing`, async () => {
        const { service, prisma } = setup(source);
        await expect(service[method]('booking', 'other')).rejects.toBeInstanceOf(ForbiddenException);
        expect(prisma.partner_walk_in_reservations.updateMany).not.toHaveBeenCalled();
        expect(prisma.bookings.updateMany).not.toHaveBeenCalled();
        expect(prisma.booking_events.create).not.toHaveBeenCalled();
      });
    }
    it(`${source} rejects attendance changes after cancellation`, async () => {
      const { service } = setup(source, 'CANCELLED');
      await expect(service.markNoShow('booking', 'owner')).rejects.toBeInstanceOf(BadRequestException);
      await expect(service.checkIn('booking', 'owner')).rejects.toBeInstanceOf(BadRequestException);
    });
    it(`${source} cannot check in a booking already marked no-show`, async () => {
      const { service } = setup(source);
      await service.markNoShow('booking', 'owner');
      await expect(service.checkIn('booking', 'owner')).rejects.toBeInstanceOf(BadRequestException);
    });
  }
  it('returns 404 for an unknown ID', async () => {
    const { service, prisma } = setup('ACTIV');
    prisma.bookings.findUnique.mockResolvedValue(null);
    await expect(service.markNoShow('missing', 'owner')).rejects.toBeInstanceOf(NotFoundException);
  });

  it.each(['WALK_IN', 'ACTIV'] as const)('%s rejects a new check-in after the slot ends', async source => {
    const { service, walkIn, booking, prisma } = setup(source);
    Object.assign(walkIn, { ends_at: new Date('2020-01-01') });
    Object.assign(booking.slots, { ends_at: new Date('2020-01-01') });
    await expect(service.checkIn('booking', 'owner')).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.booking_events.create).not.toHaveBeenCalled();
    expect(prisma.partner_walk_in_reservations.updateMany).not.toHaveBeenCalled();
  });

  it('handles a repeated no-show saved by the incoming implementation', async () => {
    const { service, prisma } = setup('ACTIV', 'NO_SHOW');
    await expect(service.markNoShow('booking', 'owner')).resolves.toMatchObject({ status: 'no_show' });
    await expect(service.checkIn('booking', 'owner')).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.bookings.updateMany).not.toHaveBeenCalled();
  });

  it('handles a repeated check-in saved by the incoming implementation', async () => {
    const { service, prisma, booking } = setup('ACTIV');
    Object.assign(booking, { checked_in_at: new Date() });
    await expect(service.checkIn('booking', 'owner')).resolves.toMatchObject({ status: 'ongoing' });
    expect(prisma.bookings.updateMany).not.toHaveBeenCalled();
    expect(prisma.booking_events.create).not.toHaveBeenCalled();
  });
});
