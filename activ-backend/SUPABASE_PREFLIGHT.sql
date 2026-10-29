-- READ ONLY. Run before SUPABASE_MIGRATION_UP.sql.
SELECT current_database(), current_schema(), version();

SELECT count(*) AS bookings FROM public.bookings;
SELECT count(*) AS payments FROM public.payments;
SELECT count(*) AS slots FROM public.slots;
SELECT count(*) AS booking_attempts FROM public.booking_attempts;
SELECT count(*) AS walk_ins FROM public.partner_walk_in_reservations;

-- These checks intentionally reference only columns known to exist today.
SELECT count(*) AS duplicate_provider_pairs
FROM (
  SELECT provider, provider_order_id
  FROM public.payments
  WHERE provider_order_id IS NOT NULL
  GROUP BY provider, provider_order_id
  HAVING count(*) > 1
) d;

SELECT count(*) AS invalid_slot_counters
FROM public.slots
WHERE capacity < 0 OR booked_quantity < 0 OR booked_quantity > capacity;

SELECT count(*) AS non_positive_slot_capacity
FROM public.slots WHERE capacity <= 0;

SELECT count(*) AS missing_booking_references
FROM public.bookings WHERE booking_reference IS NULL;

SELECT routine_name
FROM information_schema.routines
WHERE routine_schema='public'
  AND routine_name IN ('generate_booking_reference','generate_activity_reference','generate_venue_reference')
ORDER BY routine_name;

SELECT migration_name, started_at, finished_at, rolled_back_at
FROM public._prisma_migrations ORDER BY started_at;
