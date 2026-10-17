import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Prisma } from '../../generated/prisma/client';

export async function deletePartnerAccount(tx: Prisma.TransactionClient, partnerId: string): Promise<void> {
  const partners = await tx.$queryRawUnsafe<Array<{ id: string }>>(
    'SELECT id FROM partners WHERE id = $1::uuid FOR UPDATE', partnerId,
  );
  if (!partners.length) throw new NotFoundException('Partner account not found');

  // Snapshot only this partner's graph before deleting any referenced records.
  await tx.$executeRawUnsafe('CREATE TEMP TABLE account_delete_partners ON COMMIT DROP AS SELECT id FROM partners WHERE id = $1::uuid', partnerId);
  await tx.$executeRawUnsafe('CREATE TEMP TABLE account_delete_links ON COMMIT DROP AS SELECT id, user_id, role FROM partner_users WHERE partner_id IN (SELECT id FROM account_delete_partners)');
  await tx.$executeRawUnsafe("CREATE TEMP TABLE account_delete_users ON COMMIT DROP AS SELECT id, phone_e164, is_admin FROM users WHERE id IN (SELECT user_id FROM account_delete_links WHERE role = 'PARTNER_ADMIN')");
  const protectedUsers = await tx.$queryRawUnsafe<Array<{ id: string }>>(`SELECT id FROM account_delete_users
    WHERE is_admin = true OR id IN (SELECT user_id FROM partner_users WHERE partner_id <> $1::uuid)`, partnerId);
  if (protectedUsers.length) throw new BadRequestException('This login is linked to another partner or an administrator account and cannot be deleted here');
  await tx.$queryRawUnsafe('SELECT id FROM users WHERE id IN (SELECT id FROM account_delete_users) FOR UPDATE');
  await tx.$executeRawUnsafe('CREATE TEMP TABLE account_delete_venues ON COMMIT DROP AS SELECT id FROM venues WHERE partner_id IN (SELECT id FROM account_delete_partners)');
  await tx.$executeRawUnsafe('CREATE TEMP TABLE account_delete_services ON COMMIT DROP AS SELECT id FROM partner_venue_services WHERE venue_id IN (SELECT id FROM account_delete_venues)');
  await tx.$executeRawUnsafe('CREATE TEMP TABLE account_delete_facilities ON COMMIT DROP AS SELECT id FROM facilities WHERE venue_id IN (SELECT id FROM account_delete_venues)');
  await tx.$executeRawUnsafe('CREATE TEMP TABLE account_delete_slots ON COMMIT DROP AS SELECT id FROM slots WHERE facility_id IN (SELECT id FROM account_delete_facilities)');
  await tx.$queryRawUnsafe('SELECT id FROM slots WHERE id IN (SELECT id FROM account_delete_slots) FOR UPDATE');
  await tx.$executeRawUnsafe(`CREATE TEMP TABLE account_delete_bookings ON COMMIT DROP AS SELECT id, status FROM bookings
    WHERE slot_id IN (SELECT id FROM account_delete_slots) OR user_id IN (SELECT id FROM account_delete_users)`);
  const active = await tx.$queryRawUnsafe<Array<{ id: string }>>("SELECT id FROM account_delete_bookings WHERE status IN ('PENDING_PAYMENT', 'CONFIRMED') LIMIT 1");
  if (active.length) throw new BadRequestException('Cannot delete account: please cancel or complete all pending and confirmed bookings first.');
  await tx.$executeRawUnsafe(`CREATE TEMP TABLE account_delete_attempts ON COMMIT DROP AS SELECT id FROM booking_attempts
    WHERE slot_id IN (SELECT id FROM account_delete_slots) OR user_id IN (SELECT id FROM account_delete_users)`);

  const user = 'IN (SELECT id FROM account_delete_users)';
  const partner = 'IN (SELECT id FROM account_delete_partners)';
  const venue = 'IN (SELECT id FROM account_delete_venues)';
  const booking = 'IN (SELECT id FROM account_delete_bookings)';
  const link = 'IN (SELECT id FROM account_delete_links)';
  // Table names and predicates below are internal constants; identifiers are never supplied by callers.
  const remove = (table: string, predicate: string) => tx.$executeRawUnsafe(`DELETE FROM "${table}" WHERE ${predicate}`);
  const entities = `SELECT id::text FROM account_delete_partners UNION SELECT id::text FROM account_delete_users
    UNION SELECT id::text FROM account_delete_venues UNION SELECT id::text FROM account_delete_services
    UNION SELECT id::text FROM account_delete_slots UNION SELECT id::text FROM account_delete_bookings
    UNION SELECT id::text FROM account_delete_attempts`;
  await remove('outbox_events', `aggregate_id IN (${entities})`);
  await remove('audit_events', `actor_id ${user} OR entity_id IN (${entities})`);
  await remove('otp_challenges', 'phone_e164 IN (SELECT phone_e164 FROM account_delete_users)');
  await remove('notifications', `user_id ${user} OR booking_id ${booking}`);
  await remove('support_tickets', `user_id ${user} OR booking_id ${booking}`);
  await remove('reviews', `user_id ${user} OR booking_id ${booking}`);
  await remove('coupon_redemptions', `user_id ${user} OR booking_id ${booking}`);
  await remove('refunds', `booking_id ${booking} OR payment_id IN (SELECT id FROM payments WHERE booking_id ${booking})`);
  await remove('payments', `booking_id ${booking}`);
  await remove('partner_walk_in_reservations', `partner_id ${partner} OR venue_id ${venue} OR booking_id ${booking}`);
  await remove('booking_events', `booking_id ${booking}`);
  await remove('bookings', `id ${booking}`);
  await remove('booking_attempts', 'id IN (SELECT id FROM account_delete_attempts)');
  await remove('slots', 'id IN (SELECT id FROM account_delete_slots)');
  await remove('saved_venues', `user_id ${user} OR venue_id ${venue}`);
  await remove('partner_venue_answers', `venue_id ${venue} OR answered_by_partner_user_id ${link}`);
  await tx.$executeRawUnsafe('UPDATE partner_service_questions SET venue_service_id = NULL WHERE venue_service_id IN (SELECT id FROM account_delete_services)');
  await remove('partner_venue_images', `venue_id ${venue} OR uploaded_by_partner_user_id ${link}`);
  await remove('partner_venue_update_requests', `partner_id ${partner} OR venue_id ${venue} OR requested_by_partner_user_id ${link}`);
  await remove('partner_venue_services', `venue_id ${venue}`);
  await remove('partner_venue_profiles', `partner_id ${partner} OR venue_id ${venue}`);
  await remove('venue_activities', `venue_id ${venue}`);
  await remove('facilities', 'id IN (SELECT id FROM account_delete_facilities)');
  await remove('venues', `id ${venue}`);
  await remove('partner_payouts', `partner_id ${partner}`);
  for (const table of ['partner_bank_accounts', 'partner_business_profiles', 'partner_gst_verification_requests', 'partner_notification_preferences', 'partner_city_commissions']) {
    await remove(table, `partner_id ${partner}`);
  }
  for (const table of ['partner_callback_requests', 'partner_support_requests']) {
    await remove(table, `partner_id ${partner} OR partner_user_id ${link}`);
  }
  await remove('partner_staff_profiles', `partner_user_id ${link}`);
  await remove('partner_users', `partner_id ${partner}`);
  await remove('partners', `id ${partner}`);
  await remove('sessions', `user_id ${user}`);
  await remove('user_devices', `user_id ${user}`);
  await remove('users', `id ${user}`);
}
