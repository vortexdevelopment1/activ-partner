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

export function availabilityRows(venueId: string, categoryId: string, days: Record<string, any[]>) {
  const names = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  if (!days || typeof days !== 'object' || Array.isArray(days)) throw new BadRequestException('Invalid day schedule');
  return Object.entries(days).flatMap(([day, slots]) => {
    if (!names.includes(day.toLowerCase()) || !Array.isArray(slots)) throw new BadRequestException('Invalid day schedule');
    return slots.filter((slot) => slot.open !== '-' && slot.close !== '-').map((slot, index) => {
      if (typeof slot.open !== 'string' || typeof slot.close !== 'string' || !slot.open.trim() || !slot.close.trim()) {
        throw new BadRequestException('Opening and closing times are required');
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
