-- The column already exists in production as nullable timestamp without time
-- zone. Do not add or convert it during this rollout.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'bookings'
      AND column_name = 'payment_deadline'
      AND data_type = 'timestamp without time zone'
      AND is_nullable = 'YES'
  ) THEN
    RAISE EXCEPTION 'Expected nullable public.bookings.payment_deadline timestamp without time zone is missing or incompatible';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS "bookings_status_payment_deadline_idx"
  ON public."bookings" ("status", "payment_deadline");
