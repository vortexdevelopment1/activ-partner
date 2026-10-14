require('ts-node/register');
const { config } = require('dotenv');
const { Client } = require('pg');
const { getMigrationDatabaseUrlFromEnv } = require('../src/config/database.config');

const env = {
  ...process.env,
  ...config({ path: '.env', quiet: true }).parsed,
  ...config({ path: '.env.local', quiet: true }).parsed,
};
const client = new Client({ connectionString: getMigrationDatabaseUrlFromEnv(env) });

async function main() {
  await client.connect();
  const execute = process.argv.includes('--execute');
  const deleted = {};
  await client.query('BEGIN');
  try {
    await client.query("SET LOCAL lock_timeout = '10s'");
    await client.query("SET LOCAL statement_timeout = '60s'");
    // Lock the known schema, including catalogues, while snapshotting and deleting.
    const tables = await client.query("SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename <> '_prisma_migrations' ORDER BY tablename");
    const quote = (name) => '"' + name.replaceAll('"', '""') + '"';
    await client.query(`LOCK TABLE ${tables.rows.map((row) => `public.${quote(row.tablename)}`).join(', ')} IN SHARE ROW EXCLUSIVE MODE`);
    await client.query('CREATE TEMP TABLE cleanup_partners ON COMMIT DROP AS SELECT id FROM partners');
    await client.query('CREATE TEMP TABLE cleanup_links ON COMMIT DROP AS SELECT id, user_id FROM partner_users WHERE partner_id IN (SELECT id FROM cleanup_partners)');
    await client.query(`CREATE TEMP TABLE cleanup_users ON COMMIT DROP AS SELECT id, phone_e164 FROM users
      WHERE is_admin = false AND (id IN (SELECT user_id FROM cleanup_links) OR email = $1)`,
      [env.PARTNER_EMAIL || 'partner@activ.com']);
    await client.query('CREATE TEMP TABLE cleanup_venues ON COMMIT DROP AS SELECT id FROM venues WHERE partner_id IN (SELECT id FROM cleanup_partners)');
    await client.query('CREATE TEMP TABLE cleanup_services ON COMMIT DROP AS SELECT id FROM partner_venue_services WHERE venue_id IN (SELECT id FROM cleanup_venues)');
    await client.query('CREATE TEMP TABLE cleanup_facilities ON COMMIT DROP AS SELECT id FROM facilities WHERE venue_id IN (SELECT id FROM cleanup_venues)');
    await client.query('CREATE TEMP TABLE cleanup_slots ON COMMIT DROP AS SELECT id FROM slots WHERE facility_id IN (SELECT id FROM cleanup_facilities)');
    await client.query(`CREATE TEMP TABLE cleanup_bookings ON COMMIT DROP AS SELECT id FROM bookings
      WHERE slot_id IN (SELECT id FROM cleanup_slots) OR user_id IN (SELECT id FROM cleanup_users)`);
    await client.query(`CREATE TEMP TABLE cleanup_attempts ON COMMIT DROP AS SELECT id FROM booking_attempts
      WHERE slot_id IN (SELECT id FROM cleanup_slots) OR user_id IN (SELECT id FROM cleanup_users)`);
    const preserved = async () => (await client.query(`SELECT
      (SELECT array_agg(id ORDER BY id) FROM users WHERE is_admin = true) admins,
      (SELECT array_agg(id ORDER BY id) FROM users WHERE id NOT IN (SELECT id FROM cleanup_users)) other_users,
      (SELECT array_agg(id ORDER BY id) FROM activities) activities,
      (SELECT array_agg(id ORDER BY id) FROM partner_service_categories) categories,
      (SELECT array_agg(id ORDER BY id) FROM partner_service_questions) questions,
      (SELECT array_agg(id ORDER BY id) FROM content_documents) documents,
      (SELECT array_agg(id ORDER BY id) FROM faqs) faqs,
      (SELECT array_agg(id ORDER BY id) FROM coupons) coupons,
      (SELECT array_agg(id ORDER BY id) FROM partner_city_commissions WHERE partner_id IS NULL) global_commissions`)).rows[0];
    const before = await preserved();
    const remove = async (table, predicate) => {
      const result = await client.query(`DELETE FROM ${quote(table)} WHERE ${predicate}`);
      deleted[table] = result.rowCount;
    };
    const user = 'IN (SELECT id FROM cleanup_users)';
    const partner = 'IN (SELECT id FROM cleanup_partners)';
    const venue = 'IN (SELECT id FROM cleanup_venues)';
    const booking = 'IN (SELECT id FROM cleanup_bookings)';
    const link = 'IN (SELECT id FROM cleanup_links)';
    await remove('outbox_events', `aggregate_id IN (
      SELECT id::text FROM cleanup_partners UNION SELECT id::text FROM cleanup_users
      UNION SELECT id::text FROM cleanup_venues UNION SELECT id::text FROM cleanup_services
      UNION SELECT id::text FROM cleanup_slots UNION SELECT id::text FROM cleanup_bookings
      UNION SELECT id::text FROM cleanup_attempts)`);
    await remove('audit_events', `actor_id ${user} OR entity_id IN (
      SELECT id::text FROM cleanup_partners UNION SELECT id::text FROM cleanup_users
      UNION SELECT id::text FROM cleanup_venues UNION SELECT id::text FROM cleanup_services
      UNION SELECT id::text FROM cleanup_slots UNION SELECT id::text FROM cleanup_bookings)`);
    await remove('otp_challenges', 'phone_e164 IN (SELECT phone_e164 FROM cleanup_users)');
    await remove('notifications', `user_id ${user} OR booking_id ${booking}`);
    await remove('support_tickets', `user_id ${user} OR booking_id ${booking}`);
    await remove('reviews', `user_id ${user} OR booking_id ${booking}`);
    await remove('coupon_redemptions', `user_id ${user} OR booking_id ${booking}`);
    await remove('refunds', `booking_id ${booking} OR payment_id IN (SELECT id FROM payments WHERE booking_id ${booking})`);
    await remove('payments', `booking_id ${booking}`);
    await remove('partner_walk_in_reservations', `partner_id ${partner} OR venue_id ${venue} OR booking_id ${booking}`);
    await remove('booking_events', `booking_id ${booking}`);
    await remove('bookings', `id ${booking}`);
    await remove('booking_attempts', 'id IN (SELECT id FROM cleanup_attempts)');
    await remove('slots', 'id IN (SELECT id FROM cleanup_slots)');
    await remove('saved_venues', `user_id ${user} OR venue_id ${venue}`);
    await remove('partner_venue_answers', `venue_id ${venue} OR answered_by_partner_user_id ${link}`);
    // Retain every question, including any formerly attached to a deleted service.
    await client.query('UPDATE partner_service_questions SET venue_service_id = NULL WHERE venue_service_id IN (SELECT id FROM cleanup_services)');
    await remove('partner_venue_images', `venue_id ${venue}`);
    await remove('partner_venue_update_requests', `partner_id ${partner} OR venue_id ${venue}`);
    await remove('partner_venue_services', `venue_id ${venue}`);
    await remove('partner_venue_profiles', `partner_id ${partner} OR venue_id ${venue}`);
    await remove('venue_activities', `venue_id ${venue}`);
    await remove('facilities', 'id IN (SELECT id FROM cleanup_facilities)');
    await remove('venues', `id ${venue}`);
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
    await remove('users', `id ${user} AND is_admin = false`);
    if (JSON.stringify(before) !== JSON.stringify(await preserved())) {
      throw new Error('Preserved accounts or reference data changed; rolling back.');
    }
    const remaining = (await client.query(`SELECT
      (SELECT count(*) FROM partners) partners,
      (SELECT count(*) FROM venues) venues,
      (SELECT count(*) FROM partner_users) partner_users,
      (SELECT count(*) FROM users WHERE is_admin=true) admins,
      (SELECT count(*) FROM users WHERE email=$1 AND is_admin=false) demo_partner_accounts`,
      [env.PARTNER_EMAIL || 'partner@activ.com'])).rows[0];
    if (remaining.partners !== '0' || remaining.venues !== '0' || remaining.partner_users !== '0' || remaining.demo_partner_accounts !== '0') {
      throw new Error('Partner cleanup verification failed; rolling back.');
    }
    await client.query(execute ? 'COMMIT' : 'ROLLBACK');
    console.log(JSON.stringify({ mode: execute ? 'committed' : 'dry-run rolled back', deleted, remaining,
      preserved: 'Admin/customer accounts, catalogues, questions, agreement documents, FAQs, coupons and global commissions verified.' }, null, 2));
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
}).finally(() => client.end());
