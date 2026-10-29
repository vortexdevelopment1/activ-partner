import { ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateBookingDto } from './dto/create-booking.dto';

export type ResolvedLegacySlot = { slotId: string; venueId: string; serviceId: string; facilityId: string; startsAt: Date; endsAt: Date };

export class LegacySlotResolutionError extends Error {
  constructor(public readonly code: 'NO_MATCH' | 'AMBIGUOUS' | 'MISSING_FACILITY' | 'INVALID_DURATION' | 'BLOCKED' | 'OWNERSHIP') { super(code); }
}

/** Read-only resolver. It does not reserve capacity or create a booking. */
export class LegacySlotResolver {
  constructor(private readonly prisma: PrismaService) {}

  async resolve(dto: CreateBookingDto, timezone: string): Promise<ResolvedLegacySlot> {
    if (!timezone) throw new ConflictException('Venue timezone policy is required for slot resolution');
    const start = parseMinutes(dto.startTime);
    const end = parseMinutes(dto.endTime);
    if (end <= start) throw new LegacySlotResolutionError('INVALID_DURATION');

    const service = await this.prisma.partner_venue_services.findFirst({
      where: { id: dto.serviceId, venue_id: dto.venueId, is_active: true },
      select: { id: true, venue_id: true, facility_id: true, venues: { select: { id: true, booking_accept: true } } },
    });
    if (!service || service.venue_id !== dto.venueId) throw new LegacySlotResolutionError('OWNERSHIP');
    if (!service.venues.booking_accept) throw new ForbiddenException('Bookings are currently paused for this venue');
    if (!service.facility_id) throw new LegacySlotResolutionError('MISSING_FACILITY');

    const slots = await this.prisma.slots.findMany({
      where: { facility_id: service.facility_id },
      select: { id: true, facility_id: true, starts_at: true, ends_at: true, status: true },
    });
    const matches = slots.filter(slot => sameLocalSlot(slot.starts_at, slot.ends_at, dto.bookingDate, dto.startTime, dto.endTime, timezone));
    if (matches.length === 0) throw new LegacySlotResolutionError('NO_MATCH');
    if (matches.length > 1) throw new LegacySlotResolutionError('AMBIGUOUS');
    const match = matches[0];
    if (match.status !== 'AVAILABLE') throw new LegacySlotResolutionError('BLOCKED');
    return { slotId: match.id, venueId: dto.venueId, serviceId: service.id, facilityId: match.facility_id, startsAt: match.starts_at, endsAt: match.ends_at };
  }
}

function parseMinutes(value: string): number {
  const match = /^(\d{2}):(\d{2})$/.exec(value);
  if (!match) throw new LegacySlotResolutionError('INVALID_DURATION');
  return Number(match[1]) * 60 + Number(match[2]);
}

function sameLocalSlot(start: Date, end: Date, date: string, startTime: string, endTime: string, timezone: string): boolean {
  const startParts = localParts(start, timezone);
  const endParts = localParts(end, timezone);
  const startDate = date;
  const endDate = parseMinutes(endTime) <= parseMinutes(startTime) ? nextDate(date) : date;
  return `${startParts.date}T${startParts.time}` === `${startDate}T${startTime}` && `${endParts.date}T${endParts.time}` === `${endDate}T${endTime}`;
}

function localParts(value: Date, timezone: string): { date: string; time: string } {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).formatToParts(value);
  const get = (type: string) => parts.find(part => part.type === type)?.value ?? '';
  return { date: `${get('year')}-${get('month')}-${get('day')}`, time: `${get('hour')}:${get('minute')}` };
}

function nextDate(date: string): string {
  const value = new Date(`${date}T00:00:00Z`);
  value.setUTCDate(value.getUTCDate() + 1);
  return value.toISOString().slice(0, 10);
}
