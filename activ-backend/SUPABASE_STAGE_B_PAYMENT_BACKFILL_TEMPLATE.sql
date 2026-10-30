-- STAGE B / TEMPLATE ONLY / DO NOT EXECUTE WITHOUT ROW-LEVEL APPROVAL
-- This file deliberately contains no active UPDATE. Preserve legacy status.

SELECT p.id, p.booking_id, p.status::text, p.provider,
       p.provider_order_id, p.provider_payment_id, p.amount_paise,
       b.total_paise,
       'ATTACH_AUTHORIZED_PROVIDER_EVIDENCE' AS evidence_required,
       'APPROVED_ORDER_STATUS_REQUIRED' AS mapping_required
FROM public.payments p
LEFT JOIN public.bookings b ON b.id = p.booking_id
ORDER BY p.created_at, p.id;

-- After each row is approved, substitute only an approved payment ID and
-- mapping in a separately reviewed transaction. Never infer CAPTURED -> PENDING.
-- Example shape, intentionally commented:
-- BEGIN;
-- UPDATE public.payments
-- SET currency = 'INR', order_status = 'CREATED'::public."PaymentOrderStatus"
-- WHERE id = '<approved-payment-uuid>'
--   AND status = 'CREATED'
--   AND provider_order_id = '<verified-order-id>'
--   AND payment_intent_key IS NULL;
-- COMMIT;

-- Required before Stage C:
SELECT count(*) AS unresolved_currency_or_order_status
FROM public.payments
WHERE currency IS NULL OR order_status IS NULL;
