import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddPhoneOtpAndContactPhone1771180000001 implements MigrationInterface {
  name = 'AddPhoneOtpAndContactPhone1771180000001';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ─── USERS: add phone_otp and otp_expires_at ─────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "users"
        ADD COLUMN IF NOT EXISTS "phone_otp"      VARCHAR,
        ADD COLUMN IF NOT EXISTS "otp_expires_at" TIMESTAMP
    `);

    // ─── PARTNERS: add contact_phone ─────────────────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "partners"
        ADD COLUMN IF NOT EXISTS "contact_phone" VARCHAR
    `);

    // ─── PARTNERS: make business_address, city, state nullable ───────────────
    await queryRunner.query(`
      ALTER TABLE "partners"
        ALTER COLUMN "business_address" DROP NOT NULL,
        ALTER COLUMN "city"             DROP NOT NULL,
        ALTER COLUMN "state"            DROP NOT NULL
    `);

    // ─── INDEX: phone lookup for OTP flow ────────────────────────────────────
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "IDX_users_phone" ON "users" ("phone")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Remove index
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_users_phone"`);

    // Restore NOT NULL on partners columns
    await queryRunner.query(`
      ALTER TABLE "partners"
        ALTER COLUMN "business_address" SET NOT NULL,
        ALTER COLUMN "city"             SET NOT NULL,
        ALTER COLUMN "state"            SET NOT NULL
    `);

    // Remove contact_phone from partners
    await queryRunner.query(`
      ALTER TABLE "partners" DROP COLUMN IF EXISTS "contact_phone"
    `);

    // Remove OTP columns from users
    await queryRunner.query(`
      ALTER TABLE "users"
        DROP COLUMN IF EXISTS "phone_otp",
        DROP COLUMN IF EXISTS "otp_expires_at"
    `);
  }
}
