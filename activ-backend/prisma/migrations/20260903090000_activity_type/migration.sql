-- CreateEnum
CREATE TYPE "ActivityType" AS ENUM ('SINGLE', 'COURT', 'TURF', 'TABLE', 'CRICKET_NETS');

-- AlterTable
ALTER TABLE "activities" ADD COLUMN "type" "ActivityType" NOT NULL DEFAULT 'SINGLE';

-- CreateIndex
CREATE INDEX "activities_type_status_idx" ON "activities"("type", "status");
