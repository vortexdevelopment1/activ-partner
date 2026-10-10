import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { VenuesService } from './venues.service';

describe('activity management on the current schema', () => {
  let service: VenuesService;
  let prisma: any;
  let record: any;

  beforeEach(() => {
    record = { id: 'activity', venue_id: 'venue', service_category_id: 'badminton',
      facility_id: 'facility', title: 'Badminton', status: 'APPROVED', description: 'Indoor',
      onboarding_data: {}, is_active: true, partner_venue_images: [], partner_service_amenities: [],
      venues: { partner_id: 'partner' } };
    prisma = {
      partner_venue_services: { findUnique: jest.fn(async () => record),
        findUniqueOrThrow: jest.fn(async () => record), update: jest.fn(async (args) => args.data) },
      slots: { findMany: jest.fn(async () => [{ id: 'slot' }]), updateMany: jest.fn(),
        aggregate: jest.fn(async () => ({ _sum: { capacity: 10, booked_quantity: 4 } })) },
      bookings: { count: jest.fn(async () => 2),
        aggregate: jest.fn(async () => ({ _sum: { total_paise: 125000n } })),
        findMany: jest.fn(async () => [{ id: 'booking', starts_at: new Date('2030-01-01'),
          total_paise: 125000n, status: 'CONFIRMED', users: { name: 'Customer' },
          slots: { ends_at: new Date('2030-01-02') } }]) },
      reviews: { findMany: jest.fn(async () => []) },
      partner_service_paused_slots: { createMany: jest.fn(), findMany: jest.fn(async () => [{ slot_id: 'owned-slot' }]), deleteMany: jest.fn() },
    };
    prisma.$transaction = jest.fn(async (callback) => callback(prisma));
    service = Object.assign(Object.create(VenuesService.prototype), { prisma });
  });

  it('rejects another partner before accessing bookings or changing data', async () => {
    await expect(service.getActivityManagement('activity', 'other')).rejects.toBeInstanceOf(ForbiddenException);
    await expect(service.updateActivityManagement('activity', 'other', { isActive: false, reason: 'Maintenance' }))
      .rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.bookings.count).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('scopes bookings to the linked facility and serializes money without BigInt', async () => {
    const result = await service.getActivityManagement('activity', 'partner');
    expect(prisma.bookings.count).toHaveBeenCalledWith({ where: { slots: { facility_id: 'facility' } } });
    expect(result).toMatchObject({ bookingCount: 2, earnings: 1250, occupancy: 40 });
    expect(result.bookings[0]).toMatchObject({ amount: 1250, customerName: 'Customer', status: 'Upcoming' });
    expect(() => JSON.stringify(result)).not.toThrow();
  });

  it('does not load unrelated bookings for activities without a facility', async () => {
    record.facility_id = null;
    const result = await service.getActivityManagement('activity', 'partner');
    expect(result).toMatchObject({ bookingCount: null, earnings: null, occupancy: null, bookings: [] });
    expect(prisma.bookings.findMany).not.toHaveBeenCalled();
  });

  it('pauses future available slots and preserves existing bookings and metadata', async () => {
    record.onboarding_data = { imageUrls: ['photo'], amenities: ['Parking'] };
    await service.updateActivityManagement('activity', 'partner', { isActive: false, reason: 'Maintenance' });
    expect(prisma.slots.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['slot'] }, status: 'AVAILABLE' }, data: { status: 'BLOCKED' },
    });
    expect(prisma.partner_venue_services.update.mock.calls[0][0].data)
      .toMatchObject({ is_active: false, pause_reason: 'Maintenance' });
    expect(prisma.partner_venue_services.update.mock.calls[0][0].data.onboarding_data).toBeUndefined();
    expect(prisma.partner_service_paused_slots.createMany).toHaveBeenCalledWith({
      data: [{ venue_service_id: 'activity', slot_id: 'slot' }], skipDuplicates: true });
  });

  it('only resumes slots previously blocked by this activity', async () => {
    record.onboarding_data = { isActive: false, pausedSlotIds: ['owned-slot'] };
    await service.updateActivityManagement('activity', 'partner', { isActive: true });
    expect(prisma.slots.updateMany.mock.calls[0][0].where)
      .toMatchObject({ facility_id: 'facility', id: { in: ['owned-slot'] }, status: 'BLOCKED' });
  });

  it('requires a pause reason and rejects controls for draft activities', async () => {
    await expect(service.updateActivityManagement('activity', 'partner', { isActive: false }))
      .rejects.toBeInstanceOf(BadRequestException);
    record.status = 'DRAFT';
    await expect(service.updateActivityManagement('activity', 'partner', { isActive: false, reason: 'Repair' }))
      .rejects.toBeInstanceOf(BadRequestException);
  });

  it('archives the activity without deleting its records or bookings', async () => {
    await service.updateActivityManagement('activity', 'partner', {}, true);
    expect(prisma.partner_venue_services.update.mock.calls[0][0].data)
      .toMatchObject({ status: 'ARCHIVED', is_active: false });
  });
});
