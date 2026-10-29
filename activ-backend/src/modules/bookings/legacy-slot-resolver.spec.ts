import { LegacySlotResolutionError, LegacySlotResolver } from './legacy-slot-resolver';

describe('LegacySlotResolver', () => {
  const dto: any = { venueId: 'venue', serviceId: 'service', bookingDate: '2030-01-01', startTime: '10:00', endTime: '11:00' };
  const slot = (id: string, start: string, end: string, status = 'AVAILABLE') => ({ id, facility_id: 'facility', starts_at: new Date(start), ends_at: new Date(end), status });
  const resolver = (rows: any[], service: any = {}) => new LegacySlotResolver({
    partner_venue_services: { findFirst: jest.fn().mockResolvedValue({ id: 'service', venue_id: 'venue', facility_id: 'facility', venues: { id: 'venue', booking_accept: true }, ...service }) },
    slots: { findMany: jest.fn().mockResolvedValue(rows) },
  } as any);

  it('resolves one exact localized slot', async () => {
    const result = await resolver([slot('slot', '2030-01-01T04:30:00Z', '2030-01-01T05:30:00Z')]).resolve(dto, 'Asia/Kolkata');
    expect(result.slotId).toBe('slot');
  });
  it('rejects missing and ambiguous matches', async () => {
    await expect(resolver([]).resolve(dto, 'Asia/Kolkata')).rejects.toMatchObject({ code: 'NO_MATCH' });
    await expect(resolver([slot('a', '2030-01-01T04:30:00Z', '2030-01-01T05:30:00Z'), slot('b', '2030-01-01T04:30:00Z', '2030-01-01T05:30:00Z')]).resolve(dto, 'Asia/Kolkata')).rejects.toMatchObject({ code: 'AMBIGUOUS' });
  });
  it('rejects blocked, missing-facility and invalid-duration requests', async () => {
    await expect(resolver([slot('slot', '2030-01-01T04:30:00Z', '2030-01-01T05:30:00Z', 'BLOCKED')]).resolve(dto, 'Asia/Kolkata')).rejects.toMatchObject({ code: 'BLOCKED' });
    await expect(resolver([], { facility_id: null }).resolve(dto, 'Asia/Kolkata')).rejects.toMatchObject({ code: 'MISSING_FACILITY' });
    await expect(resolver([]).resolve({ ...dto, startTime: '11:00', endTime: '10:00' }, 'Asia/Kolkata')).rejects.toMatchObject({ code: 'INVALID_DURATION' });
  });
  it('matches an overnight slot against the next local date', async () => {
    const result = await resolver([slot('slot', '2029-12-31T18:30:00Z', '2029-12-31T19:30:00Z')]).resolve({ ...dto, startTime: '00:00', endTime: '01:00' }, 'Asia/Kolkata');
    expect(result.slotId).toBe('slot');
  });
});
