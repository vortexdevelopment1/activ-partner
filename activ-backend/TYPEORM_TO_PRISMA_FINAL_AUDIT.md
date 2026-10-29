# ACTIV TypeORM-to-Prisma Final Audit

Date: 2026-10-29
Branch requested: `migration/typeorm-prisma-final`
Scope: read-only source audit. No source, schema, environment, database, or feature-flag changes were made for this audit.

## 1. Executive summary

The backend is not Prisma-only. The normalized booking/payment implementations exist, but the default production path remains legacy because `NORMALIZED_BOOKING_ROUTES_ENABLED` defaults to `false`.

The two runtime services that still require TypeORM are:

- `src/modules/bookings/bookings.service.ts`
- `src/modules/payments/payments.service.ts`

Their module registrations and the global TypeORM connection must remain until the remaining default-path methods are replaced and the application is tested by the project owner.

### Progress metrics

The corrected method inventory contains 22 database-access behaviors in the two migration-target services. This counts the three payout/reporting behaviors separately and excludes entity-only metadata, migrations, and unrelated read/write services.

| Metric | Count | Result |
|---|---:|---:|
| Active database behaviors inventoried | 22 | denominator |
| Prisma-active behaviors | 12 | 54.5% runtime migration completion |
| Prisma feature-gated behaviors | 8 | 36.4%, implemented but not default |
| TypeORM-only/contract-blocked behaviors | 2 | 9.1% |
| Complete Prisma implementation exists | 20 | 90.9% implementation coverage |
| Complete Prisma implementation is default runtime path | 12 | 54.5% |
| Prisma implementation exists but is inactive/default-off | 8 | requires activation and regression testing |

These are method-level implementation and runtime-route metrics, not proof of behavioral equivalence. Several Prisma methods still need endpoint-level coverage and production-schema verification before cutover.

## 2. Migration coverage matrix

### BookingsService

| Method/behavior | TypeORM default path | Prisma implementation | Status |
|---|---|---|---|
| `create()` / `POST /bookings` | `VenueService` and `Venue` repositories plus booking query builder | `createNormalizedFromLegacy()` | PRISMA IMPLEMENTED BUT INACTIVE |
| `findAll()` | Read path is Prisma-backed | Prisma booking projection | PARTIALLY MIGRATED |
| `findByUser()` | Read path is Prisma-backed | Prisma booking projection | PARTIALLY MIGRATED |
| `findByVenue()` | Read path is Prisma-backed | Prisma booking projection | PARTIALLY MIGRATED |
| `findOneForRead()` | Prisma | Normalized booking projection | FULLY MIGRATED for this read |
| `findOne()` | TypeORM entity/repository | No safe default-path replacement proven for all legacy callers | TYPEORM ACTIVE |
| `findByReference()` | Read path is Prisma-backed | Prisma booking lookup | PARTIALLY MIGRATED |
| `cancel()` | `bookingRepository.save()` when flag is false | `cancelNormalized()` | PRISMA IMPLEMENTED BUT INACTIVE |
| `confirm()` | TypeORM status update and notification | No equivalent administrative approval state; normalized path refuses the action | TYPEORM ACTIVE / CONTRACT BLOCKER |
| `complete()` | Attendance method is Prisma-backed | `updateAttendance()` | PRISMA ACTIVE |
| `checkIn()` | Attendance method is Prisma-backed | `updateAttendance()` | PRISMA ACTIVE |
| `markNoShow()` | Attendance method is Prisma-backed | `updateAttendance()` | PRISMA ACTIVE |
| `getBookingStats()` | Prisma | Prisma aggregate/counts | FULLY MIGRATED |
| `getPayoutStatement()` | Prisma reporting path | Prisma payout projection | PRISMA ACTIVE |
| `getPayoutHistory()` | Prisma reporting path | Prisma payout projection | PRISMA ACTIVE |
| `generatePayoutStatementPdf()` | Uses Prisma-backed statement data | Prisma-backed input | PARTIALLY MIGRATED |

### PaymentsService

