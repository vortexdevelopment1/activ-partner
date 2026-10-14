import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddServiceImageUrlsAndVenueAvailability1771200000003
  implements MigrationInterface
{
  name = 'AddServiceImageUrlsAndVenueAvailability1771200000003';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ─── VENUE_SERVICES: multi-image support ──────────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "venue_services"
        ADD COLUMN IF NOT EXISTS "image_urls" jsonb NOT NULL DEFAULT '[]'
    `);

    // ─── VENUES: day-wise availability ───────────────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "venues"
        ADD COLUMN IF NOT EXISTS "availability" jsonb
    `);

    // ─── VENUES: make address/city/state nullable ─────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "venues"
        ALTER COLUMN "address" DROP NOT NULL,
        ALTER COLUMN "city"    DROP NOT NULL,
        ALTER COLUMN "state"   DROP NOT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "venues"
        DROP COLUMN IF EXISTS "availability"
    `);

    await queryRunner.query(`
      ALTER TABLE "venue_services"
        DROP COLUMN IF EXISTS "image_urls"
    `);
  }
}
