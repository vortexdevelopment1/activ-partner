-- Add email and profile_photo to users for profile sync
ALTER TABLE "users" ADD COLUMN "email" TEXT;
ALTER TABLE "users" ADD COLUMN "profile_photo" TEXT;