import type { ConfigService } from '@nestjs/config';
import { ConflictException } from '@nestjs/common';

/**
 * Rollout guard for the normalized booking writer. It is deliberately
 * default-off until a coordinated cutover is approved.
 */
export function normalizedBookingRoutesEnabled(config: ConfigService): boolean {
  return config.get<string | boolean>('NORMALIZED_BOOKING_ROUTES_ENABLED', false) === true ||
    config.get<string>('NORMALIZED_BOOKING_ROUTES_ENABLED', 'false') === 'true';
}

export function assertNormalizedBookingRoutesEnabled(config: ConfigService): void {
  if (!normalizedBookingRoutesEnabled(config)) {
    throw new ConflictException('Normalized booking writes are disabled');
  }
}

/** Every booking writer must pass the rollout guard, including direct service callers. */
export function assertNormalizedBookingWriteEnabled(config: ConfigService): void {
  assertNormalizedBookingRoutesEnabled(config);
}

/**
 * Opt-in switch for the Prisma payment writer. It remains separately
 * controlled so payment writes cannot be enabled accidentally with bookings.
 */
export function prismaLegacyPaymentWritesEnabled(config: ConfigService): boolean {
  return config.get<string | boolean>('PRISMA_LEGACY_PAYMENT_WRITES_ENABLED', false) === true ||
    config.get<string>('PRISMA_LEGACY_PAYMENT_WRITES_ENABLED', 'false') === 'true';
}

/** Payment writes require normalized booking holds and payment deadlines. */
export function assertPrismaPaymentWriteCompatibility(config: ConfigService): void {
  if (!normalizedBookingRoutesEnabled(config)) {
    throw new ConflictException(
      'Prisma payment writes require NORMALIZED_BOOKING_ROUTES_ENABLED=true',
    );
  }
  if (!prismaLegacyPaymentWritesEnabled(config)) {
    throw new ConflictException(
      'Prisma payment writes are disabled; enable PRISMA_LEGACY_PAYMENT_WRITES_ENABLED=true after approval',
    );
  }
}
