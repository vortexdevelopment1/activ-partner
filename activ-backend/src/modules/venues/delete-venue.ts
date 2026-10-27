import { BadRequestException } from '@nestjs/common';
import { Prisma } from '../../generated/prisma/client';
import { ACTIVE_BOOKING_PREDICATE } from '../bookings/active-booking-predicate';

// The caller locks the venue and authorizes permanent deletion first.
export async function deleteVenue(tx: Prisma.TransactionClient, venueId: string): Promise<void> {
  await tx.$executeRawUnsafe('CREATE TEMP TABLE venue_delete_facilities ON COMMIT DROP AS SELECT id FROM facilities WHERE venue_id = $1::uuid', venueId);
  await tx.$executeRawUnsafe('CREATE TEMP TABLE venue_delete_slots ON COMMIT DROP AS SELECT id FROM slots WHERE facility_id IN (SELECT id FROM venue_delete_facilities)');
  await tx.$queryRawUnsafe('SELECT id FROM slots WHERE id IN (SELECT id FROM venue_delete_slots) FOR UPDATE');
  await tx.$executeRawUnsafe('CREATE TEMP TABLE venue_delete_bookings ON COMMIT DROP AS SELECT id, status FROM bookings WHERE slot_id IN (SELECT id FROM venue_delete_slots)');
  const active = await tx.$queryRawUnsafe<Array<{ id: string }>>(`SELECT booking.id FROM venue_delete_bookings booking WHERE ${ACTIVE_BOOKING_PREDICATE} LIMIT 1`);
  if (active.length) throw new BadRequestException('Cannot permanently delete venue: please cancel or complete all pending and confirmed bookings first.');

  const bookings = 'IN (SELECT id FROM venue_delete_bookings)';
  const slots = 'IN (SELECT id FROM venue_delete_slots)';
  // All table names and predicates are internal constants.
  const remove = (table: string, predicate: string) => tx.$executeRawUnsafe(`DELETE FROM "${table}" WHERE ${predicate}`);
  await remove('notifications', `booking_id ${bookings}`);
  await remove('support_tickets', `booking_id ${bookings}`);
  await remove('reviews', `booking_id ${bookings}`);
  await remove('coupon_redemptions', `booking_id ${bookings}`);
  await remove('refunds', `booking_id ${bookings} OR payment_id IN (SELECT id FROM payments WHERE booking_id ${bookings})`);
  await remove('payments', `booking_id ${bookings}`);
  await tx.$executeRawUnsafe(`DELETE FROM partner_walk_in_reservations WHERE venue_id = $1::uuid OR booking_id ${bookings}`, venueId);
  await remove('booking_events', `booking_id ${bookings}`);
  await remove('bookings', `id ${bookings}`);
  await remove('booking_attempts', `slot_id ${slots}`);
  await remove('slots', `id ${slots}`);
  // Questions can be shared with other venues. Detach them before deleting services.
  await tx.$executeRawUnsafe('UPDATE partner_service_questions SET venue_service_id = NULL WHERE venue_service_id IN (SELECT id FROM partner_venue_services WHERE venue_id = $1::uuid)', venueId);
  await tx.$executeRawUnsafe('DELETE FROM partner_venue_answers WHERE venue_id = $1::uuid', venueId);
  await tx.$executeRawUnsafe('DELETE FROM partner_venue_images WHERE venue_id = $1::uuid', venueId);
  await tx.$executeRawUnsafe('DELETE FROM partner_venue_services WHERE venue_id = $1::uuid', venueId);
  await remove('facilities', 'id IN (SELECT id FROM venue_delete_facilities)');
  // Remaining venue children (profiles, images, answers, amenities, availability,
  // legal documents, update requests, saved venues and activities) cascade.
  await tx.venues.delete({ where: { id: venueId } });
}
