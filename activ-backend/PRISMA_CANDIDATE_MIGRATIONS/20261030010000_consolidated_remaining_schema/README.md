# 20261030010000_consolidated_remaining_schema

Candidate migration only. It remains outside `prisma/migrations` until reviewed.

The read-only Prisma 7.10.0 diff against Supabase proposed dropping legacy audit tables, dropping the existing booking deadline index, renaming foreign keys, and dropping `booking_reference_sequences`. Those are not missing approved objects and must not be applied. The candidate therefore performs guarded verification only.

Payment Stage B/C, activity visibility, historical migration recovery, and Prisma ledger reconciliation remain separate approval items.
