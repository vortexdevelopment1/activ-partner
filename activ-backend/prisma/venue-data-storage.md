# Venue and activity storage

The venue API no longer reads or writes `venues.metadata` or
`partner_venue_services.onboarding_data` for venue/activity content.
Their existing contents remain untouched as a migration backup, not as a
live source of truth. Do not fall back to those fields for new app queries.

| Data | Table |
| --- | --- |
| Venue identity, booking acceptance, commission and review state | `venues` |
| Address, phones, opening/closing times, rules, map link and signature | `partner_venue_profiles` |
| Venue amenities | `partner_venue_amenities` |
| Activity title, description, base price, duration, capacity and active state | `partner_venue_services` |
| Activity amenities | `partner_service_amenities` |
| Weekly availability, capacity and prices per venue/category | `partner_venue_availability` |
| Venue/activity photos and cover selection | `partner_venue_images` |
| Venue legal details and document references | `partner_venue_legal_documents` |
| Slots blocked by a paused activity | `partner_service_paused_slots` |
| Onboarding question answers | `partner_venue_answers` |

Prices are integer paise in the database and rupees in existing API responses.
Image and legal-document rows contain file URLs, not file bytes.
Dynamic question answers and audit/request payloads can still use JSON;
operational venue and activity fields are normalized.

## Existing database migration

Run from `activ-backend`:

```powershell
node scripts/migrate-venue-tables.cjs --check
node scripts/migrate-venue-tables.cjs --execute
node node_modules/prisma/build/index.js generate --config prisma7.config.ts
node scripts/verify-venue-tables.cjs
```

`--check` executes the migration in a transaction and rolls it back.
`--execute` applies additive schema changes and backfills existing data in one
transaction. A checksum in `partner_schema_migrations` prevents applying the
same backfill twice. This runner is intended for the existing introspected
database, which does not have a Prisma migration baseline. Do not reset it or
use `migrate dev` to apply this migration.

Deploy/restart the updated backend together with the new schema. Old backend
instances still writing JSON will not keep the normalized tables in sync.
The frontend UI is unchanged. Public `GET /venues` and `GET /venues/:id` read
the new tables and omit legal documents and partner identity/signature data.
