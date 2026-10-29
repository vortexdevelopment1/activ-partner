# ACTIV Partner App — Codex Deep Performance Investigation

Date: 2026-10-28  
Scope: `activ-partner/activ-frontend` and `activ-partner/activ-backend`  
Mode: read-only static investigation. No source, schema, migration, API contract, database record, package, or environment was changed.

The existing `ACTIV_PARTNER_COMPLETE_PERFORMANCE_AUDIT.md` was read first and used as an investigation lead. Its findings were rechecked against current source. No live authenticated runtime, production network trace, Prisma timing log, or hosting dashboard was available, so no latency number below is presented as measured.

## 1. Executive Summary

The strongest code-proven performance issue is repeated broad data loading across navigation boundaries. Home, activity list, management, and Add Activity screens each own local state and commonly reload after returning from a child route. The same venue/activity data is therefore fetched and decoded again rather than being reused or refreshed selectively.

The most important backend risk is response/query breadth. Venue and activity management responses combine service metadata, images, amenities, answers, availability, bookings, walk-ins, payment information, and aggregates. This increases database work, JSON serialization, transfer, and Flutter parsing cost. It is a code-level risk; actual duration requires profiling.

The most important request-policy risk is inconsistency: `ActivitySetupApi` has centralized timeout/401 handling, while many screens issue direct `http` calls. This makes retry, cancellation, authentication expiry, and loader behavior inconsistent.

The audit inventory found 121 Dart files, 106 static HTTP/request call sites, 301 loader/loading-state references, and 286 static Prisma operation call sites. These are inventory counts, not runtime request counts.

### Totals

- Confirmed code-level performance defects/inefficiencies: 9
- Suspected runtime risks requiring measurement: 12
- Highest-priority bottlenecks: repeated broad venue fetches; activity-management query/payload breadth; Add Activity request waterfall; inconsistent direct HTTP/auth policy; image/PDF transfer and decode cost.
- Most affected screens: Home, Venue Activity List, Activity Management, Add Activity, Direct Book Slot, Manage Slots, Bookings, Profile/document/PDF screens.
- APIs requiring runtime profiling: `/venues/my-approved-venues`, `/venues/activities/:id`, activity management, availability, walk-in slots, bookings, profile/auth, payout/history.
- Recommended first implementation phase: instrumentation only, followed by request deduplication/cache and payload/query projection work.

## 2. Screen-by-Screen Audit

