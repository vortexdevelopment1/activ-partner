import { MigrationInterface, QueryRunner } from 'typeorm';

export class PartnerStandaloneAuth1771210000005 implements MigrationInterface {
  name = 'PartnerStandaloneAuth1771210000005';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ─── STEP 1: Drop venues FK that references users.id ─────────────────────
    // Must be done before dropping user_id from partners, because venues.partner_id
    // previously pointed to users.id (not partners.id).
    await queryRunner.query(`
      ALTER TABLE "venues"
        DROP CONSTRAINT IF EXISTS "FK_venues_partner"
    `);

    // ─── STEP 2: Add auth fields to partners ──────────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "partners"
        ADD COLUMN IF NOT EXISTS "first_name"      VARCHAR,
        ADD COLUMN IF NOT EXISTS "last_name"       VARCHAR,
        ADD COLUMN IF NOT EXISTS "email"           VARCHAR,
        ADD COLUMN IF NOT EXISTS "password"        VARCHAR,
        ADD COLUMN IF NOT EXISTS "phone"           VARCHAR,
        ADD COLUMN IF NOT EXISTS "phone_otp"       VARCHAR,
        ADD COLUMN IF NOT EXISTS "otp_expires_at"  TIMESTAMP
    `);

    // ─── STEP 3: Make business_name nullable (needed for OTP-only partners) ───
    await queryRunner.query(`
      ALTER TABLE "partners"
        ALTER COLUMN "business_name" DROP NOT NULL
    `);

    // ─── STEP 4: Change is_active default to false (inactive until approved) ──
    await queryRunner.query(`
      ALTER TABLE "partners"
        ALTER COLUMN "is_active" SET DEFAULT false
    `);

    // ─── STEP 5: Add unique constraint on partners.email ─────────────────────
    await queryRunner.query(`
      DO $$ BEGIN
        ALTER TABLE "partners" ADD CONSTRAINT "UQ_partners_email" UNIQUE ("email");
      EXCEPTION WHEN duplicate_table THEN NULL;
      END $$
    `);

    // ─── STEP 6: Add index on partners.phone for OTP lookups ─────────────────
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_partners_phone" ON "partners" ("phone")
    `);

    // ─── STEP 7: Drop user_id FK and index from partners ─────────────────────
    await queryRunner.query(`
      DROP INDEX IF EXISTS "IDX_partners_user_id"
    `);

    await queryRunner.query(`
      ALTER TABLE "partners"
        DROP CONSTRAINT IF EXISTS "FK_partners_user"
    `);

    await queryRunner.query(`
      ALTER TABLE "partners"
        DROP COLUMN IF EXISTS "user_id"
    `);

    // ─── STEP 8: Re-add venues FK now pointing to partners.id ────────────────
    await queryRunner.query(`
      ALTER TABLE "venues"
        ADD CONSTRAINT "FK_venues_partner"
          FOREIGN KEY ("partner_id") REFERENCES "partners"("id")
    `);

    // ─── STEP 9: Remove OTP fields from users (moved to partners) ────────────
    await queryRunner.query(`
      DROP INDEX IF EXISTS "IDX_users_phone"
    `);

    await queryRunner.query(`
      ALTER TABLE "users"
        DROP COLUMN IF EXISTS "phone_otp",
        DROP COLUMN IF EXISTS "otp_expires_at"
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // ─── Restore OTP fields on users ─────────────────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "users"
        ADD COLUMN IF NOT EXISTS "phone_otp"      VARCHAR,
        ADD COLUMN IF NOT EXISTS "otp_expires_at" TIMESTAMP
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_users_phone" ON "users" ("phone")
    `);

    // ─── Drop venues FK to partners ───────────────────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "venues"
        DROP CONSTRAINT IF EXISTS "FK_venues_partner"
    `);

    // ─── Restore user_id on partners ──────────────────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "partners"
        ADD COLUMN IF NOT EXISTS "user_id" UUID
    `);

    await queryRunner.query(`
      ALTER TABLE "partners"
        ADD CONSTRAINT "FK_partners_user"
          FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_partners_user_id" ON "partners" ("user_id")
    `);

    // ─── Remove auth fields from partners ─────────────────────────────────────
    await queryRunner.query(`
      DROP INDEX IF EXISTS "IDX_partners_phone"
    `);

    await queryRunner.query(`
      ALTER TABLE "partners"
        DROP CONSTRAINT IF EXISTS "UQ_partners_email"
    `);

    await queryRunner.query(`
      ALTER TABLE "partners"
        ALTER COLUMN "is_active" SET DEFAULT true
    `);

    await queryRunner.query(`
      ALTER TABLE "partners"
        ALTER COLUMN "business_name" SET NOT NULL
    `);

    await queryRunner.query(`
      ALTER TABLE "partners"
        DROP COLUMN IF EXISTS "otp_expires_at",
        DROP COLUMN IF EXISTS "phone_otp",
        DROP COLUMN IF EXISTS "phone",
        DROP COLUMN IF EXISTS "password",
        DROP COLUMN IF EXISTS "email",
        DROP COLUMN IF EXISTS "last_name",
        DROP COLUMN IF EXISTS "first_name"
    `);

    // ─── Restore venues FK to users ───────────────────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "venues"
        ADD CONSTRAINT "FK_venues_partner"
          FOREIGN KEY ("partner_id") REFERENCES "users"("id")
    `);
  }
}
