-- STAGE C / REVIEW ONLY / RUN ONLY AFTER STAGE B APPROVAL
-- Requires zero unresolved rows and explicit database-owner approval.

BEGIN;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.payments WHERE currency IS NULL) THEN
    RAISE EXCEPTION 'Stage C blocked: payments.currency still contains NULL';
  END IF;
  IF EXISTS (SELECT 1 FROM public.payments WHERE order_status IS NULL) THEN
    RAISE EXCEPTION 'Stage C blocked: payments.order_status still contains NULL';
  END IF;
END $$;

ALTER TABLE public.payments
  ALTER COLUMN currency SET NOT NULL,
  ALTER COLUMN order_status SET NOT NULL;

COMMIT;
