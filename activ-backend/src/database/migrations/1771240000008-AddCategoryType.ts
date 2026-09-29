import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddCategoryType1771240000008 implements MigrationInterface {
  name = 'AddCategoryType1771240000008';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "categories_type_enum" AS ENUM (
          'single_booking',
          'court_booking',
          'turf_booking',
          'table_booking',
          'cricket_nets_booking'
        );
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      ALTER TABLE "categories"
        ADD COLUMN IF NOT EXISTS "type" "categories_type_enum" NOT NULL DEFAULT 'single_booking'
    `);

    // Backfill existing categories per the activity → booking-type mapping.
    // Names are matched with a prefix (TRIM + ILIKE '...%') since real rows carry
    // suffixes/whitespace the source list didn't (e.g. "Paintball Arena", "Cricket Nets ").
    // Anything not matched below (Gym, Yoga Studio, CrossFit, etc.) keeps the
    // 'single_booking' column default set above.
    await queryRunner.query(`
      UPDATE "categories" SET "type" = 'court_booking'
      WHERE TRIM("name") ILIKE ANY (ARRAY[
        'Badminton%', 'Tennis%', 'Pickleball%', 'Padel%', 'Squash%', 'Basketball%', 'Volleyball%'
      ])
    `);

    await queryRunner.query(`
      UPDATE "categories" SET "type" = 'turf_booking'
      WHERE TRIM("name") ILIKE ANY (ARRAY[
        'Cricket Turf%', 'Football Turf%', 'Hockey%', 'Paintball%', 'Frisbee%'
      ])
    `);

    await queryRunner.query(`
      UPDATE "categories" SET "type" = 'table_booking'
      WHERE TRIM("name") ILIKE ANY (ARRAY[
        'Table Tennis%', 'Billiards%', 'Teqball%'
      ])
    `);

    await queryRunner.query(`
      UPDATE "categories" SET "type" = 'cricket_nets_booking'
      WHERE TRIM("name") ILIKE ANY (ARRAY[
        'Cricket Nets%'
      ])
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "categories" DROP COLUMN IF EXISTS "type"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "categories_type_enum"`);
  }
}
