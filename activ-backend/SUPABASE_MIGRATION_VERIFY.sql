-- Read-only verification and preflight queries. No writes.

SELECT current_database(), current_schema(), version();

SELECT table_name, column_name, data_type, udt_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='public'
  AND ((table_name='bookings' AND column_name='payment_deadline')
    OR (table_name='payments' AND column_name IN ('payment_intent_key','currency','order_status')))
ORDER BY table_name, column_name;

SELECT indexname, tablename, indexdef
FROM pg_indexes
WHERE schemaname='public'
  AND tablename IN ('payments','bookings','slots','booking_attempts')
ORDER BY tablename,indexname;

SELECT conrelid::regclass AS table_name, conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid::regclass::text IN ('public.payments','public.bookings','public.slots','public.booking_attempts')
ORDER BY 1,2;

SELECT count(*) AS duplicate_provider_pairs
FROM (SELECT provider, provider_order_id FROM payments
      WHERE provider_order_id IS NOT NULL
      GROUP BY provider, provider_order_id HAVING count(*) > 1) d;

SELECT count(*) AS non_inr_payments FROM payments WHERE currency IS NOT NULL AND currency <> 'INR';
SELECT count(*) AS invalid_slot_counters FROM slots WHERE capacity < 0 OR booked_quantity < 0 OR booked_quantity > capacity;
SELECT count(*) AS duplicate_payment_intent_groups
FROM (
  SELECT payment_intent_key
  FROM public.payments
  WHERE payment_intent_key IS NOT NULL
  GROUP BY payment_intent_key
  HAVING count(*) > 1
) d;

SELECT migration_name, started_at, finished_at, rolled_back_at, logs
FROM _prisma_migrations ORDER BY started_at;