| Screen / flow | First-open APIs/work | Return/rebuild behavior | Cache/loading assessment | Severity |
|---|---|---|---|---|
| Splash/AuthWrapper/login/OTP/password reset | Session/token, auth, profile/OTP requests depending route | Redirects can recreate protected screens and repeat initialization | No shared request cache proven; auth loop not proven | P1 suspected |
| HomeScreen | `_fetchVenueName`, `_loadUserPermissions`, `_loadProfilePhoto`; dashboard load follows venue fetch | `_openSetup` always calls `_fetchVenueName` after child route | Local state only; confirmed parent refresh | P1 confirmed |
| VenueActivityListScreen | `fetchActivities` calls `/venues/my-approved-venues` | Called again after activity/result child returns | Full venue response decoded into every card; no cache | P1 confirmed |
| ActivityManagementScreen | `_load` activity management detail; slot/bookings/images actions as opened | `_save` reloads after mutation; `_slots` reloads after Manage Slots returns | Local `_data`; no resource cache | P1 confirmed |
| AddListActivityTypeScreen | Categories/activity selection and local draft state | Resume can rebuild route chain | Catalog cache not proven | P2 suspected |
| AddSelectedVenueFormScreen | Activity detail and questions; answer/file requests | Forward navigation to amenities; edit route creates a new form | Questions/detail are not shared with review | P1 confirmed |
| AddActivityAmenitiesScreen | Amenities catalog then activity detail, sequentially | Save pushes timing; revisiting repeats both calls | Catalog is static but uncached | P2 confirmed |
| AddVenueTimingScreen | Local draft/checkpoint; activity read before forwarding | Restores draft/checkpoint and writes checkpoints on state changes | Local draft only; no server cache | P2 confirmed |
| AddActivityConfigureScreen | Activity detail and questions; images from detail | Edit buttons open earlier screens; configure itself may be recreated | Review state partly in memory, activity data reloaded | P1 confirmed |
| AddActivitySubmitReviewScreen | Activity detail on `initState` | Submit performs sequential read/availability/submit; result loads activity again | No shared review snapshot | P1 confirmed |
| AddActivitySubmissionResultScreen | Activity detail/result data; draft resume reads local storage | Continue editing creates a new previous route | No persistent server cache | P2 confirmed |
| Photo list/upload/edit | Activity detail, upload/delete endpoints and image picker | Image list can be reloaded after actions | Remote images, no consistent thumbnail policy | P2 confirmed |
| DirectBookSlotScreen | Slot availability request; date/court changes reload slots | Rapid date changes are generation-guarded, but requests are not cancelled | Live slots correctly remain uncached; retry policy is special-cased | P1 suspected |
| ManageSlotsScreen | Venue/activity availability read and update | Parent management reloads after return | Draft local state; availability must remain live after mutation | P1 confirmed |
| ActivityDetailsScreen | Activity/venue details and timing display | Reopened from navigation; local model recreated | Live availability and booking status must not be long cached | P2 suspected |
| ManageBookingsScreen | Booking list/detail/action APIs | Mutations trigger reloads; pagination needs verification | No persistent cache proven | P1 suspected |
| NotificationsScreen | Notification list/read APIs | Revisit likely refetches | Static read state not cached | P2 suspected |
| Profile/Venue/owner/info screens | Profile/venue/document/image APIs | Returning from editors reloads profile/venue | Profile metadata cache not proven | P2 suspected |
| Bank/KYC/document/PDF screens | Bank, documents, legal/PDF/image requests | Large documents can be downloaded repeatedly | No file/image cache policy proven | P2 confirmed |
| ManageTeam/team invitations | Team list and mutation APIs | Refresh after mutation; route revisit reloads | No cache | P2 confirmed |
| Partner Agreement/legal/help/settings | Legal/FAQ/preferences/support APIs | Revisit likely reloads content | Static content cache not proven | P3 suspected |

### Exact confirmed examples

1. `HomeScreen.initState` starts three independent async operations at lines 121–123. `_fetchVenueName` then starts dashboard work at lines 151–180. `_openSetup` refetches the venue at lines 375–377 after every child route.
2. `VenueActivityListScreen.fetchActivities` starts a broad approved-venues request at lines 49–68, transforms all venues/services at lines 71–130, and calls `fetchActivities` again after child navigation at lines 558–571.
3. `ActivityManagementScreen._save` reloads after every non-delete mutation at lines 180–188; `_slots` reloads management data after Manage Slots returns at lines 319–333.
4. `AddActivityAmenitiesScreen._fetchAmenities` calls catalog then activity sequentially at lines 57–65.
5. `AddActivitySubmitReviewScreen._loadActivitySummary` fetches activity detail at lines 41–52; submit then enters another multi-request sequence.

## 3. API-to-Database Trace

| Flutter trigger | API family | Controller/service path | Prisma / external work | Finding |
|---|---|---|---|---|
| Home open / activity list | `/venues/my-approved-venues` | `venues.controller.ts` → venue service list methods | Venue, service, category, images, amenities, availability, answers and summary reads | Broad response reused for unrelated screens; profile/dashboard and activity list repeat calls |
| Activity detail/review | `/venues/activities/:serviceId` | `getActivityDetail` | Owned activity + venue detail/answers/availability mapping | Combined response is larger than the review card needs |
| Activity management | management endpoint | `getActivityManagement` | Service, answers, bookings, walk-ins, availability, payment modes, aggregates | Highest query/payload breadth; profile with timing required |
| Questions | `/venues/activities/:id/questions` | `getActivityQuestions` | Category question query plus saved answers | Separate from activity detail; can be deduplicated per activity/category |
| Answers | answer POST | `saveActivityAnswers` | Upsert/find/update/create answer rows | Later screens refetch complete detail |
| Amenities | amenities catalog + activity amenities | amenities service + `setActivityAmenities` | Catalog query and activity relation update | Catalog is cacheable; current selection is activity-scoped |
| Availability | `/venues/:venueId/availability` | `setAvailability` / `availabilityRows` | Ownership reads, delete/createMany, duration update transaction | Write is broad and invalidates availability; no latency evidence |
| Walk-in slots | `/venues/:venueId/activities/:id/slots` | walk-in slot service | Availability, facility slots, bookings, walk-ins, overlap/status mapping | Correctly time-sensitive; needs query and response timing |
| Walk-in reservation | walk-in POST | reservation service | Conflict checks, bookings/walk-ins, transaction | Never retry blindly; request must remain non-idempotent unless server key exists |
| Bookings/history | booking endpoints | bookings service | Booking, slot, payment, user relations and aggregates | Pagination and select breadth require runtime/API verification |
| Auth/profile | auth/users/partners | auth and user services | JWT/session/profile lookups, possible external OTP provider | Direct and wrapper clients differ in policy |
| Images | Cloudinary/profile/document routes | cloudinary/upload services | External storage/network dependency | Transformation and byte size need measurement |

