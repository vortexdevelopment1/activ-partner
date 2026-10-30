-- CreateEnum
CREATE TYPE "CatalogueStatus" AS ENUM ('PENDING', 'PUBLISHED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "ApprovalStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'ARCHIVED');

-- AlterTable (users): add admin flag
ALTER TABLE "users" ADD COLUMN "is_admin" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable (activities): map PublishStatus -> CatalogueStatus
ALTER TABLE "activities" ADD COLUMN "status_tmp" "CatalogueStatus";
UPDATE "activities" SET "status_tmp" = 'PENDING' WHERE "status" = 'DRAFT';
UPDATE "activities" SET "status_tmp" = 'PUBLISHED' WHERE "status" = 'PUBLISHED';
UPDATE "activities" SET "status_tmp" = 'ARCHIVED' WHERE "status" = 'ARCHIVED';
ALTER TABLE "activities" DROP COLUMN "status";
ALTER TABLE "activities" RENAME COLUMN "status_tmp" TO "status";
ALTER TABLE "activities" ALTER COLUMN "status" SET DEFAULT 'PENDING';

-- AlterTable (venue_activities): map PublishStatus -> ApprovalStatus
ALTER TABLE "venue_activities" ADD COLUMN "status_tmp" "ApprovalStatus";
UPDATE "venue_activities" SET "status_tmp" = 'PENDING' WHERE "status" = 'DRAFT';
UPDATE "venue_activities" SET "status_tmp" = 'APPROVED' WHERE "status" = 'PUBLISHED';
UPDATE "venue_activities" SET "status_tmp" = 'ARCHIVED' WHERE "status" = 'ARCHIVED';
ALTER TABLE "venue_activities" DROP COLUMN "status";
ALTER TABLE "venue_activities" RENAME COLUMN "status_tmp" TO "status";
ALTER TABLE "venue_activities" ALTER COLUMN "status" SET DEFAULT 'PENDING';
