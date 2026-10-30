# Supabase production migration preflight

Inspection date: 2026-10-29. This document contains reviewed SQL only. No production DDL, data update, migration resolve, or deployment was executed.

## Read-only findings

- Database identity: `postgres` on the configured Supabase endpoint.
- `public` tables: 54.
- `payments` rows: 9 (`CAPTURED`: 6, `CREATED`: 3).
- `payments.payment_intent_key`: absent.
- `payments.currency`: absent.
- `payments.order_status`: absent.
- `public."PaymentOrderStatus"`: absent.
- Payment indexes present: primary key, provider event uniqueness, provider/order uniqueness, and status/updated-at index. No payment-intent index.
- `bookings.payment_deadline`: `timestamp without time zone`, nullable, precision 3. Do not change this type during the payment rollout.
- Migration history has 24 rows, including one rolled-back and one subsequently finished `20261008_normalize_venue_data` row. `20261013_location_commissions` has the previously recorded checksum mismatch.

## Reviewed additive migration SQL

Apply only after migration-history approval and a current backup. This is deliberately not executable by this task.

```sql
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

-- Stop before defaults/backfills if any pre-existing values violate the plan.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.payments WHERE currency IS NOT NULL AND currency <> 'INR') THEN
    RAISE EXCEPTION 'Non-INR historical payment exists; obtain business approval';
  END IF;
  IF EXISTS (SELECT 1 FROM public.payments WHERE order_status IS NOT NULL) THEN
    RAISE EXCEPTION 'order_status already contains values; review before migration';
  END IF;
  IF EXISTS (SELECT 1 FROM public.payments WHERE status = 'CAPTURED') THEN
    RAISE EXCEPTION 'Captured historical payments require provider reconciliation before backfill';
  END IF;
END $$;

-- Only order lifecycle evidence is mapped. Captured is not silently treated as
-- a new order state; it requires the provider-order evidence review below.
UPDATE public.payments
SET order_status = CASE
  WHEN status = 'FAILED' THEN 'FAILED'::public."PaymentOrderStatus"
  WHEN status = 'CREATED' AND provider_order_id IS NOT NULL THEN 'CREATED'::public."PaymentOrderStatus"
  ELSE 'PENDING'::public."PaymentOrderStatus"
END,
currency = 'INR'
WHERE order_status IS NULL;

ALTER TABLE public.payments
  ALTER COLUMN currency SET DEFAULT 'INR',
  ALTER COLUMN currency SET NOT NULL,
  ALTER COLUMN order_status SET DEFAULT 'PENDING',
  ALTER COLUMN order_status SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS payments_payment_intent_key_key
  ON public.payments (payment_intent_key);

COMMIT;
```

The SQL above is not sufficient for production approval by itself: the six captured rows must be reconciled against trusted provider evidence and the legacy payment contract before any normalized verification route is enabled. `payment_intent_key` remains null for historical rows unless a deterministic, reviewed key can be proven; the unique index permits multiple nulls.

## Historical backfill decision

1. Export and checksum the nine payment rows and their associated bookings before migration.
2. Verify every historical amount is INR and reconcile each captured row to provider order/payment evidence.
3. Backfill `currency = 'INR'` only after that assertion passes.
4. Map `order_status` only from reviewed evidence: `FAILED` to `FAILED`; an order with a known provider order ID and legacy `CREATED` state to `CREATED`; ambiguous or captured-only rows remain manual-review candidates. Do not infer capture, refund, or settlement from the new column.
5. Leave historical `payment_intent_key` null unless a deterministic key is proven unique and is approved for replay/idempotency semantics.

## Preflight queries

```sql
SELECT current_database(), current_user;
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'payments'
ORDER BY ordinal_position;

SELECT status::text, count(*) FROM public.payments GROUP BY status ORDER BY 1;
SELECT provider, provider_order_id, count(*)
FROM public.payments
WHERE provider_order_id IS NOT NULL
GROUP BY provider, provider_order_id HAVING count(*) > 1;

SELECT migration_name, checksum, finished_at, rolled_back_at
FROM public."_prisma_migrations" ORDER BY started_at;
```

## Postflight queries

```sql
SELECT count(*) AS missing_currency FROM public.payments WHERE currency IS NULL;
SELECT count(*) AS missing_order_status FROM public.payments WHERE order_status IS NULL;
SELECT count(*) AS non_inr FROM public.payments WHERE currency <> 'INR';
SELECT count(*) AS duplicate_intents
FROM (SELECT payment_intent_key FROM public.payments
      WHERE payment_intent_key IS NOT NULL
      GROUP BY payment_intent_key HAVING count(*) > 1) d;
SELECT indexname FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'payments'
  AND indexname = 'payments_payment_intent_key_key';
```

## Migration-history reconciliation

Do not mark the failed migration applied and do not run `migrate resolve` yet. First compare the archived/current migration file with the production checksum and determine whether the failed row left any physical objects. Resolve the duplicate `20261008_normalize_venue_data` history only through an approved Prisma migration-history procedure, after the checksum mismatch review. The payment migration must not be considered deployable until that review is recorded.

## Recovery and rollback

- Prefer aborting before `COMMIT` if any guard fails.
- Additive columns/type/index are recoverable, but do not drop them automatically after a partial deployment.
- If the migration commits and application activation is rolled back, keep the additive schema and disable both normalized feature flags; legacy routes continue using their approved path.
- Restore data only from the preflight export after reviewing the exact affected rows. Never reconstruct captured payment state from `order_status`.
- If an index build fails, inspect duplicate non-null intent keys before retrying; do not delete payment rows.

## Deployment order

1. Freeze the reviewed SQL, checksum comparison, backup/export and approval.
2. Apply additive schema in a controlled window; do not alter `payment_deadline`.
3. Run postflight catalog/data assertions.
4. Deploy code with both normalized flags still OFF.
5. Run shadow/read-only reconciliation and payment-intent uniqueness checks.
6. Enable normalized booking/payment flows only after User App writer compatibility and historical payment mapping are approved.
7. Monitor order creation, uncertainty, verification, expiry and capacity metrics; retain an immediate flag-off procedure.

## Current verdict

**BLOCKED for production migration/cutover.** Local Prisma-only validation is complete, but production requires schema approval, historical payment reconciliation, migration-history/checksum reconciliation, and explicit confirmation that the shared User App writer uses compatible payment/capacity semantics. No production SQL was executed.