### Request-policy findings

- `ActivitySetupApi._request` has a 30-second timeout and centralized 401/error mapping.
- `HomeScreen` uses direct HTTP with a 15-second timeout for venue fetch and a direct pause request without an explicit timeout in the shown path.
- `DirectBookSlotScreen` uses a 15-second slot request and retries a 5xx availability GET once. The generation token prevents stale UI application, but it does not cancel the earlier network request.
- No runtime evidence proves an uncontrolled retry loop. A request ID and retry counter are required to verify this.

## 4. Circular Loader Findings

Static inspection classifies the main loader paths as follows:

| Loader | Location | Classification | Reason |
|---|---|---|---|
| Home dashboard flags | `HomeScreen.dart` | Potential defect | Multiple independent async operations update shared UI; runtime failure ordering not measured |
| Activity list `isLoading` | `VenueActivityListScreen.dart:49-53` | Safe in inspected path | Error/final cleanup exists; repeated route refresh is inefficient |
| Management `_saving` | `ActivityManagementScreen.dart:180-195` | Safe in inspected path | `finally` resets when mounted; request policy still varies |
| Amenities `_loading` | `AddActivityAmenitiesScreen.dart:57-76` | Safe in inspected path | `finally` resets and error state is shown |
| Review `_saving` | `AddActivitySubmitReviewScreen.dart` | Potential defect | Sequential submit and navigation require runtime interruption testing |
| Direct slots `_loadingSlots` | `DirectBookSlotScreen.dart:135-193` | Safe in inspected path | generation guard plus `finally`; old requests still consume network |
| PDF/document loading | PDF/document screens | Potential defect | Large download/render and disposal behavior require runtime trace |

No source-proven infinite loader was identified. The 301-reference inventory is not a defect count.

## 5. Duplicate API Request Findings

- **D-001:** Home refetches approved venues after every setup child route (`HomeScreen.dart:375-377`). Confirmed duplicate-prone behavior.
- **D-002:** Activity list refetches approved venues after every activity child route (`VenueActivityListScreen.dart:558-571`). Confirmed.
- **D-003:** Activity management reloads after save and again after slot-management return (`ActivityManagementScreen.dart:180-188, 319-333`). Confirmed.
- **D-004:** Amenities loads catalog and activity sequentially on every entry (`AddActivityAmenitiesScreen.dart:57-65`). Confirmed; catalog request is cacheable.
- **D-005:** Review and result screens independently fetch activity detail (`AddActivitySubmitReviewScreen.dart:41-52`; result screen loader). Confirmed.
- **D-006:** Add Activity checkpoint restoration can reconstruct screens whose `initState` repeats API calls. Confirmed route behavior; exact duplicate count depends on restoration state.

## 6. Navigation Performance Findings

`ActivityResumeNavigator`, `activity_flow_checkpoint.dart`, and the Add Activity screens preserve state through local checkpoint data, but restoration can create a new route rather than reusing a mounted route. This is functionally useful but performance-expensive: each recreated screen runs its initialization and may reload activity/questions/catalog data.

The current behavior should not be replaced with a destructive stack reset. A future implementation should return typed results from child editors, retain the checkpoint behavior, and refresh only the changed resource. Back navigation must remain covered by the existing activity flow tests.

## 7. Backend and Supabase Findings

