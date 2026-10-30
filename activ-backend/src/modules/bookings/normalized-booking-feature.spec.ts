import { normalizedBookingRoutesEnabled, prismaLegacyPaymentWritesEnabled, assertPrismaPaymentWriteCompatibility } from './normalized-booking-feature';

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

describe('Prisma legacy payment writer rollout guard', () => {
  it('is disabled by default', () => {
    const config = { get: jest.fn((_key: string, fallback?: unknown) => fallback) } as any;
    expect(prismaLegacyPaymentWritesEnabled(config)).toBe(false);
  });

  it('accepts an explicit true configuration only', () => {
    const config = { get: jest.fn((key: string, fallback?: unknown) => key === 'PRISMA_LEGACY_PAYMENT_WRITES_ENABLED' ? 'true' : fallback) } as any;
    expect(prismaLegacyPaymentWritesEnabled(config)).toBe(true);
  });

  it('rejects payment writes when normalized booking routes are disabled', () => {
    const config = { get: jest.fn((key: string, fallback?: unknown) => key === 'PRISMA_LEGACY_PAYMENT_WRITES_ENABLED' ? 'true' : fallback) } as any;
    expect(() => assertPrismaPaymentWriteCompatibility(config)).toThrow(
      'require NORMALIZED_BOOKING_ROUTES_ENABLED=true',
    );
  });

  it('allows payment writes only when both flags are explicitly enabled', () => {
    const config = { get: jest.fn((key: string, fallback?: unknown) => {
      if (key === 'PRISMA_LEGACY_PAYMENT_WRITES_ENABLED') return 'true';
      if (key === 'NORMALIZED_BOOKING_ROUTES_ENABLED') return 'true';
      return fallback;
    }) } as any;
    expect(() => assertPrismaPaymentWriteCompatibility(config)).not.toThrow();
  });
});
