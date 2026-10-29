# Rollback plan

Do not delete production business data. If the approved additive migration causes an application issue:

1. Disable normalized routes and stop the new writer deployment.
2. Keep the added nullable column, enum, default, and index in place while the legacy TypeORM path runs; they are backward-compatible and preserving them avoids data loss.
3. Revert application code to the last known-working checkpoint.
4. Investigate and repair the migration or deployment issue using the backup/PITR process.
5. Only remove newly added schema objects after a separate reviewed change, after confirming no rows depend on them and after an explicit approval.

The existing `payment_deadline` column must not be dropped or type-converted as rollback. Migration-history reconciliation is a separate controlled operation; never mark unrelated migrations applied.
