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
      public_reference: 'ACTV-000015',
      venues: { partner_id: 'partner', name: 'Arena', public_reference: 'VEN-000016' } };
    prisma = {
      $queryRawUnsafe: jest.fn().mockResolvedValue([]),
      venues: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      partner_venue_services: { findUnique: jest.fn(async () => record),
        findUniqueOrThrow: jest.fn(async () => record), update: jest.fn(async (args) => args.data), count: jest.fn().mockResolvedValue(0) },
      partner_venue_answers: { findMany: jest.fn(async () => []) },
      partner_walk_in_reservations: { findMany: jest.fn(async () => []) },
      partner_venue_availability: { findMany: jest.fn(async () => []) },
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
    service = Object.assign(Object.create(VenuesService.prototype), { prisma,
      adminNotificationsService: { notify: jest.fn().mockResolvedValue(undefined) } });
  });

  it('rejects another partner before accessing bookings or changing data', async () => {
    await expect(service.getActivityManagement('activity', 'other')).rejects.toBeInstanceOf(ForbiddenException);
    await expect(service.updateActivityManagement('activity', 'other', { isActive: false, reason: 'Maintenance' }))
      .rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.bookings.count).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('keeps ACTIV no-show attendance visible after refreshing management', async () => {
    prisma.bookings.findMany.mockResolvedValueOnce([{ id: 'booking', starts_at: new Date('2030-01-01'),
      total_paise: 125000n, status: 'CONFIRMED', users: { name: 'Customer' },
      slots: { ends_at: new Date('2030-01-02') }, booking_events: [{ to_status: 'NO_SHOW' }] }]);
    const result = await service.getActivityManagement('activity', 'partner');
    expect(result.bookings[0].status).toBe('No Show');
  });

  it('keeps a checked-in walk-in ongoing after refreshing management', async () => {
    prisma.partner_walk_in_reservations.findMany.mockResolvedValueOnce([{
      id: 'walk-in', participant_name: 'Customer', status: 'RESERVED', amount_paise: 50000n,
      notes: 'Checked-in: 2026-10-26T08:00:00Z',
      starts_at: new Date('2030-01-01'), ends_at: new Date('2030-01-02'),
    }]);
    const result = await service.getActivityManagement('activity', 'partner');
    expect(result.bookings.find((booking) => booking.id === 'walk-in').status).toBe('Ongoing');
  });

  it.each(['UPI', 'Cash', 'Card'])('includes %s walk-ins, their payment method, and their revenue', async method => {
    prisma.partner_walk_in_reservations.findMany.mockResolvedValueOnce([{
      id: 'walk-in', participant_name: 'Walk-in Customer', status: 'RESERVED', amount_paise: 50000n,
      notes: `Payment method: ${method}\nPayment status: PAID\nEmail: test@example.com`,
      created_at: new Date('2026-10-26T08:00:00Z'),
      starts_at: new Date('2030-01-01'), ends_at: new Date('2030-01-02'),
    }]);
    const result = await service.getActivityManagement('activity', 'partner');
    expect(result.bookings.find(booking => booking.id === 'walk-in')).toMatchObject({
      paymentMode: method.toUpperCase(), paymentStatus: 'PAID', amount: 500,
      email: 'test@example.com', bookedOn: new Date('2026-10-26T08:00:00Z'),
    });
    expect(result.bookingCount).toBe(3);
    expect(result.earnings).toBe(1750);
  });

  it.each([
    ['CONFIRMED', new Date('2026-10-26T08:00:00Z'), 'Ongoing'],
    ['NO_SHOW', null, 'No Show'],
    ['COMPLETED', new Date('2026-10-26T08:00:00Z'), 'Completed'],
  ])('preserves incoming %s attendance fields on refresh', async (status, checkedInAt, expected) => {
    prisma.bookings.findMany.mockResolvedValueOnce([{
      id: 'booking', starts_at: new Date('2030-01-01'), total_paise: 50000n,
      status, checked_in_at: checkedInAt, users: { name: 'Customer' },
      slots: { ends_at: new Date('2030-01-02') }, booking_events: [],
    }]);
    const result = await service.getActivityManagement('activity', 'partner');
    expect(result.bookings[0].status).toBe(expected);
    expect(prisma.bookings.aggregate.mock.calls[0][0].where.status.in).toContain('NO_SHOW');
  });

  it('returns stored public references without changing UUID identifiers', async () => {
    record.id = '93a30fe8-9c79-4337-ae10-6fac5a047b94';
    record.venue_id = '9618f0df-42eb-42f2-82c0-4e9a361c3086';
    const result = await service.getActivityManagement(record.id, 'partner');
    expect(result).toMatchObject({
      id: '93a30fe8-9c79-4337-ae10-6fac5a047b94',
      activityReference: 'ACTV-000015',
      venueId: '9618f0df-42eb-42f2-82c0-4e9a361c3086',
      venueReference: 'VEN-000016',
    });
  });

  it('scopes bookings to the linked facility and serializes money without BigInt', async () => {
    const result = await service.getActivityManagement('activity', 'partner');
    expect(result).toMatchObject({
      activityReference: 'ACTV-000015',
      venueReference: 'VEN-000016',
      id: 'activity',
      venueId: 'venue',
    });
    expect(prisma.bookings.count).toHaveBeenCalledWith({ where: { slots: { facility_id: 'facility' } } });
    expect(result).toMatchObject({ bookingCount: 2, earnings: 1250, occupancy: 40 });
    expect(result.bookings[0]).toMatchObject({ amount: 1250, customerName: 'Customer', status: 'Upcoming' });
    expect(() => JSON.stringify(result)).not.toThrow();
  });

  it('hydrates editable details from saved onboarding answers when activity data is empty', async () => {
    record.service_category_id = 'cricket-turf';
    record.description = 'Cricket turf bookings';
    prisma.partner_venue_answers.findMany.mockResolvedValueOnce([
      { answer: 'This is activity description', partner_service_questions: { question: 'Activity Description' } },
      { answer: '10', partner_service_questions: { question: 'Total Turfs' } },
      { answer: 'Artificial Turf', partner_service_questions: { question: 'Pitch Type' } },
      { answer: ['Indoor', 'Covered'], partner_service_questions: { question: 'Playing Environment' } },
    ]);

    const result = await service.getActivityManagement('activity', 'partner');

    expect(prisma.partner_venue_answers.findMany).toHaveBeenCalledWith({
      where: {
        venue_id: 'venue',
        OR: [
          { venue_service_id: 'activity' },
          {
            venue_service_id: null,
            partner_service_questions: { service_category_id: 'cricket-turf' },
          },
        ],
      },
      include: { partner_service_questions: true },
      orderBy: { updated_at: 'asc' },
    });
    expect(result).toMatchObject({
      description: 'This is activity description',
      numberOfCourt: '10',
      courtType: 'Artificial Turf',
      playingEnvironment: ['Indoor', 'Covered'],
    });
  });

  it('does not load unrelated bookings for activities without a facility', async () => {
    record.facility_id = null;
    const result = await service.getActivityManagement('activity', 'partner');
    expect(result).toMatchObject({ bookingCount: 0, earnings: 0, occupancy: null, bookings: [] });
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
    expect((service as any).adminNotificationsService.notify).toHaveBeenCalledWith(
      'activity_removed', expect.any(String), expect.any(String),
      { partnerId: 'partner', venueId: 'venue', serviceId: 'activity' },
    );
    expect((service as any).adminNotificationsService.notify).toHaveBeenCalledWith(
      'venue_auto_deactivated', expect.any(String), expect.any(String), { partnerId: 'partner', venueId: 'venue' },
    );
  });

  it('allows an owned draft to be removed using the activity management endpoint', async () => {
    record.status = 'DRAFT';
    await service.updateActivityManagement('activity', 'partner', {}, true);
    expect(prisma.partner_venue_services.update.mock.calls[0][0]).toMatchObject({
      where: { id: 'activity' }, data: { status: 'ARCHIVED', is_active: false },
    });
  });

  it('does not announce automatic deactivation when activities remain', async () => {
    prisma.partner_venue_services.count.mockResolvedValue(1);
    await service.removeService('activity', 'partner');
    expect(prisma.venues.updateMany).not.toHaveBeenCalled();
    expect((service as any).adminNotificationsService.notify).toHaveBeenCalledTimes(1);
  });

  it('does not announce deactivation again when bookings were already disabled', async () => {
    prisma.venues.updateMany.mockResolvedValue({ count: 0 });
    await service.updateActivityManagement('activity', 'partner', {}, true);
    expect((service as any).adminNotificationsService.notify).toHaveBeenCalledTimes(1);
  });

  it('does not send removal alerts when the archive transaction fails', async () => {
    prisma.partner_venue_services.update.mockRejectedValue(new Error('Update failed'));
    await expect(service.updateActivityManagement('activity', 'partner', {}, true)).rejects.toThrow('Update failed');
    expect((service as any).adminNotificationsService.notify).not.toHaveBeenCalled();
  });
});
