# Missing email delivery table: safe recovery

The approval transaction intentionally reads and writes `email_deliveries` even
with `EMAIL_PROVIDER=legacy` and `EMAIL_DELIVERY_ENABLED=false`. This guarantees
one durable approval receipt and consistent credentials/publication. Disabling
the worker or choosing SMTP does not remove that schema prerequisite. Do not
catch the missing-table error and continue approving a venue.

## Diagnosis without connecting

From `activ-backend`:

```powershell
npm.cmd run prisma:email:check
```

This prints only host, port, database and schema. It opens no connections and
does not display passwords, usernames, full URLs, tokens or environment values.
Runtime uses `getDatabaseUrlFromEnv`; Prisma 7 uses
`getMigrationDatabaseUrlFromEnv`, which prefers `DIRECT_URL`. Different pooler
ports can be expected, but do not prove that both URLs reach the same tenant.
Confirm the database/project identity with its owner.

On 2026-10-29 the workspace selected a **remote Supabase pooler** for both paths:
runtime port 6543, migrations port 5432, database `postgres`, schema `public`.
Being served from `localhost:3000` does not make its database local. Its
development/production role was not verified; no connection, backup, migration
or partner-data changes were made to that target during this diagnosis.

For an independently confirmed loopback development target only:

```powershell
npm.cmd run prisma:email:check -- --inspect-local
```

The command rejects remote or production targets before connecting. Otherwise
it performs read-only catalog checks against both configured endpoints, listing
columns, indexes, CHECK/FK constraints and migration receipt completion flags.
It never reads email payloads, OAuth credentials or partner records. It cannot
identify an already-running process's inherited environment; restart the
development backend after verifying that its shell and the CLI use the same
configuration.

## Repair a confirmed development database

1. Stop local application writers and retry workers. Confirm the database is
   dedicated development, not a proxy/tunnel to production. If remote, obtain
   the owner's explicit confirmation before **any** connection. The local audit
   command deliberately cannot authorize remote access.
2. Back up the whole verified database to a restricted directory outside the
   repository/Docker build context. With PostgreSQL 16 client tools, use
   `pg_dump --host=<verified-host> --port=<direct-port> --username=<role> --dbname=<database> --format=custom --file=<restricted-path>/before-email-schema.dump`.
   Let the client prompt for a password or use a protected PostgreSQL password
   file; do not put passwords/connection URLs into command arguments, logs or
   source files. Verify the dump using `pg_restore --list <dump-path>` privately
   (its contents can identify application data) and test restoration into a
   separate disposable database. Never restore over the working database.
3. In a shell targeting that same verified database run:
   `npx.cmd --no-install prisma migrate status --config ./prisma7.config.ts`.
   This is a database connection; do not run it against an unverified target.
   Exit 1 can mean pending migrations. Inspect `_prisma_migrations` for failed,
   incomplete or rolled-back receipts; don't print the `logs` field publicly.
4. Review **every** pending migration. The repository begins with
   `ALTER TABLE venues`, not a complete initial baseline. Never run this history
   on an empty database or assume an existing manually created schema has
   matching receipts. A missing/inconsistent baseline requires a per-migration
   schema/data review and database-owner reconciliation. Do not bulk mark
   historical migrations applied or execute `migrate reset`, `db push` or
   `migrate dev` as a shortcut.
5. The expected additions are
   `20261029000000_email_deliveries` and
   `20261029010000_google_oauth_credentials`. They create new tables/indexes/
   CHECK constraints only; neither modifies partner records or existing OAuth
   tokens. Neither has a partner/venue FK by design. The schema and generated
   client already contain both models. **Only if all pending migrations are
   reviewed, safe, and history is consistent**, run:

   ```powershell
   npx.cmd --no-install prisma migrate deploy --config ./prisma7.config.ts
   npx.cmd --no-install prisma migrate status --config ./prisma7.config.ts
   npx.cmd --no-install prisma validate --config ./prisma7.config.ts
   npm.cmd run prisma:generate
   ```

   `migrate deploy` applies every pending migration, not just these two. If an
   earlier migration fails or existing tables conflict, stop and investigate.
   Never mark either new migration applied unless the full catalog matches its
   SQL. Partial DDL from a failed migration needs explicit reviewed recovery;
   `IF NOT EXISTS` alone is not schema verification.
6. Verify both table catalogs, primary/unique/retry indexes, status constraints,
   and successful migration receipts/checksums. The integration suite contains
   executable catalog assertions in
   `test/postgres/email-schema.integration.spec.ts`. Verify runtime and direct
   endpoints see the same catalogs. Do not inspect encrypted token values.
7. Preserve the existing `EMAIL_DELIVERY_STORAGE_KEY` and OAuth storage key;
   replacing them makes existing ciphertext unreadable. The approval path also
   requires a valid delivery key in legacy mode. Do not turn on workers or change
   providers while repairing schema. Restart the local backend with the verified
   environment and regenerated client.
8. Verify approvals with isolated fixtures/mocked providers only using
   `npm.cmd run test:postgres` and `npm.cmd test -- --runInBand`. Do not click
   approve on actual partner records to test the repair. Repeat migration deploy
   should be a no-op. No email, SMS or Google authorization is required.

## Rollback

Do not drop either table after it contains deliveries or credentials. If the
application must be rolled back, keep the additive schema and stable encryption
keys; select only a reviewed compatible application revision. Pause the local
retry worker during incident investigation. Restore backups only into a new
database, verify it, then switch a **development** target deliberately. Production
recovery or environment changes require a separate authorized operation.

## Isolated verification limits

`npm.cmd run test:postgres` creates and stops its own loopback PostgreSQL cluster,
builds a synthetic prior schema, applies the actual additive migrations through
Prisma 7, checks migration status and repeat-deploy behavior, and tests approval
atomicity, retries and concurrency. It never consumes the workspace database URL.
Synthetic historical receipts in that disposable cluster do **not** reconcile
the configured Supabase database's history. A passing suite cannot establish
that the running backend's missing table has been repaired.

Verified locally on 2026-10-29: all four isolated PostgreSQL suites passed
(21 tests), including the three new migration catalog checks. The full Jest
run passed 87 suites and 564 tests; 38 opt-in database tests were skipped.
Prisma 7 validation, client generation (7.10.0), and the NestJS production build
passed. Validation/generation/build used an injected dummy loopback URL, with
local environment-file loading disabled. No remote migration-status command
was run; status/deploy/no-op checks ran only in the disposable cluster. No
backup was taken of the unverified remote target and its missing table remains
unrepaired until its identity/history can be safely checked.
