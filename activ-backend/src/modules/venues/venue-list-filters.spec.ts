import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { VenueStatus } from '../../common/enums/venue-status.enum';
import { AdminVenuesQueryDto } from './dto/admin-venues-query.dto';
import { VenuesService } from './venues.service';

describe('admin venue ordering and filters', () => {
  let venues: any;
  let service: VenuesService;
  const pagination = Object.assign(new PaginationDto(), { page: 2, limit: 15 });

  beforeEach(() => {
    venues = { findMany: jest.fn().mockResolvedValue([]), count: jest.fn().mockResolvedValue(42) };
    service = Object.assign(Object.create(VenuesService.prototype), { prisma: { venues } });
  });

  it('defaults to newest records first before pagination, with a stable tie breaker', async () => {
    expect(await service.findAll(pagination)).toEqual([[], 42]);
    expect(venues.findMany).toHaveBeenCalledWith(expect.objectContaining({
      skip: 15, take: 15,
      orderBy: [{ partner_venue_profiles: { created_at: 'desc' } }, { id: 'desc' }],
    }));
  });

  it('applies combined filters to both rows and total count', async () => {
    await service.findAll(Object.assign(new PaginationDto(), { search: 'Arena' }),
      VenueStatus.APPROVED, 'category-1', 'partner-1', { city: ' Indore ', state: ' Madhya Pradesh ', sort: 'oldest' });
    const query = venues.findMany.mock.calls[0][0];
    expect(query.where).toMatchObject({
      status: 'PUBLISHED', partner_id: 'partner-1',
      OR: expect.any(Array),
      partner_venue_services: { some: { service_category_id: 'category-1', status: { not: 'ARCHIVED' } } },
      AND: [
        { OR: [
          { city_code: { contains: 'Indore', mode: 'insensitive' } },
          { partner_venue_profiles: { city: { contains: 'Indore', mode: 'insensitive' } } },
        ] },
        { partner_venue_profiles: { state: { contains: 'Madhya Pradesh', mode: 'insensitive' } } },
      ],
    });
    expect(query.orderBy).toEqual([{ partner_venue_profiles: { created_at: 'asc' } }, { id: 'asc' }]);
    expect(venues.count).toHaveBeenCalledWith({ where: query.where });
  });

  it('supports recently updated sorting', async () => {
    await service.findAll(pagination, undefined, undefined, undefined, { sort: 'updated' });
    expect(venues.findMany.mock.calls[0][0].orderBy)
      .toEqual([{ partner_venue_profiles: { updated_at: 'desc' } }, { id: 'desc' }]);
  });

  it('distinguishes suspended venues from rejected venues', async () => {
    await service.findAll(pagination, VenueStatus.SUSPENDED);
    expect(venues.findMany.mock.calls[0][0].where).toMatchObject({ status: 'ARCHIVED', review_status: 'suspended' });
    await service.findAll(pagination, VenueStatus.REJECTED);
    expect(venues.findMany.mock.calls[1][0].where.AND).toContainEqual({
      OR: [{ review_status: null }, { review_status: { not: VenueStatus.SUSPENDED } }],
    });
  });

  it('validates supported sort values at the API boundary', async () => {
    expect(await validate(plainToInstance(AdminVenuesQueryDto, { sort: 'newest', city: 'Indore', state: 'Madhya Pradesh' }))).toHaveLength(0);
    expect((await validate(plainToInstance(AdminVenuesQueryDto, { sort: 'unknown' }))).some((error) => error.property === 'sort')).toBe(true);
  });
});
