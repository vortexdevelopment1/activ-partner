-- READ ONLY. Run after the approved migration.
SELECT table_schema,table_name,column_name,data_type,udt_name,is_nullable,column_default
FROM information_schema.columns
WHERE table_schema='public' AND table_name='payments'
  AND column_name IN ('payment_intent_key','currency','order_status')
ORDER BY column_name;

SELECT t.typname AS enum_name, e.enumlabel
FROM pg_type t JOIN pg_enum e ON e.enumtypid=t.oid
WHERE t.typnamespace='public'::regnamespace AND t.typname='PaymentOrderStatus'
ORDER BY e.enumsortorder;

SELECT indexname,indexdef
FROM pg_indexes
WHERE schemaname='public' AND tablename='payments'
  AND indexname='payments_payment_intent_key_key';

SELECT count(*) AS payment_rows,
       count(*) FILTER (WHERE currency='INR') AS inr_rows,
       count(*) FILTER (WHERE order_status='PENDING') AS pending_order_rows
FROM public.payments;

SELECT count(*) AS duplicate_payment_intents
FROM (
  SELECT payment_intent_key
  FROM public.payments
  WHERE payment_intent_key IS NOT NULL
  GROUP BY payment_intent_key
  HAVING count(*) > 1
) d;

SELECT count(*) AS invalid_slot_counters
FROM public.slots
WHERE capacity < 0 OR booked_quantity < 0 OR booked_quantity > capacity;

SELECT routine_name
FROM information_schema.routines
WHERE routine_schema='public'
  AND routine_name IN ('generate_booking_reference','generate_activity_reference','generate_venue_reference')
ORDER BY routine_name;

SELECT migration_name,started_at,finished_at,rolled_back_at
FROM public._prisma_migrations ORDER BY started_at;
