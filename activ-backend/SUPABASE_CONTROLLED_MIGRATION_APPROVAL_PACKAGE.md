# Controlled Supabase migration approval package

Prepared 2026-10-29 from read-only production inspection. No production DDL, data updates, migration resolution, deployment, or provider calls were performed.

## Current gate

**STOPPED before production writes.** A restorable current backup/PITR point and a successful restore rehearsal were not demonstrable from the available database connection. Supabase project-owner evidence is required before any production SQL is approved.

## Verified production identity and objects

- PostgreSQL 17.6 Supabase IPv6 endpoint, database `postgres`.
- 54 public tables.
- `20261008_normalize_venue_data` physical objects are present, including normalized venue availability and related tables.
- Production migration history contains both rolled-back and finished rows for `20261008_normalize_venue_data`.
- `20261013_location_commissions` production checksum differs from the current local file.
- Payment-order migration is not present in production history.

## Required backup gate

Before Stage A, the migration owner must attach:

1. Supabase project identity and environment confirmation.
2. Current PITR/backup retention and timestamp.
3. A restorable backup artifact or restore point containing the nine payments and related bookings.
4. Restore verification on an isolated clone, including row counts, payment/provider IDs, booking statuses, and migration metadata.
5. Named recovery operator and tested recovery command/runbook.

The repository contains no production payment export or credentials. This is intentional.

## Staged execution plan

### Stage A — additive schema

Use [SUPABASE_PRODUCTION_SCHEMA_MIGRATION.sql](./SUPABASE_PRODUCTION_SCHEMA_MIGRATION.sql) as a new, explicitly tracked migration. It creates the enum, adds nullable columns, sets defaults, and creates the nullable-safe unique intent index. It does not alter `payment_deadline` or rewrite historical payments.

Run only after the backup gate and migration-history approval. Do not use `prisma db push`.

### Stage B — evidence-backed mapping

Run [SUPABASE_PAYMENT_BACKFILL_REVIEW.sql](./SUPABASE_PAYMENT_BACKFILL_REVIEW.sql) against the restored clone first. Obtain trusted currency/provider evidence and written approval for every historical mapping. Keep all historical `payment_intent_key` values null unless replay ownership approves a deterministic key.

Six captured rows must preserve legacy `status = CAPTURED`; `order_status` is a separate order-lifecycle field and must not be invented from capture alone. Three created rows are candidates for `CREATED` only after provider-order and currency evidence.

### Stage C — constraints

After the clone and production validation queries show zero null/invalid currencies and order statuses, apply `SET NOT NULL` constraints in a separate reviewed migration. Do not perform this stage if any historical row remains unresolved.

### Stage D — application activation

Deploy the Prisma-only Partner Backend with payment traffic held or routed to a compatible version during the schema transition. Activate `NORMALIZED_BOOKING_ROUTES_ENABLED=true` and `PRISMA_LEGACY_PAYMENT_WRITES_ENABLED=true` together only after Stage C and shared-writer approval. The current OFF/OFF configuration is fail-closed for payment writes because TypeORM fallback no longer exists.

## Migration tracking

- Do not rewrite applied migration files.
- Do not edit checksums to force a match.
- Do not run `migrate resolve` until the migration owner decides how to handle the duplicate 20261008 records and the 20261013 checksum mismatch.
- Record the approved checksum comparison and physical-object comparison before adding the payment migration to the production migration sequence.

## Rollback and recovery

- Before Stage C/D, abort and restore the prior application version while leaving additive columns if necessary.
- After any committed production change, do not drop columns/type/index automatically; disable both normalized flags and use the restored backup only through the tested recovery runbook.
- Never reconstruct captured payment state from `order_status`.
- Preserve the legacy `status`, provider order ID, provider payment ID, amount, and booking association.

## Remaining approval blockers

1. Backup/PITR and restore rehearsal evidence.
2. Provider/account evidence that all historical payments are INR.
3. Per-row approval for six captured and three created lifecycle mappings.
4. Migration checksum/history reconciliation decision.
5. Shared User App payment-writer ownership and compatibility approval.
6. Controlled traffic/feature-flag activation plan.

## Verdict

**BLOCKED — not ready for production execution or final migration approval.** The SQL and staged procedure are prepared, but the mandatory recovery safeguard and historical/migration-owner approvals are missing.
