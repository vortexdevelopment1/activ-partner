import { BadRequestException } from '@nestjs/common';

export const INDIA_TIME_ZONE = 'Asia/Kolkata';
export const INDIA_OFFSET_MS = 330 * 60_000;

export function indiaDateBounds(date: string): { start: Date; end: Date } {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
  if (!match) throw new BadRequestException('Date must use YYYY-MM-DD format');
  const [, year, month, day] = match.map(Number);
  const wallMidnight = Date.UTC(year, month - 1, day);
  const check = new Date(wallMidnight);
  if (check.getUTCFullYear() !== year || check.getUTCMonth() !== month - 1 || check.getUTCDate() !== day) {
    throw new BadRequestException('Select a valid date');
  }
  const start = new Date(wallMidnight - INDIA_OFFSET_MS);
  return { start, end: new Date(start.getTime() + 86_400_000) };
}

export function weekdayForIndiaDate(date: string): string {
  const { start } = indiaDateBounds(date);
  return new Intl.DateTimeFormat('en-US', {
    weekday: 'long',
    timeZone: INDIA_TIME_ZONE,
  }).format(start).toLowerCase();
}

export function formatIndiaDate(value: Date): string {
  return new Intl.DateTimeFormat('en-IN', {
    day: '2-digit', month: 'long', year: 'numeric', timeZone: INDIA_TIME_ZONE,
  }).format(value);
}