| Method/behavior | TypeORM default path | Prisma implementation | Status |
|---|---|---|---|
| `createOrder()` | TypeORM booking/payment repositories; simulated order ID | `createNormalizedOrder()` and `NormalizedRazorpayOrderService` | PRISMA IMPLEMENTED BUT INACTIVE |
| `verifyPayment()` | TypeORM payment save and booking update | `verifyNormalizedPayment()` and normalized payment service | PRISMA IMPLEMENTED BUT INACTIVE |
| `findAll()` | TypeORM `findAndCount()` | Prisma list/count projection | PRISMA IMPLEMENTED BUT INACTIVE |
| `findByUser()` | TypeORM `findAndCount()` | Prisma list/count projection | PRISMA IMPLEMENTED BUT INACTIVE |
| `findOne()` | TypeORM repository | Prisma lookup/adapter | PRISMA IMPLEMENTED BUT INACTIVE |
| `getRevenueStats()` | TypeORM query builder | Prisma aggregate/count | PRISMA IMPLEMENTED BUT INACTIVE |

## 3. Complete runtime TypeORM inventory

### `src/modules/bookings/bookings.service.ts`

- Imports `InjectRepository` and `Repository` from TypeORM.
- Injects repositories for `Booking`, `VenueService`, `Venue`, `Payment`, and `BankAccount`.
- `create()` uses the venue-service and venue repositories and the booking repository query builder.
- Legacy `cancel()` uses `findOne()` and `bookingRepository.save()` when the normalized flag is off.
- `confirm()` uses `findOne()`, `bookingRepository.save()`, and venue/service repositories for notification context.
- `findOne()` remains an entity-returning TypeORM lookup and is shared by legacy mutation paths.

### `src/modules/payments/payments.service.ts`

- Imports `InjectRepository` and `Repository` from TypeORM.
- Injects `Payment` and `Booking` repositories.
- Legacy `createOrder()` creates a simulated gateway order and persists through TypeORM.
- Legacy `verifyPayment()` verifies a signature, saves payment state, updates booking state, and loads notification context through TypeORM.
- Legacy `findAll()`, `findByUser()`, and `findOne()` use TypeORM repositories.
- Legacy `getRevenueStats()` uses `createQueryBuilder()`.

### Module/global registrations

- `src/modules/bookings/bookings.module.ts` imports `TypeOrmModule.forFeature([Booking, VenueService, Venue, Payment, BankAccount])` and exports `TypeOrmModule`.
- `src/modules/payments/payments.module.ts` imports `TypeOrmModule.forFeature([Payment, Booking])`.
- `src/app.module.ts` registers `TypeOrmModule.forRootAsync(...)`.
- `src/data-source.ts` exports the TypeORM CLI `AppDataSource`.
- `src/config/database.config.ts` provides TypeORM configuration.

## 4. API migration matrix

The controller routes are registered under the Nest global prefix `/api/v1` in the deployed application.

| Route | Controller method | Default path | Normalized path |
|---|---|---|---|
| `POST /bookings` | `BookingsController.create` | `BookingsService.create()` | `createNormalizedFromLegacy()` when flag is true |
| `GET /bookings` | `findAll` | Prisma read path | same |
| `GET /bookings/my-bookings` | `getMyBookings` | Prisma read path | same |
| `GET /bookings/venue/:venueId` | `getVenueBookings` | Prisma read path | same |
| `GET /bookings/stats` | `getStats` | Prisma stats | same |
| `GET /bookings/reference/:reference` | `findByReference` | Prisma read path | same |
| `GET /bookings/payout-history` | `payoutHistory` | Prisma reporting | same |
| `GET /bookings/:id/payout-statement` | `payoutStatement` | Prisma reporting | same |
| `GET /bookings/:id/payout-statement/download` | PDF download | Prisma-backed statement data | same |
| `GET /bookings/:id` | detail | service read path; legacy entity compatibility remains | same |
| `PATCH /bookings/:id/cancel` | `cancel` | TypeORM save | `cancelNormalized()` when flag is true |
| `PATCH /bookings/:id/confirm` | `confirm` | TypeORM status save and notification | explicit conflict when flag is true |
| `PATCH /bookings/:id/complete` | `complete` | Prisma attendance | same |
| `PATCH /bookings/:id/check-in` | `checkIn` | Prisma attendance | same |
| `PATCH /bookings/:id/no-show` | `markNoShow` | Prisma attendance | same |
| `POST /payments/create-order` | `createOrder` | TypeORM plus simulated order ID | normalized provider-order service when flag is true |
| `POST /payments/verify` | `verifyPayment` | TypeORM signature/save/update | normalized payment service when flag is true |
| `GET /payments` | `findAll` | TypeORM | Prisma when flag is true |
| `GET /payments/my-payments` | `findByUser` | TypeORM | Prisma when flag is true |
| `GET /payments/stats/revenue` | `getRevenueStats` | TypeORM query builder | Prisma aggregate when flag is true |
| `GET /payments/:id` | `findOne` | TypeORM | Prisma when flag is true |

