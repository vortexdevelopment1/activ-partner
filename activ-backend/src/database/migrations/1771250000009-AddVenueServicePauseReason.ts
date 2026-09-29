import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddVenueServicePauseReason1771250000009 implements MigrationInterface {
  name = 'AddVenueServicePauseReason1771250000009';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "venue_services"
        ADD COLUMN IF NOT EXISTS "pause_reason" TEXT
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "venue_services" DROP COLUMN IF EXISTS "pause_reason"
    `);
  }
}
