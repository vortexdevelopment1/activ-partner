import { MigrationInterface, QueryRunner } from 'typeorm';

export class VenueMultipleCategories1771220000006 implements MigrationInterface {
  name = 'VenueMultipleCategories1771220000006';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ─── STEP 1: Create venue_categories junction table ───────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "venue_categories" (
        "venue_id"    UUID NOT NULL,
        "category_id" UUID NOT NULL,
        CONSTRAINT "PK_venue_categories" PRIMARY KEY ("venue_id", "category_id"),
        CONSTRAINT "FK_venue_categories_venue"    FOREIGN KEY ("venue_id")
          REFERENCES "venues"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_venue_categories_category" FOREIGN KEY ("category_id")
          REFERENCES "categories"("id") ON DELETE CASCADE
      )
    `);

    // ─── STEP 2: Migrate existing category_id data into junction table ────────
    await queryRunner.query(`
      INSERT INTO "venue_categories" ("venue_id", "category_id")
      SELECT "id", "category_id"
      FROM "venues"
      WHERE "category_id" IS NOT NULL
      ON CONFLICT DO NOTHING
    `);

    // ─── STEP 3: Drop old FK constraint on venues.category_id ────────────────
    await queryRunner.query(`
      ALTER TABLE "venues"
        DROP CONSTRAINT IF EXISTS "FK_venues_category"
    `);

    // ─── STEP 4: Drop old index on category_id ───────────────────────────────
    await queryRunner.query(`
      DROP INDEX IF EXISTS "IDX_venues_category_id"
    `);

    // ─── STEP 5: Drop the category_id column from venues ─────────────────────
    await queryRunner.query(`
      ALTER TABLE "venues"
        DROP COLUMN IF EXISTS "category_id"
    `);

    // ─── STEP 6: Add indexes on junction table for faster lookups ─────────────
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_venue_categories_venue_id"    ON "venue_categories" ("venue_id")
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_venue_categories_category_id" ON "venue_categories" ("category_id")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // ─── Drop junction table indexes ──────────────────────────────────────────
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_venue_categories_category_id"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_venue_categories_venue_id"`);

    // ─── Re-add category_id column to venues ──────────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "venues"
        ADD COLUMN IF NOT EXISTS "category_id" UUID
    `);

    // ─── Re-add FK and index ───────────────────────────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "venues"
        ADD CONSTRAINT "FK_venues_category"
          FOREIGN KEY ("category_id") REFERENCES "categories"("id")
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_venues_category_id" ON "venues" ("category_id")
    `);

    // ─── Migrate first category back to category_id column ────────────────────
    await queryRunner.query(`
      UPDATE "venues" v
      SET "category_id" = (
        SELECT "category_id" FROM "venue_categories" vc
        WHERE vc."venue_id" = v."id"
        LIMIT 1
      )
    `);

    // ─── Drop junction table ──────────────────────────────────────────────────
    await queryRunner.query(`DROP TABLE IF EXISTS "venue_categories"`);
  }
}
