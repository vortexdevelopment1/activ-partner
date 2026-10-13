import { VenuesService } from './venues.service';
import { UserRole } from '../../common/enums/user-role.enum';
import { VenueStatus } from '../../common/enums/venue-status.enum';

describe('venue location rates and selected categories', () => {
  let tx: any;
  let service: VenuesService;
  let getCommissionByCity: jest.Mock;
  const venue = { id: 'venue-1', partnerId: 'partner-1', name: 'Arena',
    city: 'Mumbai', state: 'Maharashtra', status: VenueStatus.DRAFT };

  beforeEach(() => {
    tx = {
      venues: { update: jest.fn().mockResolvedValue({}) },
      partner_venue_profiles: { upsert: jest.fn().mockResolvedValue({}) },
      partner_service_categories: { findMany: jest.fn().mockResolvedValue([{ id: 'volleyball', name: 'Volleyball' }]) },
      partner_venue_services: { updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        findFirst: jest.fn().mockResolvedValue({ id: 'service-1' }) },
    };
    getCommissionByCity = jest.fn().mockResolvedValue({ commissionPercentage: 5 });
    service = Object.assign(Object.create(VenuesService.prototype), {
      prisma: { $transaction: jest.fn((callback) => callback(tx)) },
      commissionService: { getCommissionByCity },
      findOne: jest.fn().mockResolvedValue(venue),
      adminNotificationsService: { notify: jest.fn().mockResolvedValue(undefined) },
    });
  });

  it('saves the backend rate instead of a partner-supplied commission', async () => {
    await service.update(venue.id, { commission: 10, city: 'Pune' }, { id: venue.partnerId, role: UserRole.PARTNER });
    expect(getCommissionByCity).toHaveBeenCalledWith('Pune', 'Maharashtra');
    expect(tx.venues.update).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ commission_percent: 5 }),
    }));
  });

  it('archives deselected draft activities when selection is replaced', async () => {
    await service.update(venue.id, { categoryIds: ['volleyball'] }, { id: venue.partnerId, role: UserRole.PARTNER });
    expect(tx.partner_venue_services.updateMany).toHaveBeenCalledWith({
      where: { venue_id: venue.id, service_category_id: { notIn: ['volleyball'] }, status: { not: 'ARCHIVED' } },
      data: { status: 'ARCHIVED', is_active: false, updated_at: expect.any(Date) },
    });
    expect(getCommissionByCity).not.toHaveBeenCalled();
  });

  it('replaces published selections as well as draft selections', async () => {
    (service.findOne as jest.Mock).mockResolvedValue({ ...venue, status: VenueStatus.APPROVED });
    await service.update(venue.id, { categoryIds: ['volleyball'] }, { id: venue.partnerId, role: UserRole.PARTNER });
    expect(tx.partner_venue_services.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { venue_id: venue.id, service_category_id: { notIn: ['volleyball'] }, status: { not: 'ARCHIVED' } },
    }));
  });

  it('keeps selections when an unrelated venue field is updated', async () => {
    await service.update(venue.id, { name: 'Updated Arena' }, { id: venue.partnerId, role: UserRole.PARTNER });
    expect(tx.partner_venue_services.updateMany).not.toHaveBeenCalled();
  });

  it('rejects an empty selection rather than silently retaining old categories', async () => {
    await expect(service.update(venue.id, { categoryIds: [] }, { id: venue.partnerId, role: UserRole.PARTNER }))
      .rejects.toThrow('At least one categoryId is required');
    expect(tx.partner_venue_services.updateMany).not.toHaveBeenCalled();
  });

  it('omits archived categories from the venue returned to the admin', async () => {
    const activity = (id: string, status: string) => ({
      id, status, service_category_id: id, partner_service_categories: { id, name: id },
      partner_venue_images: [], partner_service_amenities: [],
    });
    const reader = Object.assign(Object.create(VenuesService.prototype), {
      prisma: { venues: { findUnique: jest.fn().mockResolvedValue({
        id: venue.id, partner_id: venue.partnerId, name: venue.name, city_code: venue.city,
        latitude: 19, longitude: 72, status: 'DRAFT',
        partners: { partner_business_profiles: null, partner_users: [] },
        partner_venue_profiles: null, partner_venue_availability: [], partner_venue_amenities: [],
        partner_venue_images: [], partner_venue_answers: [],
        partner_venue_services: [activity('volleyball', 'DRAFT'), activity('basketball', 'ARCHIVED')],
      }) } },
    });
    const result = await reader.findOne(venue.id);
    expect(result.categories.map((category) => category.id)).toEqual(['volleyball']);
    expect(result.services.map((activity) => activity.categoryId)).toEqual(['volleyball']);
  });
});
