import { VenuesService } from './venues.service';
import { CreateVenueDto } from './dto/create-venue.dto';

describe('venue creation retries', () => {
  const input = { name: 'abc', address: 'mahalaxmi nagar', city: 'Indore',
    latitude: 22.7, longitude: 75.8, categoryIds: ['basketball'] } as CreateVenueDto;
  let service: VenuesService;
  let tx: any;
  let prisma: any;
  let records: any[];

  beforeEach(() => {
    records = [];
    let queue = Promise.resolve();
    prisma = {
      partners: { findUnique: jest.fn().mockResolvedValue({ id: 'partner-1' }) },
      partner_service_categories: { findMany: jest.fn().mockResolvedValue([{ id: 'basketball', name: 'Basketball', slug: 'basketball' }]) },
      activities: { findMany: jest.fn().mockResolvedValue([]) },
      venues: { update: jest.fn().mockResolvedValue({}) },
      partner_venue_services: { updateMany: jest.fn().mockResolvedValue({}) },
      $transaction: jest.fn(async (callback) => {
        if (Array.isArray(callback)) return Promise.all(callback);
        let release: () => void;
        const previous = queue;
        queue = new Promise<void>((resolve) => { release = resolve; });
        const transaction = { ...tx, $queryRaw: jest.fn(async () => { await previous; return [{ id: 'partner-1' }]; }) };
        try { return await callback(transaction); } finally { release!(); }
      }),
    };
    tx = {
      venues: {
        findMany: jest.fn(async () => [...records]),
        create: jest.fn(async ({ data }) => { records.push({ id: data.id, status: data.status }); return data; }),
      },
      partner_venue_profiles: { create: jest.fn().mockResolvedValue({}) },
      partner_venue_services: { create: jest.fn().mockResolvedValue({}) },
    };
    service = Object.assign(Object.create(VenuesService.prototype), {
      prisma, commissionService: { getCommissionByCity: jest.fn().mockResolvedValue({ commissionPercentage: 5 }) },
      update: jest.fn(async (id) => ({ id })),
      findOne: jest.fn(async (id) => ({ id, status: 'approved' })),
    });
  });

  it('concurrent creation requests return the same venue ID', async () => {
    const [first, second] = await Promise.all([service.create(input, 'partner-1'), service.create(input, 'partner-1')]);
    expect(first.id).toBe(second.id);
    expect(tx.venues.create).toHaveBeenCalledTimes(1);
    expect(service.update).toHaveBeenCalledTimes(1);
  });

  it('reuses a published venue before an old matching draft', async () => {
    records.push({ id: 'old-draft', status: 'DRAFT' }, { id: 'approved-venue', status: 'PUBLISHED' });
    expect((await service.create(input, 'partner-1')).id).toBe('approved-venue');
    expect(tx.venues.create).not.toHaveBeenCalled();
    expect(service.update).not.toHaveBeenCalled();
  });

  it('reuses a rejected venue and resets it for resubmission', async () => {
    records.push({ id: 'rejected-venue', status: 'ARCHIVED' });
    expect((await service.create(input, 'partner-1')).id).toBe('rejected-venue');
    expect(tx.venues.create).not.toHaveBeenCalled();
    expect(prisma.venues.update).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: 'rejected-venue' }, data: expect.objectContaining({ status: 'DRAFT' }),
    }));
  });

  it('matches the same partner and location rather than venue name alone', async () => {
    await service.create(input, 'partner-1');
    expect(tx.venues.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ partner_id: 'partner-1',
        city_code: { equals: 'Indore', mode: 'insensitive' },
        partner_venue_profiles: { address_line_1: 'mahalaxmi nagar' },
      }),
    }));
  });
});
