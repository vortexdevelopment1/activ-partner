import { BadRequestException } from '@nestjs/common';
import { VenueServiceStatus } from '../../common/enums/venue-service-status.enum';
import { availabilityRows, mapVenueAvailability } from './venue-table-data';
import { VenuesService } from './venues.service';

describe('relational venue data', () => {
  it('creates venue, activity, amenity and image records without writing JSON content', async () => {
    const tx = { venues: { create: jest.fn() }, partner_venue_profiles: { create: jest.fn() },
      partner_venue_amenities: { createMany: jest.fn() }, partner_venue_services: { create: jest.fn() } };
    const prisma = { partners: { findUnique: jest.fn(async () => ({ id: 'partner' })) },
      partner_service_categories: { findMany: jest.fn(async () => [{ id: 'category', name: 'Badminton', slug: 'badminton' }]) },
      activities: { findMany: jest.fn(async () => []) }, $transaction: jest.fn(async (callback) => callback(tx)) };
    const service = Object.assign(Object.create(VenuesService.prototype), { prisma });
    await service.create({ name: 'Arena', latitude: 22, longitude: 75, categoryIds: ['category'],
      amenities: ['Parking', 'Parking'], openingTime: '09:00', rules: 'No food',
      services: [{ name: 'Court A', pricePerHour: 123.45, capacity: 4, imageUrl: '/court.jpg' }] }, 'partner');
    expect(tx.venues.create.mock.calls[0][0].data).not.toHaveProperty('metadata');
    expect(tx.partner_venue_profiles.create.mock.calls[0][0].data).toMatchObject({ opening_time: '09:00', rules: 'No food' });
    expect(tx.partner_venue_amenities.createMany.mock.calls[0][0].data).toHaveLength(1);
    const activity = tx.partner_venue_services.create.mock.calls[0][0].data;
    expect(activity).toMatchObject({ title: 'Court A', price_per_hour_paise: 12345n, capacity: 4 });
    expect(activity).not.toHaveProperty('onboarding_data');
    expect(activity.partner_venue_images.create).toMatchObject({ url: '/court.jpg', is_cover: true });
  });

  it('approves activities in the current table without overriding a paused venue', async () => {
    const prisma = { partner_venue_services: {
      findUnique: jest.fn(async () => ({ id: 'activity', status: 'PENDING', venues: { partner_id: 'partner' } })),
      update: jest.fn(),
    }, venues: { update: jest.fn() } };
    const service = Object.assign(Object.create(VenuesService.prototype), { prisma,
      findOwnedActivity: jest.fn(async () => ({ id: 'activity', name: 'Court A' })),
      notificationsService: { notify: jest.fn() } });
    await service.processActivityApproval('activity', { status: VenueServiceStatus.APPROVED }, 'admin');
    expect(prisma.partner_venue_services.update).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ status: 'APPROVED', is_active: true, approved_by: 'admin' }),
    }));
    expect(prisma.venues.update).not.toHaveBeenCalled();
  });

  it('round-trips schedule prices as integer paise and keeps categories separate', () => {
    const rows = [
      ...availabilityRows('venue', 'badminton', { Monday: [{ open: '09:00 AM', close: '10:00 AM', capacity: 4, price: 123.45, discountedPrice: 100 }] }),
      ...availabilityRows('venue', 'football', { Tuesday: [{ open: '15:00', close: '16:00', capacity: 10, price: 500 }] }),
    ];
    expect(rows[0].price_paise).toBe(12345n);
    const result = mapVenueAvailability(rows);
    expect(result.badminton[0].slots[0]).toMatchObject({ price: 123.45, capacity: 4 });
    expect(result.football[0].day).toBe('tuesday');
    expect(() => JSON.stringify(result)).not.toThrow();
  });

  it('removes closed days and rejects invalid prices and capacity', () => {
    expect(availabilityRows('venue', 'category', { Monday: [{ open: '-', close: '-' }] })).toEqual([]);
    for (const values of [{ price: -1 }, { capacity: 1.5 }, { price: 'not-a-number' }]) {
      expect(() => availabilityRows('venue', 'category', { Monday: [{ open: '09:00', close: '10:00', ...values }] }))
        .toThrow(BadRequestException);
    }
    expect(() => availabilityRows('venue', 'category', { Someday: [] })).toThrow(BadRequestException);
  });

  it('updates only requested categories, including clearing a closed schedule', async () => {
    const tx = { partner_venue_availability: { deleteMany: jest.fn(), createMany: jest.fn() } };
    const prisma = { venues: { findUnique: jest.fn(async () => ({ id: 'venue', partner_id: 'partner', status: 'PUBLISHED', metadata: { availability: 'stale' } })) },
      partner_venue_services: { findMany: jest.fn(async () => [{ service_category_id: 'badminton' }]) },
      partner_venue_availability: { findMany: jest.fn(async () => []) },
      $transaction: jest.fn(async (callback) => callback(tx)) };
    const service = Object.assign(Object.create(VenuesService.prototype), { prisma });
    await service.setAvailability('venue', { badminton: { Monday: [{ open: '-', close: '-' }] } }, 'partner');
    expect(tx.partner_venue_availability.deleteMany).toHaveBeenCalledWith({ where: {
      venue_id: 'venue', service_category_id: { in: ['badminton'] },
    } });
    expect(tx.partner_venue_availability.createMany).not.toHaveBeenCalled();
    await expect(service.setAvailability('venue', { foreign: {} }, 'partner')).rejects.toThrow(BadRequestException);
  });

  it('keeps private details and inactive activities out of the user app payload', async () => {
    const service = Object.assign(Object.create(VenuesService.prototype), { findOne: jest.fn(async () => ({
      id: 'venue', name: 'Arena', status: 'approved', bookingAccept: true, partner: { email: 'private@example.com' },
      electronicSignature: 'private', amenities: ['Parking'],
      categories: [{ id: 'category' }, { id: 'draft-category' }],
      services: [{ id: 'active', categoryId: 'category', status: 'approved', isActive: true },
        { id: 'paused', categoryId: 'draft-category', status: 'approved', isActive: false }],
      images: [{ venueServiceId: 'active' }, { venueServiceId: 'paused' }],
      availability: { category: [], 'draft-category': [] },
    })) });
    const payload = await service.findPublicVenue('venue');
    expect(payload.services.map((activity) => activity.id)).toEqual(['active']);
    expect(payload.images).toHaveLength(1);
    expect(Object.keys(payload.availability)).toEqual(['category']);
    expect(payload).not.toHaveProperty('partner');
    expect(payload).not.toHaveProperty('electronicSignature');
  });
});
