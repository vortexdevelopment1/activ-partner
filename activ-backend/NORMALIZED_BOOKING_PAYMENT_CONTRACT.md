# Normalized Booking/Payment Contract Decision

Date: 2026-10-29  
Status: implementation preparation; no runtime booking or payment code changed.

## Verified schema

- `bookings` requires `slot_id`, `policy_version`, `public_code`, integer paise amounts, and `PENDING_PAYMENT` as its initial status.
- `booking_reference` is unique and database-generated.
- `booking_attempts` supports user-scoped idempotency, quantity, expiry, quote snapshots, and `HELD`, `PAYMENT_PROCESSING`, `CONSUMED`, `EXPIRED`, and `RELEASED` states.
- `slots` contains `capacity`, `booked_quantity`, and `AVAILABLE`, `BLOCKED`, and `ARCHIVED` states.
- `payments` contains provider/order/payment identifiers, amount in paise, and `CREATED`, `AUTHORIZED`, `CAPTURED`, `FAILED`, and `REFUNDED`-family states defined by the Prisma enum.

## Proposed contract

The eventual internal request must select a concrete slot:

```text
userId             server-authenticated
slotId             required UUID
quantity           positive integer, initially 1 unless product approves more
idempotencyKey     required, scoped to user
policyVersion      server-selected from an approved policy source
quote              server-created; never trusted from the client
```

The server must derive facility, venue, activity/service, price, discount, currency, and policy metadata from the selected slot and its relations. `booking_reference` remains database-generated. `public_code` still lacks an approved generator or database default and must not be fabricated in application code.

## State and capacity rules

| Object | Allowed initial/terminal states | Capacity effect |
|---|---|---|
| Booking attempt | `HELD → PAYMENT_PROCESSING → CONSUMED` | Hold reserves quantity; consumed hold must not release it |
| Booking attempt | `HELD → EXPIRED` or `HELD → RELEASED` | Release exactly once |
| Booking attempt | `PAYMENT_PROCESSING → CONSUMED` or recovery-defined failure state | Requires explicit payment reconciliation policy |
| Booking | `PENDING_PAYMENT → CONFIRMED` after authoritative payment success | Occupancy remains reserved |
| Booking | `PENDING_PAYMENT → CANCELLED` on failed/expired flow | Requires atomic occupancy release policy |
| Booking | `CONFIRMED → COMPLETED/CANCELLED/RESCHEDULED/NO_SHOW` | Existing write state machine must remain unchanged |
| Payment | `CREATED → AUTHORIZED/CAPTURED/FAILED` and approved refund transitions | Must not confirm booking before verified success |

These transitions are a contract proposal, not implemented behavior. The schema alone does not define the expiry worker, payment-race ordering, or whether `booked_quantity` represents holds, confirmed bookings, or both.

## Current blockers

1. No authoritative policy document/version source is wired to user booking creation.
2. `public_code` is required but has no verified generator/default.
3. No normalized service currently performs atomic slot reservation through `booking_attempts`.
4. No expiry/release worker exists for user booking holds.
5. No normalized Razorpay order association exists in `PaymentsService`.
6. Existing `PaymentsService` reads legacy booking fields (`totalAmount`, legacy status, legacy reference) through TypeORM.
7. Payment-success-versus-expiry reconciliation is undefined.
8. Walk-in reservations and user bookings are read together in availability code, but no shared atomic capacity mutation is established.

## Required minimal decisions before implementation

- Approve the policy source and version value.
- Approve the `public_code` format/generator, preferably as a reviewed database function/default or an explicit application contract.
- Define whether a hold increments `booked_quantity`, or whether active holds are counted separately.
- Define hold duration, expiry ownership, and payment-success-after-expiry behavior.
- Define the normalized Razorpay order/payment mapping and idempotency rules.
- Define whether and how walk-ins consume the same capacity counter.

## Final decision matrix

| Rule | Existing schema | Existing code | Migration needed | Decision |
|---|---|---|---|---|
| Policy version | `venues.policy_version` exists | Venue creation stores `v1` | No, if the venue policy is authoritative | Use the selected slot's facility → venue `policy_version`; reject missing values |
| Public code | `bookings.public_code` is required and unique | No generator found | Yes | Add a reviewed database generator/default or approved service-side generator before booking creation |
| Ten-minute hold | `expires_at` exists on attempts | No user-hold worker exists | No field migration; code required | Use 10 minutes only in the approved service/worker configuration |
| Idempotency | Unique `(user_id, idempotency_key)` exists | No reservation implementation | Code required | Reuse the existing unique constraint; return the existing active attempt for an exact retry |
| Capacity | `slots.capacity` and `booked_quantity` exist | No shared atomic mutation; walk-ins do not use the same counter | Yes for complete invariant, or a reviewed lock-based compatibility design | Count active user holds, confirmed bookings, and walk-ins exactly once |
| Payment association | Payments reference `booking_id` only | PaymentsService is legacy TypeORM | Yes for attempt/order idempotency | Add a reviewed attempt/order association or define a unique booking-order contract |
| Booking timing | Booking can reference an attempt and slot | No normalized creation path | Code required after public-code decision | Create a `PENDING_PAYMENT` booking with the hold so payment has a stable booking ID |
| Booking reference | Database default exists | No normalized writer | No | Let PostgreSQL generate it; never allocate it in application code |
| Refund/late payment | Refund model exists | No normalized reconciliation | Code and product policy required | Late capture becomes reconciliation/manual review unless capacity is still held |
| Walk-in integration | Walk-ins have separate rows | No shared atomic capacity update | Yes or explicitly serialized shared transaction | Walk-ins and user holds must use the same capacity reservation operation |

