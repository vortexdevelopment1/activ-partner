import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddVenueAndPartnerLegalFields1771190000002 implements MigrationInterface {
  name = 'AddVenueAndPartnerLegalFields1771190000002';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ─── VENUES: new fields ───────────────────────────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "venues"
        ADD COLUMN IF NOT EXISTS "venue_phone"          VARCHAR,
        ADD COLUMN IF NOT EXISTS "location_url"         VARCHAR,
        ADD COLUMN IF NOT EXISTS "flat_building"        VARCHAR,
        ADD COLUMN IF NOT EXISTS "terms_accepted"       BOOLEAN NOT NULL DEFAULT false,
        ADD COLUMN IF NOT EXISTS "terms_accepted_at"    TIMESTAMP,
        ADD COLUMN IF NOT EXISTS "electronic_signature" VARCHAR
    `);

    // Change default status from 'pending' to 'draft' for new venues
    await queryRunner.query(`
      ALTER TABLE "venues"
        ALTER COLUMN "status" SET DEFAULT 'draft'
    `);

    // ─── PARTNERS: legal document fields ─────────────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "partners"
        ADD COLUMN IF NOT EXISTS "aadhaar_name"    VARCHAR,
        ADD COLUMN IF NOT EXISTS "aadhaar_number"  VARCHAR,
        ADD COLUMN IF NOT EXISTS "pan_card_url"    VARCHAR,
        ADD COLUMN IF NOT EXISTS "aadhaar_card_url" VARCHAR,
        ADD COLUMN IF NOT EXISTS "gstin_doc_url"   VARCHAR
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Revert partners legal fields
    await queryRunner.query(`
      ALTER TABLE "partners"
        DROP COLUMN IF EXISTS "gstin_doc_url",
        DROP COLUMN IF EXISTS "aadhaar_card_url",
        DROP COLUMN IF EXISTS "pan_card_url",
        DROP COLUMN IF EXISTS "aadhaar_number",
        DROP COLUMN IF EXISTS "aadhaar_name"
    `);

    // Revert venue status default
    await queryRunner.query(`
      ALTER TABLE "venues"
        ALTER COLUMN "status" SET DEFAULT 'pending'
    `);

    // Revert venue new fields
    await queryRunner.query(`
      ALTER TABLE "venues"
        DROP COLUMN IF EXISTS "electronic_signature",
        DROP COLUMN IF EXISTS "terms_accepted_at",
        DROP COLUMN IF EXISTS "terms_accepted",
        DROP COLUMN IF EXISTS "flat_building",
        DROP COLUMN IF EXISTS "location_url",
        DROP COLUMN IF EXISTS "venue_phone"
    `);
  }
}
