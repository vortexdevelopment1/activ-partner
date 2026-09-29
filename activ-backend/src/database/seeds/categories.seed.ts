import { DataSource } from 'typeorm';
import { Category } from '../../modules/categories/entities/category.entity';
import { CategoryType } from '../../common/enums/category-type.enum';

const CATEGORIES: { name: string; description: string; type: CategoryType; order: number }[] = [
  // ── Court sports ──────────────────────────────────────────────────────────
  { name: 'Pickle Ball',      description: 'Pickleball court bookings',           type: CategoryType.COURT_BOOKING,        order: 1  },
  { name: 'Padel',            description: 'Padel court bookings',                type: CategoryType.COURT_BOOKING,        order: 2  },
  { name: 'Badminton',        description: 'Badminton court bookings',            type: CategoryType.COURT_BOOKING,        order: 3  },
  { name: 'Tennis',           description: 'Tennis court bookings',               type: CategoryType.COURT_BOOKING,        order: 4  },
  { name: 'Squash',           description: 'Squash court bookings',               type: CategoryType.COURT_BOOKING,        order: 5  },
  { name: 'Basketball',       description: 'Basketball court bookings',           type: CategoryType.COURT_BOOKING,        order: 6  },
  { name: 'Volleyball',       description: 'Volleyball court bookings',           type: CategoryType.COURT_BOOKING,        order: 7  },
  // ── Table sports ─────────────────────────────────────────────────────────
  { name: 'Table Tennis',     description: 'Table tennis bookings',               type: CategoryType.TABLE_BOOKING,        order: 8  },
  { name: 'Teqball',          description: 'Teqball table bookings',              type: CategoryType.TABLE_BOOKING,        order: 9  },
  { name: 'Billiards',        description: 'Billiards table bookings',            type: CategoryType.TABLE_BOOKING,        order: 10 },
  { name: 'Bowling',          description: 'Bowling lane bookings',               type: CategoryType.TABLE_BOOKING,        order: 11 },
  // ── Turf sports ──────────────────────────────────────────────────────────
  { name: 'Football Turf',    description: 'Football turf bookings',              type: CategoryType.TURF_BOOKING,         order: 12 },
  { name: 'Cricket Turf',     description: 'Cricket turf bookings',               type: CategoryType.TURF_BOOKING,         order: 13 },
  { name: 'Hockey',           description: 'Hockey field bookings',               type: CategoryType.TURF_BOOKING,         order: 14 },
  { name: 'Box Cricket',      description: 'Box cricket arena bookings',          type: CategoryType.TURF_BOOKING,         order: 15 },
  // ── Cricket nets ─────────────────────────────────────────────────────────
  { name: 'Cricket Nets',     description: 'Cricket nets bookings',               type: CategoryType.CRICKET_NETS_BOOKING, order: 16 },
  // ── Fitness & wellness ───────────────────────────────────────────────────
  { name: 'Yoga',             description: 'Yoga class bookings',                 type: CategoryType.SINGLE_BOOKING,       order: 17 },
  { name: 'Pilates',          description: 'Pilates class bookings',              type: CategoryType.SINGLE_BOOKING,       order: 18 },
  { name: 'Gym',              description: 'Gym session bookings',                type: CategoryType.SINGLE_BOOKING,       order: 19 },
  { name: 'HIIT',             description: 'HIIT class bookings',                 type: CategoryType.SINGLE_BOOKING,       order: 20 },
  { name: 'Crossfit',         description: 'CrossFit session bookings',           type: CategoryType.SINGLE_BOOKING,       order: 21 },
  { name: 'Dance Fitness',    description: 'Dance fitness class bookings',        type: CategoryType.SINGLE_BOOKING,       order: 22 },
  // ── Combat sports ────────────────────────────────────────────────────────
  { name: 'Martial Arts',     description: 'Martial arts session bookings',       type: CategoryType.SINGLE_BOOKING,       order: 23 },
  { name: 'MMA',              description: 'MMA training session bookings',       type: CategoryType.SINGLE_BOOKING,       order: 24 },
  { name: 'Boxing',           description: 'Boxing session bookings',             type: CategoryType.SINGLE_BOOKING,       order: 25 },
  // ── Water & adventure ────────────────────────────────────────────────────
  { name: 'Swimming',         description: 'Swimming pool bookings',              type: CategoryType.SINGLE_BOOKING,       order: 26 },
  { name: 'Skating',          description: 'Skating rink bookings',               type: CategoryType.SINGLE_BOOKING,       order: 27 },
  { name: 'Trampoline',       description: 'Trampoline park bookings',            type: CategoryType.SINGLE_BOOKING,       order: 28 },
  // ── Precision & adventure sports ─────────────────────────────────────────
  { name: 'Shooting',         description: 'Shooting range bookings',             type: CategoryType.SINGLE_BOOKING,       order: 29 },
  { name: 'Archery',          description: 'Archery range bookings',              type: CategoryType.SINGLE_BOOKING,       order: 30 },
  { name: 'Bouldering',       description: 'Bouldering wall bookings',            type: CategoryType.SINGLE_BOOKING,       order: 31 },
  { name: 'Rock Climbing',    description: 'Rock climbing wall bookings',         type: CategoryType.SINGLE_BOOKING,       order: 32 },
  { name: 'Equestrian',       description: 'Horse riding session bookings',       type: CategoryType.SINGLE_BOOKING,       order: 33 },
  { name: 'Paintball',        description: 'Paintball field bookings',            type: CategoryType.SINGLE_BOOKING,       order: 34 },
  { name: 'Adventure Sports', description: 'Adventure sports activity bookings',  type: CategoryType.SINGLE_BOOKING,       order: 35 },
  // ── Field/outdoor ────────────────────────────────────────────────────────
  { name: 'Frisbee',          description: 'Frisbee field bookings',              type: CategoryType.SINGLE_BOOKING,       order: 36 },
  // ── Catch-all ────────────────────────────────────────────────────────────
  { name: 'Other Activity',   description: 'Other sports & activity bookings',    type: CategoryType.SINGLE_BOOKING,       order: 37 },
];

