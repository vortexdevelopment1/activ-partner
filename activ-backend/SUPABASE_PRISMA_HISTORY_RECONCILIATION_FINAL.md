# Final Prisma migration-history reconciliation

Review date: 2026-10-30. No production writes, migration resolution, deployment, or `_prisma_migrations` changes were performed.

## Artifact search result

Searched all Partner Git refs, archived paths, available project repositories, local temporary backup artifacts, and Codex workspace artifacts.

The following 13 production migration names remain absent from the Partner migration tree and were not recovered byte-for-byte:

```text
20260826072657_init
20260826073000_database_invariants
20260903090000_activity_type
20260903100000_catalogue_approval_workflow
20260903110000_booking_reschedule_count
20260905131705_0001
20260905203714_venue_profile_metadata
20260906183359_notification_read_at
20260907140000_add_user_devices
20260909000000_add_user_email_photo
20260916082859_add_admin_password_auth
20260930000000_add_partner_additive_domain_models
20260930083621_add_partner_additive_domain_models
```

Same-named User App files exist, but their hashes do not match the production checksums. They are not replacements and were not copied. The logical database dump contains migration metadata, not the original migration SQL files.

## Production ledger versus local tree

- Production: 24 ledger rows.
- Local: 14 migration directories.
- Production has finished rows corresponding to the local historical migrations through `20261024001000_add_booking_checked_in_at`.
- Production also has a rolled-back and a finished `20261008_normalize_venue_data` row; both are retained.
- The four local pending directories are not present in production history.
- Payment Stage A was manually applied and is not represented by a Prisma ledger row.

## Definitive non-destructive strategy

### Preferred strategy: recover exact originals

1. Obtain the 13 original SQL files from the migration owner’s authoritative repository/archive.
2. Verify each file’s bytes against the production checksum.
3. Restore them into the exact timestamped directories without editing contents.
4. Verify `prisma validate` and a disposable-clone migration rehearsal.
5. Preserve the duplicate 20261008 records as historical evidence; do not delete or rewrite them.
6. Handle the line-ending-only 20261013 discrepancy by preserving the production/original LF file, not by forcing a checksum.
7. Add new migrations for the already-manual Stage A state and deferred Stage B/C only after owner approval.

### Fallback strategy if originals cannot be recovered

Do not invent replacement SQL and do not pretend the current tree is deployable. Create a separately reviewed baseline repository/artifact from the restored production schema and preserve the complete old ledger/checksum export as external audit evidence. The migration owner must explicitly approve the baseline transition and the exact Prisma history procedure before any production `migrate resolve` or deploy operation.

The baseline must be rehearsed on a clone first and must prove that applying the baseline to an empty database produces the intended schema while applying the approved history procedure to the existing database performs no schema replay. This fallback is not approved or executed here.

## Pending migration handling

1. `20261027_inactive_activity_visibility`: preview-only; current candidate count is zero. Keep deferred until business approval.
2. `20261029010000_add_payment_deadline`: replace with a future object/type-guarded index-only migration. Preserve the existing `timestamp without time zone` column.
3. `20261029020000_add_payment_order_intent`: represent the manually applied nullable Stage A as a new tracked migration only after history approval. Keep evidence backfill and `NOT NULL` enforcement separate.
4. `20261029030000_add_slot_capacity_checks`: replace with an object-aware verification/no-op migration because production already has equivalent constraints.

No original pending migration should be edited in place if it may be used by another environment. Create correctly named future migrations after approval.

## Clone rehearsal status

The restored PostgreSQL 17 clone previously verified:

- 54 public tables, 9 bookings, 9 payments and 24 migration rows preserved.
- Activity preview affected zero rows.
- Existing payment deadline type preserved.
- Nullable payment Stage A enum/columns/index applied without changing payment rows.
- Existing slot constraints preserved without duplicates.
- Stage B/C simulated separately.
- Partner Prisma generation, validation, reads and HTTP booking/payment tests passed.

This demonstrates schema safety, not production migration-history approval.

## Future commands after owner approval

Run against a disposable clone first:

```sh
npx prisma validate
npx prisma migrate diff --from-url "$TEST_DATABASE_URL" \
  --to-schema-datamodel prisma/schema.prisma --script
npx prisma migrate deploy
```

For production, use an explicitly selected production URL only after backup, maintenance-window, history, and evidence approval. Do not use `prisma db push`, reset, direct `_prisma_migrations` updates, or unapproved `migrate resolve`.

## Remaining approvals

- Recovery of exact 13 historical SQL files or formal baseline approval.
- Migration-owner decision for duplicate 20261008 history.
- Approval of line-ending-only 20261013 checksum handling.
- Tracking plan for manual Stage A and deferred Stage B/C.
- Historical payment evidence and backfill approval.
- Production backup/PITR and maintenance-window confirmation.

## Verdict

**NO-GO — migration history is not yet safe for future production Prisma deployment.** The database is locally rehearsed and unchanged, but exact historical artifacts or an explicitly approved baseline strategy are still required.