## Capacity invariant

For each slot, the single invariant is:

```text
active_quantity(holds) + confirmed_quantity(bookings) + active_quantity(walk_ins)
  <= slots.capacity
```

The implementation must choose one physical accounting strategy. The preferred strategy is a single transactional counter on `slots.booked_quantity`, incremented when a user hold or walk-in is created and decremented exactly once when that reservation is released. Queries must not add the counter to the same reservations again. A lock plus conditional update must enforce `booked_quantity + quantity <= capacity`.

If existing data or walk-in semantics make that strategy unsafe, a schema-backed reservation ledger and derived counter must be approved instead. A read-then-insert check is not sufficient.

## Executable transaction specification

For a user hold, one Prisma transaction at PostgreSQL `Serializable` isolation must:

1. Resolve the authenticated active user and selected slot.
2. Lock or conditionally update the slot only when it is `AVAILABLE` and has capacity.
3. Resolve the facility, venue, service/activity, server price, discount, and venue policy version.
4. Resolve the user's `(user_id, idempotency_key)` attempt. An exact active retry returns the existing result; a conflicting payload is rejected.
5. Create or associate the `booking_attempts` row with a ten-minute expiry and immutable quote snapshot.
6. Create the `bookings` row in `PENDING_PAYMENT` with `slot_id`, `attempt_id`, generated booking reference, and approved public code.
7. Commit before any Razorpay request.

Capacity release, expiry, payment-success claiming, and walk-in reservation must use the same slot-lock/conditional-update rule and an idempotent status transition. Razorpay calls must occur outside database transactions.

## Payment and expiry race

Payment verification must first claim the attempt/booking in a short transaction, using a conditional state transition. If the hold is already expired and capacity has been released, a late successful payment cannot confirm the booking. It must be recorded for reconciliation/refund/manual review according to the approved payment policy. If payment claims the hold first, expiry must observe the changed state and must not release capacity.

This requires a normalized payment/order association and idempotent provider-event handling; the current `payments` schema and legacy PaymentsService do not provide that complete contract.

## Minimal migration proposal — do not apply automatically

The smallest schema changes that appear necessary are:

1. Add a verified `public_code` generator/default or approve an application generator with a database uniqueness retry contract.
2. Add an explicit payment-attempt/order association and idempotency constraint, preferably `payments.attempt_id` plus a unique provider/order relationship reviewed against existing rows.
3. Add a durable capacity reservation representation if the current `booked_quantity` cannot safely include both walk-ins and user holds without double counting.
4. Add any provider-event uniqueness needed for webhook replay protection if the existing `provider_event_id` is not sufficient for all callback paths.

No migration is authorized by this document.

## Implementation slices

### Slice 1 — contract and test harness

- Inputs: approved slot, user, idempotency key, policy and price decisions.
- Outputs: fixtures and real-PostgreSQL transaction harness only.
- Files: booking test utilities and contract tests; no production route.
- Tests: enum transitions, uniqueness, rollback, and isolated database setup.
- Prerequisites: none beyond an approved test database.

### Slice 2 — schema-backed hold service

- Inputs: selected slot and authenticated user.
- Outputs: idempotent held attempt plus pending booking.
- Prerequisites: public-code and capacity strategy approval; any required migration applied separately.
- Tests: last-capacity concurrency, duplicate requests, blocked/expired slots, rollback.

### Slice 3 — expiry/reconciliation

- Inputs: expired attempts and provider state.
- Outputs: exactly-once release or reconciliation state.
- Prerequisites: payment race policy and worker ownership.

### Slice 4 — normalized payment adapter

- Inputs: pending booking/attempt.
- Outputs: idempotent Razorpay order and verified capture transition.
- Prerequisites: payment association migration/contract; no external call inside transaction.

### Slice 5 — controlled rollout

- Keep legacy routes unchanged.
- Expose a versioned endpoint only after all real PostgreSQL concurrency and payment tests pass.
- Migrate clients deliberately, then retire TypeORM booking/payment paths separately.

## First independently executable step

Implement Slice 1 only: a real-PostgreSQL integration harness and contract-level tests that prove the currently declared constraints and expose the missing public-code, capacity, and payment-association guarantees. Do not add a live reservation service until those tests and the schema decisions pass review.

## Implementation gate

No public endpoint, internal reservation service, schema change, migration, payment rewrite, pool change, or TypeORM removal should proceed until the decisions above are approved and covered by real PostgreSQL concurrency tests. The legacy `POST /bookings` and existing payment routes remain unchanged.

## Validation required after approval

- Concurrent requests competing for final capacity.
- Duplicate user/idempotency-key requests.
- Hold expiry and exactly-once release.
- Payment verification racing expiry.
- Duplicate payment callbacks and retry behavior.
- Walk-in/user capacity collision.
- Booking-reference/public-code uniqueness.
- Transaction rollback and restart recovery.
