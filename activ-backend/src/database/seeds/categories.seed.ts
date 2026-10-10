import { randomUUID } from 'crypto';

import {
  ActivityType,
  CatalogueStatus,
  PartnerVenueServiceStatus,
  type PrismaClient,
} from '../../generated/prisma/client';

export const CATEGORIES = [
  ['Pickle Ball', 'Pickleball court bookings', ActivityType.COURT],
  ['Padel', 'Padel court bookings', ActivityType.COURT],
  ['Badminton', 'Badminton court bookings', ActivityType.COURT],
  ['Tennis', 'Tennis court bookings', ActivityType.COURT],
  ['Squash', 'Squash court bookings', ActivityType.COURT],
  ['Basketball', 'Basketball court bookings', ActivityType.COURT],
  ['Volleyball', 'Volleyball court bookings', ActivityType.COURT],
  ['Table Tennis', 'Table tennis bookings', ActivityType.TABLE],
  ['Teqball', 'Teqball table bookings', ActivityType.TABLE],
  ['Billiards', 'Billiards table bookings', ActivityType.TABLE],
  ['Bowling', 'Bowling lane bookings', ActivityType.TABLE],
  ['Football Turf', 'Football turf bookings', ActivityType.TURF],
  ['Cricket Turf', 'Cricket turf bookings', ActivityType.TURF],
  ['Hockey', 'Hockey field bookings', ActivityType.TURF],
  ['Box Cricket', 'Box cricket arena bookings', ActivityType.TURF],
  ['Cricket Nets', 'Cricket nets bookings', ActivityType.CRICKET_NETS],
  ['Yoga', 'Yoga class bookings', ActivityType.SINGLE],
  ['Pilates', 'Pilates class bookings', ActivityType.SINGLE],
  ['Gym', 'Gym session bookings', ActivityType.SINGLE],
  ['HIIT', 'HIIT class bookings', ActivityType.SINGLE],
  ['Crossfit', 'CrossFit session bookings', ActivityType.SINGLE],
  ['Dance Fitness', 'Dance fitness class bookings', ActivityType.SINGLE],
  ['Martial Arts', 'Martial arts session bookings', ActivityType.SINGLE],
  ['MMA', 'MMA training session bookings', ActivityType.SINGLE],
  ['Boxing', 'Boxing session bookings', ActivityType.SINGLE],
  ['Swimming', 'Swimming pool bookings', ActivityType.SINGLE],
  ['Skating', 'Skating rink bookings', ActivityType.SINGLE],
  ['Trampoline', 'Trampoline park bookings', ActivityType.SINGLE],
  ['Shooting', 'Shooting range bookings', ActivityType.SINGLE],
  ['Archery', 'Archery range bookings', ActivityType.SINGLE],
  ['Bouldering', 'Bouldering wall bookings', ActivityType.SINGLE],
  ['Rock Climbing', 'Rock climbing wall bookings', ActivityType.SINGLE],
  ['Equestrian', 'Horse riding session bookings', ActivityType.SINGLE],
  ['Paintball', 'Paintball field bookings', ActivityType.SINGLE],
  ['Adventure Sports', 'Adventure sports activity bookings', ActivityType.SINGLE],
  ['Frisbee', 'Frisbee field bookings', ActivityType.SINGLE],
  ['Other Activity', 'Other sports and activity bookings', ActivityType.SINGLE],
] as const;

export const toCategorySlug = (name: string): string =>
  name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');

export async function seedCategories(prisma: PrismaClient) {
  let created = 0;
  let updated = 0;

  for (const [name, description, type] of CATEGORIES) {
    const slug = toCategorySlug(name);
    const sortOrder = CATEGORIES.findIndex(([itemName]) => itemName === name) + 1;
    const existingCategory = await prisma.partner_service_categories.findUnique({
      where: { slug },
    });

    await prisma.partner_service_categories.upsert({
      where: { slug },
      create: {
        id: randomUUID(),
        slug,
        name,
        description,
        status: PartnerVenueServiceStatus.APPROVED,
        sort_order: sortOrder,
        updated_at: new Date(),
      },
      update: {
        name,
        description,
        status: PartnerVenueServiceStatus.APPROVED,
        sort_order: sortOrder,
        updated_at: new Date(),
      },
    });

    const existingActivity = await prisma.activities.findFirst({
      where: { sport_code: slug, name },
    });

    if (existingActivity) {
      await prisma.activities.update({
        where: { id: existingActivity.id },
        data: { type, status: CatalogueStatus.PUBLISHED },
      });
      updated++;
    } else {
      await prisma.activities.create({
        data: {
          id: randomUUID(),
          sport_code: slug,
          name,
          type,
          status: CatalogueStatus.PUBLISHED,
        },
      });
      created++;
    }

    if (existingCategory) updated++;
    else created++;
  }

  console.log(`Categories/activities created: ${created}; updated: ${updated}`);
}
