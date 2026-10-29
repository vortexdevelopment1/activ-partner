# Supabase migration plan (approval required)

Status: **BLOCKED / READY FOR REVIEW ONLY**. Do not run automatically.

1. Take and verify a current Supabase backup/PITR recovery point.
2. Resolve the failed `20261008_normalize_venue_data` migration using the exact Prisma migration procedure and a reviewed physical-schema comparison. Do not mark it applied by assumption.
3. Run the preflight queries in `SUPABASE_MIGRATION_VERIFY.sql` on a staging clone.
4. Apply only the additive payment-intent statements in `SUPABASE_MIGRATION_UP.sql`.
5. Verify columns, enum, defaults, index uniqueness, row counts, and legacy payment compatibility.
6. Reconcile `_prisma_migrations` only after reviewing the physical result and Prisma checksum/history. Never resolve unrelated migrations.
7. Keep `NORMALIZED_BOOKING_ROUTES_ENABLED=false` until owner regression testing and coordinated writer cutover pass.

No production execution is approved by this artifact.
