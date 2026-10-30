-- REVIEW ONLY. Do not execute until production approval, backup, and
-- migration-history reconciliation are complete.
-- Additive schema only: no payment_deadline change and no data backfill.

BEGIN;

DO $$
BEGIN
  CREATE TYPE public."PaymentOrderStatus" AS ENUM ('PENDING', 'CREATED', 'FAILED', 'UNCERTAIN');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS payment_intent_key text,
  ADD COLUMN IF NOT EXISTS currency text,
  ADD COLUMN IF NOT EXISTS order_status public."PaymentOrderStatus";

ALTER TABLE public.payments
  ALTER COLUMN currency SET DEFAULT 'INR',
  ALTER COLUMN order_status SET DEFAULT 'PENDING';

CREATE UNIQUE INDEX IF NOT EXISTS payments_payment_intent_key_key
  ON public.payments (payment_intent_key);

COMMIT;

-- NOT included intentionally: SET NOT NULL and historical backfill. Those
-- require the separate evidence review after the actual nine rows are mapped.
