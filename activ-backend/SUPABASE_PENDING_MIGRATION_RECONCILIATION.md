# Pending migration reconciliation

Read-only production inspection and isolated PostgreSQL 17 rehearsal: 2026-10-30. No production SQL or `_prisma_migrations` rows were changed.

## Historical migration files

Production has 13 earlier migration names that are absent from the Partner migration folder. Exact copies were not found in Partner Git history. Same-named files exist in the read-only User App checkout, but their SHA-256 hashes do not match production checksums, so they are not safe replacements for the applied originals. They were not copied or modified.

The missing originals must be recovered from the migration owner’s repository/archive or a verified backup of migration artifacts. Do not invent SQL or use the User App copies to conceal checksum gaps.

## Pending order

1. `20261027_inactive_activity_visibility`
2. `20261029010000_add_payment_deadline`
3. `20261029020000_add_payment_order_intent`
4. `20261029030000_add_slot_capacity_checks`

## Rehearsal findings

The fresh PostgreSQL 17 clone restored from the verified dump contained 54 public tables, 9 bookings, 9 payments, and the existing slot constraints.

- Activity visibility preview: **0 candidate rows**. No archive update was executed.
- Payment deadline: column already existed as nullable `timestamp without time zone`; creating the composite index was safe and did not convert timestamps.
- Payment intent Stage A: corrected rehearsal added the enum, nullable columns, defaults and unique nullable index without changing existing rows. All 9 rows remained present and all 9 intent keys remained null.
- Slot capacity checks: production-equivalent constraints already existed as `slots_booked_quantity_valid`, `slots_capacity_positive`, and `slots_time_order`. The pending migration’s three differently named checks would be redundant and must not be applied unchanged.
- Prisma schema validation: passed.

## Required corrections

- Keep activity visibility as preview-only until an explicit archival approval exists.
- Replace the payment migration’s `NOT NULL DEFAULT` historical mutation with a nullable Stage A migration; perform evidence-backed backfill and Stage C constraints separately.
- Treat the existing payment deadline column as authoritative and add only the missing index.
- Replace the slot-check migration with an object-aware no-op/verification step, or reconcile names through an approved migration procedure. Do not add duplicate checks.

## Production blocker

The exact 13 historical migration files and their checksums are still missing from the Partner repository. Production history must not be rewritten, resolved, or replayed until those originals are recovered and the migration owner approves the tracked procedure.

## Current ledger reconciliation

- Local migration directories: 14.
- Production ledger rows: 24, including the rolled-back and finished duplicate `20261008_normalize_venue_data` rows.
- The 10 local migrations from `20261008_normalize_venue_data` through `20261024001000_add_booking_checked_in_at` have corresponding finished production rows, except that `20261008` also has its rolled-back attempt.
- The 13 older production migration names are absent from the Partner folder and remain unrecovered.
- The four local pending migration directories are not present in production history.
- Payment Stage A was manually applied and is therefore not represented by a production Prisma migration row. It must not be falsely recorded as the original non-null migration.

## Pending handling

1. `20261027_inactive_activity_visibility`: retain as a review-only migration or replace with an explicitly approved future migration. Current preview affected zero rows; do not deploy it as an accidental side effect.
2. `20261029010000_add_payment_deadline`: replace with a future tracked migration containing only the missing composite index and an object/type guard. Do not add or convert the existing column.
3. `20261029020000_add_payment_order_intent`: use a new tracked nullable Stage A migration matching the manually applied production state. Keep Stage B evidence backfill and Stage C `NOT NULL` in separate future migrations.
4. `20261029030000_add_slot_capacity_checks`: replace with a verification/no-op migration because production already has equivalent named checks. Do not add duplicate constraints.

## Safe future deployment commands

After the missing historical artifacts are recovered into the exact expected migration tree and the owner approves the ledger plan, run only against a disposable clone first:

```sh
npx prisma validate
npx prisma migrate diff --from-url "$TEST_DATABASE_URL" --to-schema-datamodel prisma/schema.prisma --script
npx prisma migrate deploy
```

The production command, if approved later, is `npx prisma migrate deploy` with the production URL explicitly selected and after preflight/backup approval. Do not run `prisma db push`, `migrate resolve`, or a reset as a substitute for missing history. The commands above were not executed against production in this review.
