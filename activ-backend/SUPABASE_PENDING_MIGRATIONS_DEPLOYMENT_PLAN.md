# Pending Supabase migration deployment plan

Review status: candidate only. No production SQL, Prisma deploy, resolve, or
database writes were executed by this review.

## Reviewed pending migrations

| Migration | Handling | Production effect |
|---|---|---|
| `20261027_inactive_activity_visibility` | Guard only; fails if candidates exist | No activity archival. Requires separate business approval. |
| `20261029010000_add_payment_deadline` | Verify nullable `timestamp without time zone`; create index if absent | No column creation or timezone conversion. |
| `20261029020000_add_payment_order_intent` | Stage A nullable columns/defaults and nullable unique index | Preserves all nine historical payments and NULL historical values. |
| `20261029030000_add_slot_capacity_checks` | Verify existing named constraints | Adds no duplicate constraints. |

The payment migration no longer declares `currency` or `order_status` NOT NULL.
Stage B evidence-backed backfill and Stage C NOT NULL enforcement remain separate
and are not approved by this package.

## Schema comparison

The read-only Prisma diff against the current Supabase schema proposed dropping
legacy audit tables, dropping the existing booking deadline index, renaming
foreign keys, and dropping `booking_reference_sequences`. Those are drift
operations, not missing approved objects, and must not be applied.

Current production objects intentionally preserved:

- nullable `payments.currency` with default `INR`;
- nullable `payments.order_status` with default `PENDING`;
- nullable unique `payments.payment_intent_key`;
- `PaymentOrderStatus` with `PENDING`, `CREATED`, `FAILED`, `UNCERTAIN`;
- nullable `bookings.payment_deadline` as `timestamp without time zone`;
- `bookings_status_payment_deadline_idx`;
- `slots_booked_quantity_valid`, `slots_capacity_positive`, and `slots_time_order`.

## Required execution order after approval

1. Recover and verify all 13 missing historical migration files byte-for-byte
   against the production checksums, or obtain formal approval for a supported
   baseline transition.
2. Export `_prisma_migrations` and obtain migration-owner approval for the
   duplicate rolled-back/finished `20261008` history and the
   `20261013_location_commissions` checksum discrepancy.
3. Rehearse the exact approved migration tree on a fresh PostgreSQL 17 clone.
4. Confirm backup/PITR, maintenance window, and a no-write application state.
5. Run only the approved migration procedure against production. Do not use
   `db push`, reset, direct ledger updates, or unapproved `migrate resolve`.
6. Run preflight/postflight catalog checks and verify payment/booking counts,
   payment status values, index definitions, and slot constraints.
7. Keep historical `currency`, `order_status`, and `payment_intent_key` values
   unchanged until separate Stage B approval.

## Recovery

If any guard fails, abort before commit. If additive Stage A changes have already
committed, keep them in place, disable normalized payment activation, and recover
only from the approved backup/export after reviewing affected rows. Never restore
captured payment state from `order_status` alone.

## Remaining blockers

- Thirteen exact historical migration artifacts/checksums are missing locally.
- Migration-owner approval is required for history reconciliation.
- Historical payment currency and lifecycle evidence is still required before
  Stage B/C.
- Production backup/PITR and maintenance-window approval must be confirmed.

**Assessment: NO-GO for production deployment.** The pending SQL is safer and
rehearsable, but the unresolved migration ledger and evidence approvals prevent
safe production execution.
