# Candidate Prisma baseline

This is a candidate only. It is not part of the active `prisma/migrations` tree and has not been marked applied anywhere.

Generated with Prisma 7.10.0 using:

```sh
npx prisma migrate diff --from-empty --to-schema prisma/schema.prisma --script
```

The generated SQL is stored outside the repository for review at:

`/private/tmp/activ-prisma-baseline-20261030/prisma/migrations/00000000000000_baseline/migration.with-functions.sql`

SHA-256 of the generated baseline with the three verified production reference functions prepended is available in that temporary directory. The generated Prisma SQL covers 50 public application tables. Production also contains four non-Prisma migration/audit objects; their reviewed supplement is [SUPABASE_BASELINE_NON_PRISMA_SUPPLEMENT.sql](./SUPABASE_BASELINE_NON_PRISMA_SUPPLEMENT.sql).

## Rehearsal

- Empty PostgreSQL 17 database created successfully.
- Baseline initially failed because Prisma does not emit the production reference functions used by defaults.
- Prepending the verified `generate_activity_reference`, `generate_booking_reference`, and `generate_venue_reference` definitions fixed the dependency.
- Baseline then created all Prisma-modelled objects successfully.
- Production-only migration/audit tables were identified explicitly rather than hidden.

## Transition warning

Do not apply this baseline to the existing production database. A baseline transition requires an approved Prisma history procedure and controlled `migrate resolve` operation after the missing historical artifacts decision. No such operation was executed.
