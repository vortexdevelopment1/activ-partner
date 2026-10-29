import { ConflictException } from '@nestjs/common';

export const INDIA_BOOKING_TIMEZONE = 'Asia/Kolkata';

export function resolveBookingTimezone(country: string | null | undefined): string {
  if (country?.trim().toLowerCase() === 'india') return INDIA_BOOKING_TIMEZONE;
  throw new ConflictException('Booking timezone is unsupported for this venue');
}