Partner walk-in routes are already Prisma-backed in `VenuesService`; their normalized slot-locking branch must be tested together with user-booking activation before any mixed cutover.

## 5. Prisma implementation inventory

The following implementations exist in source. The first group is active on the default path; the second group is feature-gated and inactive by default.

### Prisma-active implementations

- Booking reads, statistics, payout reporting, attendance, and walk-in capacity code in `BookingsService`/`VenuesService`

### Feature-gated implementations

- `src/modules/bookings/createNormalizedFromLegacy()`
- `src/modules/bookings/normalized-booking-hold.service.ts`
- `src/modules/bookings/normalized-booking-payment.service.ts`
- `src/modules/bookings/normalized-booking-reschedule.service.ts`
- `src/modules/bookings/slot-capacity-coordinator.ts`
- `src/modules/bookings/legacy-slot-resolver.ts`
- `src/modules/bookings/normalized-booking-payment-workflow.ts`
- `src/modules/payments/normalized-razorpay-order.service.ts`
- `src/modules/payments/razorpay-order-client.ts`
- Trusted Razorpay verification/recovery helpers and their tests
- Prisma payment list/detail/revenue adapters inside `PaymentsService`
- Prisma normalized booking cancellation and normalized booking creation

Attendance, payout, reporting, and booking statistics should not be counted as inactive merely because other booking writers remain legacy.

Evidence exists for focused unit tests and local PostgreSQL concurrency tests in the repository history/current test files. This audit does not treat those tests as proof of production endpoint equivalence.

## 6. Administrative confirmation findings

`PATCH /bookings/:id/confirm` currently means a legacy administrative/partner confirmation but the legacy implementation sets the booking status to `CONFIRMED` and sends a booking notification. The normalized state machine uses `CONFIRMED` for payment-backed confirmation.

The normalized path therefore refuses this route with:

> Administrative confirmation is not a payment confirmation; use verified payment capture

This is the correct safety behavior until one of these decisions is approved:

1. Add or verify a separate administrative approval state/event while retaining payment state independently.
2. Retire the route after all clients are confirmed not to use it.
3. Preserve a narrow compatibility implementation with explicitly documented semantics and tests.

It must not be replaced by blindly setting `CONFIRMED` or by claiming Razorpay success.

## 7. Database schema compatibility

No live Supabase catalog query was executed in this audit. The following items are therefore **NOT VERIFIED** against production and remain deployment prerequisites:

- `bookings.payment_deadline`
- `payments.payment_intent_key`
- `payments.currency`
- `payments.order_status`
- Unique indexes/provider-order constraints
- Relevant triggers and booking-reference functions
- Prisma migration table/history reconciliation

The local Prisma schema and local migration files must be compared with the production catalog using read-only SQL before enabling normalized routes. Existing source code contains Prisma queries selecting the new payment fields, so a production schema missing them can cause runtime failures if those paths are activated.

Prohibited until separately approved: `prisma migrate deploy`, `db push`, `migrate resolve`, reset, or production writes.

## 8. Test coverage and missing tests

Verified from the repository state:

- Prisma generation has passed in prior work.
- NestJS build has passed in prior work.
- Focused booking/payment/attendance tests exist and have passed in prior work.
- Local PostgreSQL capacity/concurrency tests exist and have passed in prior work.