export async function seedCategories(dataSource: DataSource) {
  const categoryRepo = dataSource.getRepository(Category);

  let created = 0;
  let skipped = 0;
  let disabled = 0;

  const knownNames = CATEGORIES.map((c) => c.name.toLowerCase());

  // Disable any existing category not in the 37-activity list
  const allCategories = await categoryRepo.find();
  for (const cat of allCategories) {
    if (!knownNames.includes(cat.name.toLowerCase()) && cat.isActive) {
      cat.isActive = false;
      await categoryRepo.save(cat);
      console.log(`  🚫 Disabled extra category: "${cat.name}"`);
      disabled++;
    }
  }

  // Insert missing categories from the list
  for (const def of CATEGORIES) {
    const existing = await categoryRepo
      .createQueryBuilder('c')
      .where('LOWER(c.name) = LOWER(:name)', { name: def.name })
      .getOne();

    if (existing) {
      // Re-enable if it was previously disabled
      if (!existing.isActive) {
        existing.isActive = true;
        await categoryRepo.save(existing);
        console.log(`  ✅ Re-enabled category: "${def.name}"`);
        created++;
      } else {
        console.log(`  ℹ️  Category already exists: "${def.name}"`);
        skipped++;
      }
      continue;
    }

    const category = categoryRepo.create({
      name: def.name,
      description: def.description,
      type: def.type,
      order: def.order,
      isActive: true,
    });
    await categoryRepo.save(category);
    console.log(`  ✅ Created category: "${def.name}"`);
    created++;
  }

  console.log(`\n📊 Categories seed summary:`);
  console.log(`   Created/re-enabled : ${created}`);
  console.log(`   Skipped            : ${skipped} (already active)`);
  console.log(`   Disabled           : ${disabled} (not in activity list)`);
}
