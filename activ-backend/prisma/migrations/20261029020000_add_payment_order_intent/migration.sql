-- Reviewed for local activ_capacity_test only; do not apply automatically to Supabase.
DO $$ BEGIN
  CREATE TYPE public."PaymentOrderStatus" AS ENUM ('PENDING', 'CREATED', 'FAILED', 'UNCERTAIN');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public."payments"
  ADD COLUMN IF NOT EXISTS "payment_intent_key" TEXT,
  ADD COLUMN IF NOT EXISTS "currency" TEXT NOT NULL DEFAULT 'INR',
  ADD COLUMN IF NOT EXISTS "order_status" public."PaymentOrderStatus" NOT NULL DEFAULT 'PENDING';

CREATE UNIQUE INDEX IF NOT EXISTS "payments_payment_intent_key_key"
  ON public."payments" ("payment_intent_key");