Still required for cutover evidence:

- Controller-level PostgreSQL tests for every route in the API matrix.
- Legacy request/response compatibility tests with the actual Flutter payloads.
- Administrative confirmation semantics tests.
- Payment order/verification tests against mocked Razorpay plus persisted local state.
- Walk-in versus user-booking concurrency tests after both writers use the same active path.
- Production read-only schema verification.
- Full Partner App manual regression by the project owner.

## 9. Exact remaining work

1. **P0 — Administrative confirmation decision**
   - Files: `src/modules/bookings/bookings.service.ts`, controller tests, normalized booking state/event mapping.
   - Decide approval versus payment semantics; do not change production behavior during audit.

2. **P0 — Production schema verification**
   - Files: Prisma schema and migrations only after catalog comparison.
   - Verify four new fields, indexes, defaults, and migration history read-only.

3. **P0 — Route-level integration**
   - Files: `src/modules/bookings/bookings.controller.ts`, `bookings.service.ts`, `payments.controller.ts`, `payments.service.ts`, local integration specs.
   - Execute actual controller/service workflows with disposable local PostgreSQL fixtures.

4. **P1 — Legacy fallback replacement**
   - Files: `bookings.service.ts`, `payments.service.ts`.
   - Replace `create()`, legacy cancellation, legacy confirmation only after the contract decision, legacy payment order/verification, and remaining entity-returning `findOne()` callers.

5. **P1 — Side-effect parity**
   - Preserve notifications, audit events, authorization, payout calculations, and response adapters in Prisma paths.

6. **P1 — Coordinated capacity cutover**
   - Files: `venues.service.ts`, normalized hold/payment/reschedule services, availability readers.
   - Ensure no active TypeORM writer can bypass slot locking before activation.

7. **P2 — TypeORM removal preparation**
   - Remove repository injections and module registrations only after owner testing and explicit approval.
   - Remove global TypeORM only after all unrelated entity consumers/tooling requirements are resolved.

## 10. Final TypeORM removal checklist

- [ ] Project owner has tested the full Partner App and User App flows.
- [ ] Administrative confirmation contract is resolved.
- [ ] No active controller reaches a TypeORM repository.
- [ ] `BookingsService` has no repository/DataSource/query-builder dependency.
- [ ] `PaymentsService` has no repository/query-builder dependency.
- [ ] Booking, payment, walk-in, attendance, payout, and notification regressions pass.
- [ ] Local PostgreSQL concurrency tests pass for the final writer set.
- [ ] Production schema fields/indexes are verified read-only.
- [ ] Production migrations are reviewed/applied separately if required.
- [ ] `BookingsModule` and `PaymentsModule` no longer need `TypeOrmModule.forFeature`.
- [ ] `app.module.ts` no longer needs `TypeOrmModule.forRootAsync`.
- [ ] `data-source.ts`, migration tooling, and entity files are classified before removal.
- [ ] No Flutter/API response contract changes are introduced.
- [ ] Rollback checkpoint is preserved.
- [ ] Project owner explicitly approves TypeORM removal.

## 11. Cutover readiness

**BLOCKED.**

The current application remains safe to preserve on its working default-off configuration, but final TypeORM removal/cutover is not ready because:

1. The normalized feature flag is off and legacy booking/payment routes remain authoritative.
2. `BookingsService` and `PaymentsService` still inject and execute TypeORM fallbacks.
3. Administrative confirmation has no verified normalized equivalent.
4. Production schema and migration history were not verified in this audit.
5. Full controller-level local PostgreSQL and project-owner app regression evidence is still required.

No TypeORM code, schema, environment variable, route activation, migration, or deployment was changed by this audit.

## Execution addendum — 2026-10-29

The local PostgreSQL prerequisite was checked without printing credentials:

- `TEST_DATABASE_URL`: not configured
- `TEST_DATABASE_NAME`: not configured
- `activ_capacity_test`: not reachable on `localhost:5432`
- Supabase was not used as a fallback

Therefore real PostgreSQL controller/fixture flows were not executed and are **UNVERIFIED**, not passed.