### Confirmed code risks

- `getActivityManagement` is a large orchestration method with independent booking, walk-in, availability, payment, and aggregate work. It should be timed by stage before any refactor.
- Venue list/detail methods return nested service/category/image/amenity/answer/availability data. Projection-specific selects are likely to reduce transfer and serialization.
- Booking and walk-in views contain time-range and relation filters; query plans and indexes must be checked with authorized read-only `EXPLAIN` in a non-production or approved environment.
- Pagination is not proven for every booking, payout, notification, and activity-history response. This must be checked against actual controller DTOs and response sizes.

### Unverified deployment risks

- Supabase/backend region mismatch.
- Connection pool exhaustion or connection acquisition time.
- Cold starts or hosting plan limits.
- External Cloudinary/MSG91/Gmail latency.

No hosting or Supabase metrics were available; these are not confirmed bottlenecks.

## 8. Image and Rendering Findings

- Activity/photo/review paths use remote image URLs and fixed display boxes, but thumbnail transformation and decode-size hints are not consistently enforced.
- Full image lists can be rendered in review/edit flows; original Cloudinary dimensions and bytes were not measured.
- PDF preview can perform large download/render work on the UI-facing path; runtime memory and raster timing are unknown.
- Nested lists and shrink-wrapped grids appear in onboarding/management flows. Exact frame cost requires Flutter DevTools.
- JSON mapping is performed on the UI isolate. Current payload size and parsing duration are not measured.

## 9. Confirmed Issues vs Unverified Hypotheses

### Confirmed from source

1. Parent screens refetch after child navigation.
2. Add Activity steps issue separate, repeated resource reads.
3. Management/detail payloads aggregate broad data sets.
4. Direct HTTP and wrapper clients have different timeout/error policies.
5. Static catalogs have no visible shared cache.
6. Walk-in slot/date requests are live and not cacheable, but old requests are not cancelled.
7. Image/PDF code lacks a globally enforced thumbnail/decode/cache policy.
8. Several histories require pagination verification.
9. Add Activity route restoration can recreate screens and initialization work.

### Unverified until runtime measurement

1. Any endpoint exceeding a specific latency threshold.
2. Any infinite loader.
3. N+1 query behavior in a production-sized dataset.
4. Supabase region/connection pool bottlenecks.
5. Cloudinary byte/decode cost.
6. Actual Flutter frame drops or memory pressure.
7. JWT refresh loops or simultaneous refresh races.

## 10. Prioritized Issues

### P1-001 — Repeated broad venue fetches

- Affected: Home, Activity List, activity return navigation.
- Files/lines: `HomeScreen.dart:151-180, 375-377`; `VenueActivityListScreen.dart:49-68, 558-571`.
- Root cause: parent state is discarded/refreshed after navigation.
- Evidence: direct calls and explicit post-navigation refreshes.
- Recommendation: repository cache with stale-while-revalidate for metadata; selective invalidation after mutations.
- Expected improvement: fewer requests, faster warm navigation; no numeric claim until profiled.
- Risk: stale activity status if invalidation is incomplete.
- Verification: request-count and warm-navigation benchmark.

### P1-002 — Activity management query/payload breadth

- Affected: Activity Management and detail.
- Files: `activ-backend/src/modules/venues/venues.service.ts` (`getActivityManagement`, `getActivityDetail`).
- Root cause: display data and aggregates are assembled together.
- Evidence: service, answers, bookings, walk-ins, availability, payment and summary operations in one management path.
- Recommendation: measured stage parallelization and endpoint-specific Prisma projections/pagination.
- Risk: API compatibility and authorization regressions.
- Verification: Prisma query count/time, response bytes, controller timing.

### P1-003 — Add Activity request waterfall

- Affected: details, amenities, configure, review, result.
- Files: `AddActivityAmenitiesScreen.dart:57-76`; `AddActivitySubmitReviewScreen.dart:41-52`; `ActivitySetupApi.submit`.
- Root cause: independent screen-local loads and sequential submit operations.
- Recommendation: share activity/questions/catalog state; reuse submit response; invalidate only changed resources.
- Risk: stale review data.
- Verification: route/API timeline and mutation consistency tests.

### P1-004 — Inconsistent request/auth policy

