-- Reviewed but not applied to Supabase. Existing bookings remain nullable during rollout.
ALTER TABLE "bookings"
  ADD COLUMN IF NOT EXISTS "payment_deadline" TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS "bookings_status_payment_deadline_idx"
  ON "bookings" ("status", "payment_deadline");
