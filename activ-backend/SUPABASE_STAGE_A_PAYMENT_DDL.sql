-- STAGE A / REVIEW ONLY / PRODUCTION EXECUTION BLOCKED
-- Requires: backup/PITR evidence, migration-history approval, maintenance
-- window, and explicit database-owner approval.
-- No historical backfill, status rewrite, or payment_deadline conversion.

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
