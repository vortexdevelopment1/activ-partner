import { MigrationInterface, QueryRunner } from 'typeorm';

export class VenueServiceActivityLifecycle1771230000007 implements MigrationInterface {
  name = 'VenueServiceActivityLifecycle1771230000007';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ─── venue_services: category link + per-activity approval lifecycle ──────
    await queryRunner.query(`
      ALTER TABLE "venue_services"
        ADD COLUMN IF NOT EXISTS "category_id" UUID
    `);

    await queryRunner.query(`
      ALTER TABLE "venue_services"
        ADD CONSTRAINT "FK_venue_services_category"
          FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE SET NULL
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_venue_services_category_id" ON "venue_services" ("category_id")
    `);

    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "venue_services_status_enum" AS ENUM ('draft', 'pending', 'approved', 'rejected');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryRunner.query(`
      ALTER TABLE "venue_services"
        ADD COLUMN IF NOT EXISTS "status" "venue_services_status_enum" NOT NULL DEFAULT 'draft'
    `);

    await queryRunner.query(`
      ALTER TABLE "venue_services"
        ADD COLUMN IF NOT EXISTS "amenities" JSON
    `);

    await queryRunner.query(`
      ALTER TABLE "venue_services"
        ADD COLUMN IF NOT EXISTS "rejection_reason" TEXT
    `);

    await queryRunner.query(`
      ALTER TABLE "venue_services"
        ADD COLUMN IF NOT EXISTS "submitted_at" TIMESTAMP
    `);

    await queryRunner.query(`
      ALTER TABLE "venue_services"
        ADD COLUMN IF NOT EXISTS "approved_at" TIMESTAMP
    `);

    await queryRunner.query(`
      ALTER TABLE "venue_services"
        ADD COLUMN IF NOT EXISTS "approved_by" UUID
    `);

    // Existing rows were created via the original venue-onboarding wizard —
    // treat them as already-approved activities since their parent venue is approved.
    await queryRunner.query(`
      UPDATE "venue_services" SET "status" = 'approved' WHERE "status" = 'draft'
    `);

    // ─── venue_answers: optional link to a specific activity ──────────────────
    await queryRunner.query(`
      ALTER TABLE "venue_answers"
        ADD COLUMN IF NOT EXISTS "venue_service_id" UUID
    `);

    await queryRunner.query(`
      ALTER TABLE "venue_answers"
        ADD CONSTRAINT "FK_venue_answers_venue_service"
          FOREIGN KEY ("venue_service_id") REFERENCES "venue_services"("id") ON DELETE CASCADE
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_venue_answers_venue_service_id" ON "venue_answers" ("venue_service_id")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_venue_answers_venue_service_id"`);
    await queryRunner.query(`
      ALTER TABLE "venue_answers" DROP CONSTRAINT IF EXISTS "FK_venue_answers_venue_service"
    `);
    await queryRunner.query(`
      ALTER TABLE "venue_answers" DROP COLUMN IF EXISTS "venue_service_id"
    `);

    await queryRunner.query(`
      ALTER TABLE "venue_services" DROP COLUMN IF EXISTS "approved_by"
    `);
    await queryRunner.query(`
      ALTER TABLE "venue_services" DROP COLUMN IF EXISTS "approved_at"
    `);
    await queryRunner.query(`
      ALTER TABLE "venue_services" DROP COLUMN IF EXISTS "submitted_at"
    `);
    await queryRunner.query(`
      ALTER TABLE "venue_services" DROP COLUMN IF EXISTS "rejection_reason"
    `);
    await queryRunner.query(`
      ALTER TABLE "venue_services" DROP COLUMN IF EXISTS "amenities"
    `);
    await queryRunner.query(`
      ALTER TABLE "venue_services" DROP COLUMN IF EXISTS "status"
    `);
    await queryRunner.query(`DROP TYPE IF EXISTS "venue_services_status_enum"`);

    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_venue_services_category_id"`);
    await queryRunner.query(`
      ALTER TABLE "venue_services" DROP CONSTRAINT IF EXISTS "FK_venue_services_category"
    `);
    await queryRunner.query(`
      ALTER TABLE "venue_services" DROP COLUMN IF EXISTS "category_id"
    `);
  }
}
