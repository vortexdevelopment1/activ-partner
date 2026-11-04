import { randomUUID } from "crypto";

import {
  ActivityType,
  CatalogueStatus,
  PartnerVenueServiceStatus,
  type PrismaClient,
} from "../../generated/prisma/client";

export const CATEGORIES = [
  ["Gym", "Gym session bookings", ActivityType.SINGLE],
  ["Yoga Studio", "Yoga studio bookings", ActivityType.SINGLE],
  ["Pilates", "Pilates class bookings", ActivityType.SINGLE],
  ["Zumba", "Zumba class bookings", ActivityType.SINGLE],
  ["Dance Studio", "Dance studio bookings", ActivityType.SINGLE],
  ["CrossFit", "CrossFit session bookings", ActivityType.SINGLE],
  ["HIIT Studio", "HIIT studio bookings", ActivityType.SINGLE],
  ["Bowling", "Bowling lane bookings", ActivityType.SINGLE],
  ["Trampoline", "Trampoline park bookings", ActivityType.SINGLE],
  [
    "Adventure Sports",
    "Adventure sports activity bookings",
    ActivityType.SINGLE,
  ],
  ["Rock Climbing", "Rock climbing wall bookings", ActivityType.SINGLE],
  ["Bouldering", "Bouldering wall bookings", ActivityType.SINGLE],
  ["Boxing", "Boxing session bookings", ActivityType.SINGLE],
  ["MMA", "MMA training session bookings", ActivityType.SINGLE],
  ["Martial Arts", "Martial arts session bookings", ActivityType.SINGLE],
  ["Archery", "Archery range bookings", ActivityType.SINGLE],
  ["Shooting", "Shooting range bookings", ActivityType.SINGLE],
  ["Swimming", "Swimming pool bookings", ActivityType.SINGLE],
  ["Skating", "Skating rink bookings", ActivityType.SINGLE],
  ["Equestrian", "Horse riding session bookings", ActivityType.SINGLE],
  ["Badminton", "Badminton court bookings", ActivityType.COURT],
  ["Tennis", "Tennis court bookings", ActivityType.COURT],
  ["Pickleball", "Pickleball court bookings", ActivityType.COURT],
  ["Padel", "Padel court bookings", ActivityType.COURT],
  ["Squash", "Squash court bookings", ActivityType.COURT],
  ["Basketball", "Basketball court bookings", ActivityType.COURT],
  ["Volleyball", "Volleyball court bookings", ActivityType.COURT],
  ["Padbol", "Padbol court bookings", ActivityType.COURT],
  ["Table Tennis", "Table tennis bookings", ActivityType.TABLE],
  ["Pool Table", "Pool table bookings", ActivityType.TABLE],
  ["Teqball", "Teqball table bookings", ActivityType.TABLE],
  ["Snooker", "Snooker table bookings", ActivityType.TABLE],
  ["Football Turf", "Football turf bookings", ActivityType.TURF],
  ["Cricket Turf", "Cricket turf bookings", ActivityType.TURF],
  ["Hockey", "Hockey field bookings", ActivityType.TURF],
  ["Paintball", "Paintball field bookings", ActivityType.TURF],
  ["Frisbee", "Frisbee field bookings", ActivityType.TURF],
  ["Cricket Nets", "Cricket nets bookings", ActivityType.CRICKET_NETS],
] as const;

export const toCategorySlug = (name: string): string =>
  name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");

export async function seedCategories(prisma: PrismaClient) {
  let created = 0;
  let updated = 0;

  for (const [name, description, type] of CATEGORIES) {
    const slug = toCategorySlug(name);
    const sortOrder =
      CATEGORIES.findIndex(([itemName]) => itemName === name) + 1;
    const existingCategory = await prisma.partner_service_categories.findUnique(
      {
        where: { slug },
      },
    );

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
