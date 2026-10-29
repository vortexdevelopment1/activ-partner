import { NormalizedBookingHoldService } from './normalized-booking-hold.service';

describe('normalized booking hold service', () => {
  const baseSlot = {
    id: 'slot', status: 'AVAILABLE', capacity: 1, price_paise: 1000n,
    starts_at: new Date('2030-01-01T10:00:00Z'), ends_at: new Date('2030-01-01T11:00:00Z'),
    facilities: { id: 'facility', venue_id: 'venue', venues: { id: 'venue', policy_version: 'v1', status: 'PUBLISHED', booking_accept: true } },
  };
  const tx = (existing: any = null) => ({
    $queryRaw: jest.fn().mockResolvedValue([]),
    slots: { findUnique: jest.fn().mockResolvedValue(baseSlot) },
    booking_attempts: {
      findUnique: jest.fn().mockResolvedValue(existing),
      findMany: jest.fn().mockResolvedValue([]),
      create: jest.fn().mockImplementation(async ({ data }: any) => ({ ...data })),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    bookings: { findMany: jest.fn().mockResolvedValue([]) },
    partner_walk_in_reservations: { findMany: jest.fn().mockResolvedValue([]) },
  });

  it('creates a server-priced ten-minute hold with policy snapshot', async () => {
    const service = new NormalizedBookingHoldService();
    const result = await service.createHold(tx() as any, 'user', 'slot', 'key', 1, 10, new Date('2030-01-01T09:00:00Z'));
    expect(result.status).toBe('HELD');
    expect(result.unitPricePaise).toBe(1000n);
    expect(result.expiresAt).toEqual(new Date('2030-01-01T09:10:00Z'));
  });

  it('reuses a compatible active idempotent hold', async () => {
    const existing = { id: 'attempt', user_id: 'user', slot_id: 'slot', quantity: 1, status: 'HELD',
      expires_at: new Date('2030-01-01T09:05:00Z'), quote_snapshot: { policyVersion: 'v1', unitPricePaise: '1000' } };
    const service = new NormalizedBookingHoldService();
    const result = await service.createHold(tx(existing) as any, 'user', 'slot', 'key', 1, 10, new Date('2030-01-01T09:00:00Z'));
    expect(result.reused).toBe(true);
  });

  it('expires only held attempts whose timestamp has passed', async () => {
    const service = new NormalizedBookingHoldService();
    const database = tx({ slot_id: 'slot' });
    await expect(service.expireHold(database as any, 'attempt', new Date('2030-01-01T10:00:00Z'))).resolves.toBe(true);
    expect(database.booking_attempts.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: 'attempt', status: 'HELD', expires_at: { lte: new Date('2030-01-01T10:00:00Z') } },
    }));
  });
});
