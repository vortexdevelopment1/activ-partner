require('ts-node/register');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const dotenv = require('dotenv');
const { ConfigService } = require('@nestjs/config');
const { PrismaService } = require('../src/prisma/prisma.service');
const { VenuesService } = require('../src/modules/venues/venues.service');

const root = path.resolve(__dirname, '..');
const readEnv = (file) => fs.existsSync(file) ? dotenv.parse(fs.readFileSync(file)) : {};
const env = { ...process.env, ...readEnv(path.join(root, '.env')), ...readEnv(path.join(root, '.env.local')) };
const prisma = new PrismaService(new ConfigService(env));
const service = Object.assign(Object.create(VenuesService.prototype), { prisma });

async function main() {
  await prisma.$connect();
  const venues = await prisma.venues.findMany({ select: { id: true } });
  let activities = 0;
  let schedules = 0;
  let photos = 0;
  let publicVenues = 0;
  for (const { id } of venues) {
    const venue = await service.findOne(id);
    assert.equal(venue.id, id);
    assert.doesNotThrow(() => JSON.stringify(venue));
    activities += venue.services.length;
    photos += venue.images.length;
    schedules += Object.values(venue.availability).reduce((total, days) =>
      total + days.reduce((count, day) => count + day.slots.length, 0), 0);
    for (const activity of venue.services) {
      const detail = await service.getActivityManagement(activity.id, venue.partnerId);
      assert.equal(detail.id, activity.id);
      assert.doesNotThrow(() => JSON.stringify(detail));
    }
    if (venue.status === 'approved' && venue.bookingAccept) {
      const payload = await service.findPublicVenue(id);
      assert.equal(Object.hasOwn(payload, 'partner'), false);
      assert.equal(Object.hasOwn(payload, 'electronicSignature'), false);
      assert(payload.services.every((activity) => activity.status === 'approved' && activity.isActive));
      publicVenues += 1;
    }
  }
  console.log(JSON.stringify({ venues: venues.length, activities, schedules, photos, publicVenues }));
  console.log('Table-backed venue/activity reads succeeded; public payloads exclude private partner fields.');
}

main().catch((error) => { console.error(error.message); process.exitCode = 1; })
  .finally(() => prisma.$disconnect());
