-- Persists partner check-in independently from the booking lifecycle status.
ALTER TABLE "bookings"
ADD COLUMN IF NOT EXISTS "checked_in_at" TIMESTAMP(3);
