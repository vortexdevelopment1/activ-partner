import { createHash } from 'crypto';
import { ConflictException } from '@nestjs/common';
import { CreateBookingDto } from './dto/create-booking.dto';

export type LegacyIdempotencyContext = { key?: string; guaranteed: boolean; fingerprint: string };

/** Optional compatibility header; absence preserves legacy behavior explicitly. */
export function extractLegacyIdempotencyKey(headers: Record<string, unknown> | undefined): string | undefined {
  const value = headers?.['idempotency-key'] ?? headers?.['Idempotency-Key'];
  if (Array.isArray(value)) return value.length === 1 ? normalize(value[0]) : undefined;
  return normalize(value);
}

export function buildLegacyIdempotencyContext(dto: CreateBookingDto, userId: string, slotId: string, headers?: Record<string, unknown>): LegacyIdempotencyContext {
  const key = extractLegacyIdempotencyKey(headers);
  const fingerprint = createHash('sha256').update(JSON.stringify({
    userId, slotId, venueId: dto.venueId, serviceId: dto.serviceId, categoryId: dto.categoryId ?? null,
    bookingDate: dto.bookingDate, startTime: dto.startTime, endTime: dto.endTime, notes: dto.notes ?? null,
  })).digest('hex');
  return { key, guaranteed: Boolean(key), fingerprint };
}

export function assertIdempotencyFingerprint(existing: string | undefined, current: string): void {
  if (existing && existing !== current) throw new ConflictException('Idempotency key was already used for a different booking request');
}

function normalize(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > 255) return undefined;
  return trimmed;
}
