import { Injectable, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { bookingHasEnded, INDIA_OFFSET_MS } from './booking-expiry';

@Injectable()
export class BookingExpiryService implements OnModuleInit, OnModuleDestroy {
  private timer?: ReturnType<typeof setInterval>;
  private running = false;
  private readonly logger = new Logger(BookingExpiryService.name);
  constructor(private readonly prisma: PrismaService) {}

  onModuleInit() {
    this.timer = setInterval(() => void this.sweep(), 30_000);
    this.timer.unref();
    void this.sweep();
  }

  onModuleDestroy() { clearInterval(this.timer); }

  async sweep() {
    if (this.running) return;
    this.running = true;
    try {
      const now = new Date();
      // Exclude previously processed attendance before limiting the batch.
      const activ = await this.prisma.bookings.findMany({
        where: { status: 'CONFIRMED', checked_in_at: null,
          slots: { ends_at: { lte: now } },
          booking_events: { none: { to_status: { in: ['CHECKED_IN', 'NO_SHOW'] } } } },
        select: { id: true }, orderBy: { starts_at: 'asc' }, take: 200,
      });
      const walkIns = await this.prisma.partner_walk_in_reservations.findMany({
        where: { status: 'RESERVED', ends_at: { lte: new Date(now.getTime() + INDIA_OFFSET_MS) },
          OR: [{ notes: null }, { NOT: { notes: { contains: 'Checked-in: ' } } }] },
        select: { id: true }, orderBy: { ends_at: 'asc' }, take: 200,
      });
      for (const candidate of [...activ.map(b => ({ ...b, walkIn: false })),
        ...walkIns.map(b => ({ ...b, walkIn: true }))]) {
        await this.expire(candidate.id, candidate.walkIn, now);
      }
    } catch {
      // The next sweep retries after a transient database failure. Never log booking details.
      this.logger.warn('Automatic no-show update failed; retrying on the next interval.');
    } finally { this.running = false; }
  }

  async expire(id: string, walkIn: boolean, now = new Date()) {
    await this.prisma.$transaction(async tx => {
      // Same lock as partner check-in: re-read attendance after obtaining it.
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${'booking-attendance:' + id}))`;
      if (walkIn) {
        const booking = await tx.partner_walk_in_reservations.findUnique({ where: { id } });
        if (!booking || booking.status !== 'RESERVED' || /^Checked-in: /m.test(booking.notes ?? '') ||
          !bookingHasEnded(booking.ends_at, now, true)) return;
        await tx.partner_walk_in_reservations.updateMany({ where: { id, status: 'RESERVED', notes: booking.notes },
          data: { status: 'NO_SHOW', updated_at: now } });
        return;
      }
      // Lock the booking row as well so concurrent cancellations cannot be overwritten.
      await tx.$queryRaw`SELECT id FROM bookings WHERE id = ${id}::uuid FOR UPDATE`;
      const booking = await tx.bookings.findUnique({ where: { id }, include: { slots: true } });
      if (!booking || booking.status !== 'CONFIRMED' || booking.checked_in_at ||
        !bookingHasEnded(booking.slots.ends_at, now)) return;
      const attendance = await tx.booking_events.findFirst({ where: { booking_id: id,
        to_status: { in: ['CHECKED_IN', 'NO_SHOW'] } }, orderBy: { created_at: 'desc' } });
      if (attendance) return;
      await tx.booking_events.create({ data: { id: randomUUID(), booking_id: id,
        from_status: 'CONFIRMED', to_status: 'NO_SHOW', created_at: now,
        metadata: { type: 'automatic_attendance', reason: 'slot_ended_without_check_in' } } });
    });
  }
}
