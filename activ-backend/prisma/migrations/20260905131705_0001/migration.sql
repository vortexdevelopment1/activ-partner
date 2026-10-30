/*
  Warnings:

  - Made the column `status` on table `activities` required. This step will fail if there are existing NULL values in that column.
  - Made the column `status` on table `venue_activities` required. This step will fail if there are existing NULL values in that column.

*/
-- AlterTable
ALTER TABLE "activities" ALTER COLUMN "status" SET NOT NULL;

-- AlterTable
ALTER TABLE "venue_activities" ALTER COLUMN "status" SET NOT NULL;

-- CreateIndex
CREATE INDEX "activities_type_status_idx" ON "activities"("type", "status");

-- CreateIndex
CREATE INDEX "venue_activities_activity_id_venue_id_status_idx" ON "venue_activities"("activity_id", "venue_id", "status");
