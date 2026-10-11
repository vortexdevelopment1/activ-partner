require('ts-node/register');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { randomUUID } = require('node:crypto');
const dotenv = require('dotenv');
const { ConfigService } = require('@nestjs/config');
const { PrismaService } = require('../src/prisma/prisma.service');
const { deletePartnerAccount } = require('../src/modules/partners/delete-partner-account');
const read = (file) => fs.existsSync(file) ? dotenv.parse(fs.readFileSync(file)) : {};
const env = { ...process.env, ...read('.env'), ...read('.env.local') };
const prisma = new PrismaService(new ConfigService({ ...env, DATABASE_URL: env.DIRECT_URL || env.DATABASE_URL }));
const rollback = new Error('Verification complete: rollback synthetic records');

async function main() {
  await prisma.$transaction(async (tx) => {
    const now = new Date();
    const ids = Object.fromEntries(['owner', 'partner', 'link', 'venue', 'facility', 'slot', 'booking', 'payment', 'staff', 'staffLink', 'otherPartner', 'otherUser', 'otherLink'].map((key) => [key, randomUUID()]));
    const phone = '+999' + String(BigInt('0x' + randomUUID().replaceAll('-', '').slice(0, 10)));
    const category = await tx.partner_service_categories.findFirst();
    const activity = await tx.activities.findFirst();
    assert(category && activity, 'Category and activity reference data are required');
    for (const [user, number] of [[ids.owner, phone], [ids.staff, phone + '1'], [ids.otherUser, phone + '2']]) {
      await tx.users.create({ data: { id: user, phone_e164: number, updated_at: now } });
    }
    for (const partner of [ids.partner, ids.otherPartner]) await tx.partners.create({ data: { id: partner, legal_name: 'Deletion verification', updated_at: now } });
    for (const [id, partner_id, user_id, role] of [[ids.link, ids.partner, ids.owner, 'PARTNER_ADMIN'], [ids.staffLink, ids.partner, ids.staff, 'PARTNER_USER'], [ids.otherLink, ids.otherPartner, ids.otherUser, 'PARTNER_ADMIN']]) {
      await tx.partner_users.create({ data: { id, partner_id, user_id, role } });
    }
    await tx.venues.create({ data: { id: ids.venue, partner_id: ids.partner, name: 'Test venue', city_code: 'test', latitude: 0, longitude: 0, policy_version: 'test' } });
    await tx.partner_venue_amenities.create({ data: { venue_id: ids.venue, title: 'WiFi' } });
    await tx.facilities.create({ data: { id: ids.facility, venue_id: ids.venue, activity_id: activity.id, name: 'Test court', capacity: 1 } });
    await tx.partner_venue_services.create({ data: { id: randomUUID(), venue_id: ids.venue, facility_id: ids.facility, service_category_id: category.id, title: 'Test activity', updated_at: now } });
    await tx.slots.create({ data: { id: ids.slot, facility_id: ids.facility, starts_at: now, ends_at: new Date(now.getTime() + 3600000), capacity: 1, price_paise: 100n } });
    await tx.bookings.create({ data: { id: ids.booking, public_code: randomUUID(), user_id: ids.otherUser, slot_id: ids.slot, status: 'COMPLETED', policy_version: 'test', subtotal_paise: 100n, total_paise: 100n, starts_at: now, updated_at: now } });
    await tx.payments.create({ data: { id: ids.payment, booking_id: ids.booking, provider: 'test', amount_paise: 100n, updated_at: now } });
    await tx.otp_challenges.create({ data: { id: randomUUID(), phone_e164: phone, code_hash: 'test', expires_at: new Date(now.getTime() + 300000) } });
    await tx.bookings.update({ where: { id: ids.booking }, data: { status: 'CONFIRMED' } });
    await tx.$executeRawUnsafe('SAVEPOINT delete_guard_check');
    await assert.rejects(deletePartnerAccount(tx, ids.partner), /cancel or complete/);
    await tx.$executeRawUnsafe('ROLLBACK TO SAVEPOINT delete_guard_check');
    assert(await tx.partners.findUnique({ where: { id: ids.partner } }), 'Blocked deletion must preserve the account');
    await tx.bookings.update({ where: { id: ids.booking }, data: { status: 'COMPLETED' } });
    await deletePartnerAccount(tx, ids.partner);
    for (const [model, id] of [['partners', ids.partner], ['users', ids.owner], ['venues', ids.venue], ['facilities', ids.facility], ['slots', ids.slot], ['bookings', ids.booking], ['payments', ids.payment], ['partner_users', ids.staffLink]]) {
      assert.equal(await tx[model].findUnique({ where: { id } }), null, model + ' should be removed');
    }
    assert.equal(await tx.otp_challenges.count({ where: { phone_e164: phone } }), 0);
    assert(await tx.users.findUnique({ where: { id: ids.staff } }), 'Staff login must be preserved');
    assert(await tx.partners.findUnique({ where: { id: ids.otherPartner } }), 'Unrelated partner must be preserved');
    assert(await tx.users.findUnique({ where: { id: ids.otherUser } }), 'Unrelated customer must be preserved');
    const freshUser = await tx.users.create({ data: { id: randomUUID(), phone_e164: phone, updated_at: now } });
    const freshPartner = await tx.partners.create({ data: { id: randomUUID(), legal_name: 'Fresh account', updated_at: now } });
    await tx.partner_users.create({ data: { id: randomUUID(), user_id: freshUser.id, partner_id: freshPartner.id, role: 'PARTNER_ADMIN' } });
    assert.notEqual(freshUser.id, ids.owner);
    assert.equal(await tx.venues.count({ where: { partner_id: freshPartner.id } }), 0);
    throw rollback;
  }, { timeout: 120000, maxWait: 15000, isolationLevel: 'Serializable' });
}
main().catch((error) => {
  if (error === rollback) console.log('Deletion, related-record cleanup, account isolation, and fresh same-phone registration verified. All synthetic records rolled back.');
  else { console.error('Verification failed:', error.code || error.message); process.exitCode = 1; }
}).finally(() => prisma.$disconnect());