- Affected: Home, direct booking, profile and all direct HTTP callers.
- Files: `ActivitySetupApi.dart`; `HomeScreen.dart:156-159, 383-404`; `DirectBookSlotScreen.dart:125-132`.
- Root cause: wrapper and direct clients differ in timeout, 401, retry and cancellation policy.
- Recommendation: one bounded request layer with correlation IDs and auth coordination.
- Risk: changed expiry behavior.
- Verification: forced timeout/401 tests and retry count.

### P1-005 — Live slot request churn

- Affected: Direct Book Slot.
- Files: `DirectBookSlotScreen.dart:135-193`.
- Root cause: date changes issue requests; generation prevents stale UI but does not abort network work.
- Recommendation: cancellable request client or debounce date changes; never cache occupancy/reservation state long-term.
- Risk: stale slot display if invalidation is wrong.
- Verification: rapid date-switch trace and server request count.

### P2-001 — Static catalog/cache gap

- Affected: amenities, categories, legal/FAQ/settings.
- Evidence: `AddActivityAmenitiesScreen.dart:57-65` fetches catalog on entry.
- Recommendation: TTL cache with explicit invalidation.

### P2-002 — Image/PDF transfer and decoding

- Affected: photo/review/profile/document screens.
- Recommendation: Cloudinary thumbnails, decode sizing, lazy PDF rendering.

### P2-003 — History pagination uncertainty

- Affected: bookings, payouts, notifications.
- Recommendation: verify API pagination and response limits before implementation.

### P2-004 — Loader state complexity

- Affected: all async screens.
- Recommendation: state-machine-like operation ownership, exhaustive disposal/error tests.

## 11. Proposed Fix Plan

### Phase 1 — Safe instrumentation only

- Add request IDs/timestamps in the shared HTTP layer and server request interceptor.
- Capture route open, first content, usable state, loader start/end, response bytes, status, retry count.
- Redact JWTs, phone numbers, names, emails, booking IDs and document URLs.

### Phase 2 — Repository and request deduplication

- Files: `ActivitySetupApi.dart`, Home, Activity List, Management, Add Activity screens.
- Add in-memory request coalescing and TTL metadata cache.
- Keep availability, slot occupancy, reservations, payment status, and live financial values uncached or very short-lived.

### Phase 3 — Backend projection/query work

- Files: `venues.controller.ts`, `venues.service.ts`, booking/payout/notification services.
- Measure first; then reduce Prisma selects/includes, parallelize independent reads, and paginate histories.
- Do not add indexes until read-only query plans justify them.

### Phase 4 — Images/rendering

- Centralize Cloudinary transformations, use display-size decode hints, lazy-load large images/PDFs, and profile low-end devices.

## 12. Before/After Benchmark Plan

Capture cold and warm runs for Home, Activity List, Management, Add Activity, Direct Book Slot, Manage Slots, Bookings, Profile and PDF preview.

For each run record:

- time to route transition;
- time to first visible content;
- time to usable state;
- endpoint count, duration, status, retry count and bytes;
- controller and Prisma stage durations;
- loader duration;
- Flutter build/raster time, image decode time and memory;
- cold versus warm behavior;
- rapid back/navigation and rapid date-switch behavior.

Suggested targets for later validation: immediate transition feedback, cached metadata visible under 500 ms where feasible, common API p95 under 1 second in the deployed region, no uncontrolled retries/loaders, and zero avoidable duplicate requests. These are targets, not current measurements.

## Final Confirmation

1. Total confirmed defects/inefficiencies: **9**.
2. Total suspected runtime risks: **12**.
3. Five highest-priority bottlenecks: repeated venue fetches; broad activity management queries/payloads; Add Activity waterfall; inconsistent HTTP/auth policy; image/PDF transfer and decoding.
4. Most affected screens: Home, Activity List, Activity Management, Add Activity, Direct Book Slot, Manage Slots, Bookings, Profile/documents.
5. APIs requiring profiling: approved venues, activity detail/management, availability, walk-in slots, bookings, auth/profile, payout/history.
6. Recommended first implementation phase: instrumentation-only measurement, then request/cache and payload/query work.
7. **No application code, database, schema, migration, API contract, package, or environment was modified during this investigation.**
