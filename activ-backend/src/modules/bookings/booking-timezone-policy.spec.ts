import { resolveBookingTimezone } from './booking-timezone-policy';

describe('booking timezone policy', () => {
  it('uses explicit India policy', () => expect(resolveBookingTimezone('India')).toBe('Asia/Kolkata'));
  it('rejects unknown or unsupported venue countries', () => {
    expect(() => resolveBookingTimezone(undefined)).toThrow('unsupported');
    expect(() => resolveBookingTimezone('United States')).toThrow('unsupported');
  });
});
