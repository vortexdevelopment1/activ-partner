-- Stage B preparation: READ ONLY
-- Historical payment currency and order lifecycle
-- must be verified before updates are authorized.

SELECT
  id,
  status::text AS payment_status,
  provider,
  amount_paise,
  provider_order_id,
  currency,
  order_status::text
FROM public.payments
WHERE currency IS NULL OR order_status IS NULL
ORDER BY created_at;

SELECT COUNT(*) AS unresolved
FROM public.payments
WHERE currency IS NULL OR order_status IS NULL;
