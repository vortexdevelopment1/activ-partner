-- REVIEW/VALIDATION ONLY. This file intentionally performs no UPDATE.
-- Execute only after provider evidence and business approval are attached to
-- the row-by-row mapping report.

SELECT p.id,
       p.booking_id,
       p.status::text AS legacy_status,
       p.provider,
       p.provider_order_id,
       p.provider_payment_id,
       p.amount_paise,
       b.total_paise AS booking_total_paise,
       CASE WHEN p.amount_paise = b.total_paise THEN 'MATCH' ELSE 'REVIEW' END AS amount_evidence,
       CASE WHEN p.provider_order_id IS NOT NULL THEN 'PRESENT' ELSE 'MISSING' END AS order_evidence,
       CASE WHEN p.status::text = 'CAPTURED' AND p.provider_payment_id IS NOT NULL THEN 'CAPTURE_EVIDENCE_PRESENT' ELSE 'MANUAL_REVIEW' END AS capture_evidence,
       'CURRENCY_NOT_STORED' AS currency_evidence
FROM public.payments p
LEFT JOIN public.bookings b ON b.id = p.booking_id
ORDER BY p.created_at, p.id;

-- Approved mapping rules, to be applied manually in a separately reviewed
-- transaction only:
--   legacy CREATED + provider_order_id -> order_status CREATED
--   legacy FAILED -> order_status FAILED
--   legacy CAPTURED -> manual mapping after trusted provider reconciliation;
--       never infer PENDING from CAPTURED
--   payment_intent_key -> NULL unless a deterministic approved key is proven
--   currency -> INR only after external/provider evidence confirms INR

SELECT count(*) AS unsafe_rows
FROM public.payments p
LEFT JOIN public.bookings b ON b.id = p.booking_id
WHERE p.amount_paise <> b.total_paise
   OR p.provider IS NULL
   OR p.status::text = 'CAPTURED' AND p.provider_payment_id IS NULL;
