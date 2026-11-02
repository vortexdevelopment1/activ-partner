import { ConfigService } from '@nestjs/config';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';
import { PaymentsService } from '../payments/payments.service';

const bookingDto = {
  venueId: 'venue',
  serviceId: 'service',
  categoryId: 'category',
  bookingDate: '2030-01-01',
  startTime: '10:00',
  endTime: '11:00',
} as any;

describe('booking/payment write rollout safety', () => {
  it('blocks POST /bookings before invoking a writer when booking writes are disabled', async () => {
    const createNormalizedFromLegacy = jest.fn();
    const controller = new BookingsController(
      { createNormalizedFromLegacy } as any,
      new ConfigService({ NORMALIZED_BOOKING_ROUTES_ENABLED: 'false' }),
    );

    await expect(controller.create(bookingDto, { id: 'user' } as any, 'request-key'))
      .rejects.toThrow('Normalized booking writes are disabled');
    expect(createNormalizedFromLegacy).not.toHaveBeenCalled();
  });

  it('passes the caller idempotency key only through the enabled booking path', async () => {
    const createNormalizedFromLegacy = jest.fn().mockResolvedValue({ id: 'booking' });
    const controller = new BookingsController(
      { createNormalizedFromLegacy } as any,
      new ConfigService({ NORMALIZED_BOOKING_ROUTES_ENABLED: 'true' }),
    );

    await controller.create(bookingDto, { id: 'user' } as any, ' request-key ');
    expect(createNormalizedFromLegacy).toHaveBeenCalledWith(bookingDto, 'user', ' request-key ');
  });

  it('rejects malformed booking idempotency keys before resolving a slot', async () => {
    const prisma = { partner_venue_services: { findFirst: jest.fn() } } as any;
    const service = new BookingsService(
      prisma,
      new ConfigService({ NORMALIZED_BOOKING_ROUTES_ENABLED: 'true' }),
    );

    await expect(service.createNormalizedFromLegacy(bookingDto, 'user', ' '.repeat(1)))
      .rejects.toThrow('valid Idempotency-Key');
    expect(prisma.partner_venue_services.findFirst).not.toHaveBeenCalled();
  });

  it('blocks both payment write endpoints when payment writes are disabled', async () => {
    const prisma = {
      bookings: { findUnique: jest.fn() },
      payments: { findFirst: jest.fn() },
    } as any;
    const service = new PaymentsService(
      new ConfigService({ NORMALIZED_BOOKING_ROUTES_ENABLED: 'false', PRISMA_LEGACY_PAYMENT_WRITES_ENABLED: 'false' }),
      prisma,
    );

    await expect(service.createOrder({ bookingId: 'booking' } as any, 'user'))
      .rejects.toThrow('NORMALIZED_BOOKING_ROUTES_ENABLED=true');
    await expect(service.verifyPayment({ bookingId: 'booking' } as any, 'user'))
      .rejects.toThrow('NORMALIZED_BOOKING_ROUTES_ENABLED=true');
    expect(prisma.bookings.findUnique).not.toHaveBeenCalled();
    expect(prisma.payments.findFirst).not.toHaveBeenCalled();
  });

  it('requires both explicit flags before payment writes can be reached', async () => {
    const service = new PaymentsService(
      new ConfigService({ NORMALIZED_BOOKING_ROUTES_ENABLED: 'true', PRISMA_LEGACY_PAYMENT_WRITES_ENABLED: 'false' }),
      { bookings: { findUnique: jest.fn() } } as any,
    );

    await expect(service.createOrder({ bookingId: 'booking' } as any, 'user'))
      .rejects.toThrow('PRISMA_LEGACY_PAYMENT_WRITES_ENABLED=true');
  });
});
