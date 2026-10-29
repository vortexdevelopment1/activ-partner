import { normalizedBookingRoutesEnabled } from './normalized-booking-feature';

describe('normalized booking rollout guard', () => {
  it('is disabled by default', () => {
    const config = { get: jest.fn((_key: string, fallback?: unknown) => fallback) } as any;
    expect(normalizedBookingRoutesEnabled(config)).toBe(false);
  });

  it('accepts an explicit true configuration only', () => {
    const config = { get: jest.fn((key: string, fallback?: unknown) => key === 'NORMALIZED_BOOKING_ROUTES_ENABLED' ? 'true' : fallback) } as any;
    expect(normalizedBookingRoutesEnabled(config)).toBe(true);
  });

  it('does not enable the writer for arbitrary truthy values', () => {
    const config = { get: jest.fn((key: string, fallback?: unknown) => key === 'NORMALIZED_BOOKING_ROUTES_ENABLED' ? 'yes' : fallback) } as any;
    expect(normalizedBookingRoutesEnabled(config)).toBe(false);
  });
});
