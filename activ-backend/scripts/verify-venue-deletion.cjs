// Exercise only synthetic records; the outer transaction always rolls back.
require('ts-node/register/transpile-only');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const fs = require('node:fs');
const dotenv = require('dotenv');
const { ConfigService } = require('@nestjs/config');
const { PrismaService } = require('../src/prisma/prisma.service');
const { VenuesService } = require('../src/modules/venues/venues.service');
const read = (file) => fs.existsSync(file) ? dotenv.parse(fs.readFileSync(file)) : {};
const env = { ...process.env, ...read('.env'), ...read('.env.local') };
const db = new PrismaService(new ConfigService({ ...env, DATABASE_URL: env.DIRECT_URL || env.DATABASE_URL }));
const rollback = new Error('Rollback synthetic venue verification');

async function main() {
  await db.$transaction(async (tx) => {
    const now = new Date();
    const ids = Object.fromEntries(['user', 'partner', 'venue', 'otherVenue', 'facility', 'slot', 'booking', 'payment', 'service', 'question', 'answer', 'image'].map(key => [key, randomUUID()]));
    const category = await tx.partner_service_categories.findFirst();
    const activity = await tx.activities.findFirst();
    assert(category && activity, 'Activity and category reference data required');
    await tx.users.create({ data: { id: ids.user, phone_e164: '+999' + String(BigInt('0x' + randomUUID().replaceAll('-', '').slice(0, 10))), updated_at: now } });
    await tx.partners.create({ data: { id: ids.partner, legal_name: 'Synthetic venue deletion verification', updated_at: now } });
    for (const id of [ids.venue, ids.otherVenue]) await tx.venues.create({ data: { id, partner_id: ids.partner, name: 'Synthetic venue', city_code: 'test', latitude: 0, longitude: 0, policy_version: 'test', status: 'PUBLISHED' } });
    await tx.facilities.create({ data: { id: ids.facility, venue_id: ids.venue, activity_id: activity.id, name: 'Synthetic court', capacity: 1 } });
    await tx.partner_venue_services.create({ data: { id: ids.service, venue_id: ids.venue, facility_id: ids.facility, service_category_id: category.id, title: 'Synthetic service', updated_at: now } });
    await tx.partner_service_questions.create({ data: { id: ids.question, venue_service_id: ids.service, question: 'Synthetic question', type: 'TEXT', updated_at: now } });
    await tx.partner_venue_answers.create({ data: { id: ids.answer, venue_id: ids.venue, venue_service_id: ids.service, question_id: ids.question, answer: 'test', updated_at: now } });
    await tx.partner_venue_images.create({ data: { id: ids.image, venue_id: ids.venue, venue_service_id: ids.service, url: '/synthetic.png', updated_at: now } });
    await tx.partner_venue_amenities.create({ data: { venue_id: ids.venue, title: 'Synthetic amenity' } });
    await tx.slots.create({ data: { id: ids.slot, facility_id: ids.facility, starts_at: now, ends_at: new Date(now.getTime() + 3600000), capacity: 1, price_paise: 100n } });
    await tx.bookings.create({ data: { id: ids.booking, public_code: randomUUID(), user_id: ids.user, slot_id: ids.slot, status: 'CONFIRMED', policy_version: 'test', subtotal_paise: 100n, total_paise: 100n, starts_at: now, updated_at: now } });
    await tx.payments.create({ data: { id: ids.payment, booking_id: ids.booking, provider: 'test', amount_paise: 100n, updated_at: now } });
    const service = Object.assign(Object.create(VenuesService.prototype), { prisma: { $transaction: callback => callback(tx) } });
    const admin = { id: ids.user, role: 'admin' };
    assert.deepEqual(await service.remove(ids.venue, admin), { permanentlyDeleted: false });
    const archived = await tx.venues.findUnique({ where: { id: ids.venue } });
    assert.equal(archived.status, 'ARCHIVED');
    assert.equal(archived.booking_accept, false);
    await tx.$executeRawUnsafe('SAVEPOINT venue_delete_guard');
    await assert.rejects(service.remove(ids.venue, admin), /cancel or complete/);
    await tx.$executeRawUnsafe('ROLLBACK TO SAVEPOINT venue_delete_guard');
    await tx.bookings.update({ where: { id: ids.booking }, data: { status: 'COMPLETED' } });
    assert.deepEqual(await service.remove(ids.venue, admin), { permanentlyDeleted: true });
    for (const [model, id] of [['venues', ids.venue], ['facilities', ids.facility], ['slots', ids.slot], ['bookings', ids.booking], ['payments', ids.payment], ['partner_venue_services', ids.service], ['partner_venue_answers', ids.answer], ['partner_venue_images', ids.image]]) {
      assert.equal(await tx[model].findUnique({ where: { id } }), null, `${model} should be deleted`);
    }
    assert(await tx.partners.findUnique({ where: { id: ids.partner } }), 'Partner must be preserved');
    assert(await tx.users.findUnique({ where: { id: ids.user } }), 'Customer must be preserved');
    assert(await tx.venues.findUnique({ where: { id: ids.otherVenue } }), 'Other venue must be preserved');
    assert.equal((await tx.partner_service_questions.findUnique({ where: { id: ids.question } })).venue_service_id, null);
    throw rollback;
  }, { timeout: 120000, maxWait: 15000, isolationLevel: 'Serializable' });
}
main().catch(error => {
  if (error === rollback) console.log('Archive, permanent deletion, booking guard, child cleanup and venue isolation verified. All synthetic records rolled back.');
  else { console.error('Verification failed:', error.code || error.message); process.exitCode = 1; }
}).finally(() => db.$disconnect());
