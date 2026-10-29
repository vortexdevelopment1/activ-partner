import type { ConfigService } from '@nestjs/config';

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
