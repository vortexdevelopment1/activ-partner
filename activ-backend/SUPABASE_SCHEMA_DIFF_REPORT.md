# Supabase schema diff report (read-only inspection)

Inspection date: 2026-10-29. No production DDL or data writes were executed.

## Verified target

- Database: `postgres`
- Schema: `public`
- PostgreSQL server: Supabase IPv6 endpoint
- Production rows observed: bookings 9, payments 9, slots 4,980, booking attempts 12, walk-in reservations 14.

## Verified differences relevant to the current Prisma implementation

| Object | Production | Local Prisma/migrations | Finding |
|---|---|---|---|
| `bookings.payment_deadline` | Exists, nullable `timestamp without time zone` | Nullable Prisma `DateTime`; migration file requests `TIMESTAMPTZ` | Present, physical type differs from migration text; do not convert during this rollout without timezone approval. |
| `payments.payment_intent_key` | Missing | Nullable unique text | Required before normalized order creation. |
| `payments.currency` | Missing | Non-null text, default `INR` | Required before normalized payment reads/writes. Existing rows need the default/backfill. |
| `payments.order_status` | Missing | `PaymentOrderStatus` enum, default `PENDING` | Required before normalized order creation. |
| Slot capacity checks | Production has `slots_booked_quantity_valid` (`booked_quantity >= 0 AND booked_quantity <= capacity`) and `slots_capacity_positive` | Local migration adds equivalent safety checks | Already protected in production; no duplicate production checks should be added without name reconciliation. |
| Booking references | `generate_booking_reference()` and support table exist | Present in local migration | Present. |
| Provider-order uniqueness | `(provider, provider_order_id)` unique index exists | Required by Prisma | Present. |
| Payment intent uniqueness | No column/index | Required by Prisma | Missing. |

The production catalog contains the core tables, foreign keys, indexes, functions, and no triggers in `information_schema.triggers` for the inspected schema. The full Prisma migration history is not reconciled: production stops at `20261024001000_add_booking_checked_in_at` after a failed/rolled-back `20261008_normalize_venue_data` record.

Checksum comparison found one existing tracked mismatch: `20261013_location_commissions` has production checksum `c4fbc5c3...` and the current local file hashes to `ffb26863...`. This must be reviewed before any migration-history reconciliation. The failed `20261008_normalize_venue_data` checksum matches the current local file, but its physical effects and rollback state still require explicit recovery review.

The inspection query for payment-intent duplicates could not run because the column is absent. It must be run after the column is added or against a staging clone. Existing provider-pair duplicates returned zero only after the relevant index was observed; slot invalid-counter query must be rerun on the clone before adding any new checks.

## Data safety observations

- No production rows were changed.
- Adding nullable `payment_intent_key` is additive.
- Adding `currency` with `DEFAULT 'INR'` is compatible with existing payment rows, but the application should verify every existing payment is INR before activation.
- Adding `order_status` with `DEFAULT 'PENDING'` does not prove old payments are pending; legacy rows require a reviewed backfill/state mapping before normalized order processing.
- The failed migration must not be marked applied merely to unblock later migrations.
