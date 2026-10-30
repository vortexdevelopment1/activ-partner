import type { ConfigService } from '@nestjs/config';
import { ConflictException } from '@nestjs/common';

/**
 * Rollout guard for the normalized booking writer. It is deliberately
 * default-off; legacy booking/payment routes remain authoritative until a
 * coordinated cutover is approved.
 */
export function normalizedBookingRoutesEnabled(config: ConfigService): boolean {
  return config.get<string | boolean>('NORMALIZED_BOOKING_ROUTES_ENABLED', false) === true ||
    config.get<string>('NORMALIZED_BOOKING_ROUTES_ENABLED', 'false') === 'true';
}

export function assertNormalizedBookingRoutesEnabled(config: ConfigService): void {
  if (!normalizedBookingRoutesEnabled(config)) {
    throw new Error('Normalized booking routes are disabled');
  }
}

/**
 * Opt-in switch for the Prisma payment writer while the legacy booking
 * writer and production schema are still being coordinated. This is
 * intentionally independent from the normalized booking route switch so a
 * local payment cutover can be tested without changing booking creation.
 */
export function prismaLegacyPaymentWritesEnabled(config: ConfigService): boolean {
  return config.get<string | boolean>('PRISMA_LEGACY_PAYMENT_WRITES_ENABLED', false) === true ||
    config.get<string>('PRISMA_LEGACY_PAYMENT_WRITES_ENABLED', 'false') === 'true';
}

/** Payment writes require normalized booking holds and payment deadlines. */
export function assertPrismaPaymentWriteCompatibility(config: ConfigService): void {
  if (prismaLegacyPaymentWritesEnabled(config) && !normalizedBookingRoutesEnabled(config)) {
    throw new ConflictException(
      'Prisma payment writes require NORMALIZED_BOOKING_ROUTES_ENABLED=true',
    );
  }
}