The source-level `findOne()` analysis found that the public `GET /bookings/:id` controller already calls `findOneForRead()` (Prisma). The remaining TypeORM `findOne()` is required by legacy `cancel()` and `confirm()` entity-compatible paths. It was not removed because those fallback routes remain active by default.

Administrative `confirm()` remains unresolved safely: the existing route changes booking status and emits a notification, while normalized `CONFIRMED` is payment-backed. No behavior was changed.

### Changes made during execution

- `src/modules/venues/venues.service.ts`: walk-in wall-clock times and activity-day overlap queries now use the explicit Asia/Kolkata-to-UTC policy consistently.
- `src/modules/venues/activity-slot-merge.spec.ts`: corrected the fixture to represent normalized UTC storage.

### Validation

- Prisma generation: PASS
- NestJS build: PASS
- Focused walk-in/availability tests: 8 PASS
- Full Jest run before the fixture correction: 437 PASS, 35 skipped, 15 failures. The 15 failures were test-server `listen EPERM` sandbox errors in `venues-admin-details.spec.ts` plus the now-corrected legacy-timezone fixture assertion; no migration-related assertion failure remains in the focused rerun.

TypeORM remains installed and active. The normalized feature flag remains off.

## Local PostgreSQL execution addendum — 2026-10-29

The disposable local database was verified as `activ_capacity_test` on localhost port 5432 using the local PostgreSQL user. No Supabase credentials were used for the test commands.

- A local custom-format backup was created at `.local-test-backups/activ_capacity_test-before-prisma-push.dump` before schema synchronization.
- The authorized `prisma db push --accept-data-loss` synchronized the local schema. It removed the unmanaged `booking_reference_sequences` support table, so the repository's `20261020_booking_reference` migration SQL was reapplied locally to restore the booking-reference table and function.
- The temporary `.env.local` override was removed after testing.
- Fixture cleanup left 12 estimated rows in the local database; no production data was involved.

### Actual test results

- `capacity-concurrency.integration.spec.ts`: **PASS**, 11 PostgreSQL integration scenarios executed, including concurrent walk-in claims, walk-in/user collision, idempotency, rollback, cancellation/retry, payment/expiry race, and rescheduling.
- `normalized-booking-schema.integration.spec.ts`: **24 passed, 1 failed, 4 skipped, 6 TODO**. The single failure is the intentional contract-gap assertion for missing database CHECK constraints on slot capacity counters.
- Focused normalized booking/payment/walk-in suites: **26 passed**.
- Prisma generation: **PASS**.
- NestJS build: **PASS**.

The unique-constraint inspection was corrected to include PostgreSQL unique indexes as well as `pg_constraint`; the previous false negatives are resolved. The remaining capacity CHECK constraint is a real reviewed schema blocker, not an assertion workaround.

Controller-level booking/payment flows were not claimed as passed because no dedicated controller-level PostgreSQL suite exists in the current repository and no live Razorpay calls were made. TypeORM remains installed, the normalized route flag remains off, and no production migration or deployment was performed.

## Constraint and E2E execution addendum — 2026-10-29

Added the reviewed local migration:

- `prisma/migrations/20261029030000_add_slot_capacity_checks/migration.sql`

It adds three local PostgreSQL checks:

- `capacity >= 0`
- `booked_quantity >= 0`
- `booked_quantity <= capacity`

The migration was applied only to `localhost:5432/activ_capacity_test`. Read-only verification confirmed three slot CHECK constraints, the `generate_booking_reference()` function, and ten relevant unique indexes across bookings, booking attempts, and payments.

After applying the constraint migration:

- Schema integration: **25 passed, 4 skipped, 6 TODO**.
- Capacity concurrency integration: **11 passed**.
- The previous schema failure is resolved.

There is still no dedicated controller-level PostgreSQL E2E suite in the repository. The existing tests exercise real Prisma transactions and persisted local state, but they do not justify claiming HTTP-controller coverage for booking/payment routes. Creating that suite remains the next implementation step; external Razorpay calls remain mocked and no production routes were enabled.
