-- CANDIDATE ONLY / REVIEW GATE REQUIRED
-- 20261030010000_consolidated_remaining_schema
--
-- The current Supabase schema already contains all approved Partner Backend
-- payment Stage A objects, the booking-deadline index, and equivalent slot
-- checks. The Prisma diff therefore contains destructive drift operations
-- (legacy audit tables, constraint renames, and an existing index drop), not
-- missing approved schema. This migration is intentionally verification-only
-- so it cannot replay or silently remove existing production objects.

BEGIN;

DO $$
DECLARE
  labels text[];
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'payments'
      AND column_name = 'payment_intent_key' AND is_nullable = 'YES'
  ) THEN
    RAISE EXCEPTION 'Required nullable payments.payment_intent_key is missing or non-null';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'payments'
      AND column_name = 'currency' AND is_nullable = 'YES'
  ) THEN
    RAISE EXCEPTION 'Required nullable payments.currency is missing or non-null';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'payments'
      AND column_name = 'order_status' AND is_nullable = 'YES'
  ) THEN
    RAISE EXCEPTION 'Required nullable payments.order_status is missing or non-null';
  END IF;

  SELECT array_agg(e.enumlabel ORDER BY e.enumsortorder)
  INTO labels
  FROM pg_type t JOIN pg_enum e ON e.enumtypid = t.oid
  WHERE t.typnamespace = 'public'::regnamespace AND t.typname = 'PaymentOrderStatus';
  IF labels IS DISTINCT FROM ARRAY['PENDING','CREATED','FAILED','UNCERTAIN']::text[] THEN
    RAISE EXCEPTION 'PaymentOrderStatus is missing or incompatible: %', labels;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public' AND tablename = 'payments'
      AND indexname = 'payments_payment_intent_key_key'
  ) THEN
    RAISE EXCEPTION 'Required payment-intent unique index is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'bookings'
      AND column_name = 'payment_deadline'
      AND data_type = 'timestamp without time zone'
  ) THEN
    RAISE EXCEPTION 'bookings.payment_deadline is missing or has an incompatible type';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public' AND tablename = 'bookings'
      AND indexname = 'bookings_status_payment_deadline_idx'
  ) THEN
    RAISE EXCEPTION 'Booking deadline index is missing';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.slots'::regclass AND conname = 'slots_booked_quantity_valid' AND pg_get_constraintdef(oid) ILIKE '%booked_quantity%capacity%')
     OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.slots'::regclass AND conname = 'slots_capacity_positive' AND pg_get_constraintdef(oid) ILIKE '%capacity%0%')
     OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.slots'::regclass AND conname = 'slots_time_order' AND pg_get_constraintdef(oid) ILIKE '%ends_at%starts_at%') THEN
    RAISE EXCEPTION 'Required existing slot capacity/time constraints are missing or incompatible';
  END IF;
END $$;

-- No ALTER, UPDATE, DELETE, DROP, activity archival, payment backfill,
-- payment NOT NULL enforcement, or migration-history mutation is intentional.
COMMIT;
