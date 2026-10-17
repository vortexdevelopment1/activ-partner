import { BadRequestException } from '@nestjs/common';
import { randomUUID } from 'crypto';

export function mapVenueAvailability(rows: Array<{ service_category_id: string; day: string;
  open_time: string; close_time: string; capacity: number; price_paise: bigint;
  discounted_price_paise: bigint }>) {
  const result: Record<string, Array<{ day: string; slots: Array<{ openTime: string;
    closeTime: string; capacity: number; price: number; discountedPrice: number }> }>> = {};
  for (const row of rows) {
    const days = result[row.service_category_id] ??= [];
    let day = days.find((entry) => entry.day === row.day);
    if (!day) { day = { day: row.day, slots: [] }; days.push(day); }
    day.slots.push({ openTime: row.open_time, closeTime: row.close_time,
      capacity: row.capacity, price: Number(row.price_paise) / 100,
      discountedPrice: Number(row.discounted_price_paise) / 100 });
  }
  return result;
}

function timeMinutes(value: string): number {
  const match = value.trim().match(/^(\d{1,2}):(\d{2})\s*(AM|PM)?$/i);
  if (!match) throw new BadRequestException('Invalid schedule time');
  let hour = Number(match[1]);
  const minute = Number(match[2]);
  if (minute > 59 || (match[3] ? hour < 1 || hour > 12 : hour > 23)) {
    throw new BadRequestException('Invalid schedule time');
  }
  if (match[3]) hour = hour % 12 + (match[3].toUpperCase() === 'PM' ? 12 : 0);
  return hour * 60 + minute;
}

export function availabilityRows(venueId: string, categoryId: string, days: Record<string, any[]>) {
  const names = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  if (!days || typeof days !== 'object' || Array.isArray(days)) throw new BadRequestException('Invalid day schedule');
  const rangesByDay = new Map<string, Array<[number, number]>>();
  return Object.entries(days).flatMap(([day, slots]) => {
    if (!names.includes(day.toLowerCase()) || !Array.isArray(slots)) throw new BadRequestException('Invalid day schedule');
    return slots.filter((slot) => slot.open !== '-' && slot.close !== '-').map((slot, index) => {
      if (typeof slot.open !== 'string' || typeof slot.close !== 'string' || !slot.open.trim() || !slot.close.trim()) {
        throw new BadRequestException('Opening and closing times are required');
      }
      const open = timeMinutes(slot.open), close = timeMinutes(slot.close);
      if (open >= close) throw new BadRequestException('Opening time must be earlier than closing time');
      const ranges = rangesByDay.get(day.toLowerCase()) ?? [];
      if (ranges.some(([start, end]) => open < end && close > start)) {
        throw new BadRequestException(`Time ranges for ${day} must not overlap or repeat`);
      }
      ranges.push([open, close]);
      rangesByDay.set(day.toLowerCase(), ranges);
      if (slot.slotDurationMinutes !== undefined) {
        const duration = Number(slot.slotDurationMinutes);
        if (![30, 60, 90, 120].includes(duration) || close - open < duration) {
          throw new BadRequestException('Invalid slot size or time range shorter than slot size');
        }
      }
      const numbers = [slot.capacity ?? 0, slot.price ?? 0, slot.discountedPrice ?? 0].map(Number);
      if (numbers.some((value) => !Number.isFinite(value) || value < 0) || !Number.isInteger(numbers[0])) {
        throw new BadRequestException('Invalid capacity or price');
      }
      return { id: randomUUID(), venue_id: venueId, service_category_id: categoryId,
        day: day.toLowerCase(), sort_order: index, open_time: slot.open, close_time: slot.close,
        capacity: numbers[0], price_paise: BigInt(Math.round(numbers[1] * 100)),
        discounted_price_paise: BigInt(Math.round(numbers[2] * 100)) };
    });
  });
}
