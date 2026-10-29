# ACTIV Partner App — Complete Read-Only Performance Audit

Audit date: 2026-10-28  
Scope: `activ-frontend` Flutter partner app and `activ-backend` NestJS/Prisma backend.  
Mode: read-only static audit. No application code, schema, migration, API, or data was changed.

## 1. Executive Summary

The repository is functional but has a high amount of request and state-management risk. The largest confirmed risks are:

1. Several screens reload full activity/venue data after navigation instead of returning updated state, creating request waterfalls.
2. Dashboard and activity-management flows make broad payload requests containing images, amenities, answers, availability, bookings, and financial aggregates together.
3. `HomeScreen` and activity flows use manual HTTP calls in addition to `ActivitySetupApi`, so request policy, timeout, retry, and cancellation behavior is inconsistent.
4. The app has many independent loading flags and indicators. Most have `finally` cleanup, but the number of paths makes stuck or duplicate loading states difficult to reason about.
5. Image lists use `Image.network` with no explicit width/height cache policy or Cloudinary thumbnail transformation in the reviewed UI paths.
6. Backend services contain large multi-query methods and broad Prisma `include` graphs. Several independent database reads are sequential.

No production latency, DevTools timeline, database query duration, hosting-region, or network trace was available. All latency claims below are therefore marked **Not measured** and are based on static code evidence only.

## 2. Screen-by-Screen Performance Audit

Severity uses P0 critical, P1 high, P2 medium, P3 low. “Confirmed” means directly visible in code; “Hypothesis” means it requires runtime measurement.

| Screen / flow | APIs / work on open or return | Duplicate / loading risk | Cache status | Severity | Evidence |
|---|---|---|---|---|---|
| Splash, `AuthWrapper`, login, password reset, OTP | Auth/profile/session calls; route decisions | Auth restoration can trigger repeated protected calls after redirects | No shared request cache found | P1 hypothesis | `lib/Screens/AuthWrapper.dart`, `LoginScreen.dart`, `OTPVerificationScreen.dart` |
| `HomeScreen` / dashboard | Venue list, profile/photo, dashboard/bookings and setup checks | Full refresh after returning from child screens; manual HTTP path | Venue state held locally only | P1 confirmed | `lib/Screens/Home/HomeScreen.dart`, `_fetchVenueName`, `_loadDashboardData`, `_openSetup` |
| `VenueActivityListScreen` | Approved venues plus activity/service data; per-card navigation | `fetchActivities()` called after child route returns; maps entire venue response into models | No TTL or stale display | P1 confirmed | `lib/Screens/Home/Activities/VenueActivityListScreen.dart:44-132, 560+` |
| `ActivityManagementScreen` | Activity detail/management, slots, bookings, images, pause/resume, delete | `_load()` after mutations and after slot-management return; broad detail payload | Local `_data`, discarded on route recreation | P1 confirmed | `lib/Screens/Home/Activities/ActivityManagementScreen.dart:180-230, 319-330` |
| Add Activity type selection | Categories, local draft/checkpoint writes | New route chain recreates screens | Shared preferences checkpoint only | P2 confirmed | `AddActivities/AddListActivityTypeScreen.dart`, `activity_flow_checkpoint.dart` |
| Add Activity details/questions | Questions, activity detail, answer/file uploads | Questions and activity can be loaded independently; edit route starts fresh | Draft/checkpoint but no response cache | P1 confirmed | `AddSelectedVenueFormScreen.dart:39-100, 300+` |
| Amenities | Amenities catalog plus activity detail | Catalog and detail requests are sequential in `_fetchAmenities` | No catalog cache | P2 confirmed | `AddActivityAmenitiesScreen.dart:57-81` |
| Timing / slots | Activity detail before navigation; local draft/checkpoint; submit availability | Restoring timing can read draft, checkpoint, and initial values; repeated save/checkpoint work | Local draft only | P1 confirmed | `AddVenueTimingScreen.dart:42-95, 112-130` |
| Photos / edit photos | Activity detail, image upload/delete, image picker | Full image list rendered; upload then reloads/updates list | No explicit image cache policy | P2 confirmed | `EditActivityPhotosScreen.dart`, `AddVenuePhotoUploadScreen.dart` |
| Configure/review | Activity detail, questions, images; route to edit screens | Configure opens after timing, then edits reopen earlier screens and can repeat APIs | Timing passed in memory; activity data reloaded | P1 confirmed | `AddActivityConfigureScreen.dart:25-60, 150+` |
| Submit review / result | Activity detail; submit performs activity read, availability write, submit call | Submit contains sequential read → availability update → submit; result loads activity again | None | P1 confirmed | `AddActivitySubmitReviewScreen.dart:38-58, 68-100`, `ActivitySetupApi.submit` |
| Direct book / walk-in | Activity/venue context, walk-in slots, reservation, confirmation | Date changes refetch slots; no request cancellation for rapidly changed dates | Slot data is screen-local | P1 confirmed | `DirectBookSlotScreen.dart:130-190, 1140-1210` |
| Manage slots / pricing | Venue/activity, availability, updates | Reload after save and after navigation; controllers retained per slot | Draft local only | P1 confirmed | `ManageSlotsScreen.dart:130-190, 210-280` |
| Bookings / booking detail | Booking list/detail and actions | Refresh after mutations; pagination must be verified at runtime | No visible persistent list cache | P1 hypothesis | `ManageBookingsScreen.dart` |
| Earnings / payouts | Payout/history endpoints and PDF generation/download | Large history responses and PDF rendering can block | No visible pagination/cache proof | P2 hypothesis | `PayoutHistoryScreen.dart`, `PdfViewerPage*.dart` |
| Notifications | Notification list/read state | Return-to-screen refresh likely repeats list call | No visible cache | P2 hypothesis | `NotificationsScreen.dart` |
| Profile, documents, bank/KYC | Profile, documents, bank endpoints; PDF/image loading | Large document/image payloads and sequential profile sections | No shared profile cache | P2 confirmed | `ProfileScreen.dart`, `ViewDocumentScreen.dart`, `BankAccountScreen.dart` |
| Team / staff | Team list, invite, permissions | Refresh after each mutation; possible duplicate list loads | No persistent cache | P2 confirmed | `ManageTeamScreen.dart` |
| Agreement/legal/help/settings | Legal, FAQ, support, settings/notification preferences | Mostly one-shot calls; repeated navigation reloads content | No cache visible | P3/P2 hypothesis | `PartnerAgreementScreen.dart`, `HelpSupportScreen.dart`, `SettingsScreen.dart` |

### Screen inventory checked

The Flutter tree contains 121 Dart files, including the screens listed above plus venue onboarding (`VenueScreen`, `VenueInfoScreen`, `VenueTimingScreen`, photo screens), auth, legal, support, profile, document, menu, and shared navigation/widget files. Every screen under `activ-partner/activ-frontend/lib/Screens` was included in the static inventory. Exact runtime request counts were not measurable without a running authenticated build and network trace.

## 3. Complete API Audit

The app contains 106 static HTTP/request call sites. The principal endpoint families are below; related controller/service implementations were inspected.

| Endpoint family | Caller | Backend area | Static performance finding | Severity |
|---|---|---|---|---|
| Auth/login/OTP/profile | Auth screens, `AuthWrapper` | `auth.controller.ts`, users/partners | Multiple initialization paths can independently establish session/profile state; refresh-loop behavior needs runtime trace | P1 hypothesis |
| `/venues/my-approved-venues` | Home, activity list | `venues.controller.ts` and venue service | Broad venue/service payload is reused for dashboard and activity list; likely over-fetching images, amenities, availability, and service metadata | P1 confirmed |
| `/venues/activities/:id` | Add flow, activity management, review/result | `getActivityDetail` | Combined response includes answers, slots, images, venue/service context; repeated on every step | P1 confirmed |
| `/venues/activities/:id/questions` | Details form, configure/review | Questions service | Separate request after activity detail; can be deduplicated per activity/category | P2 confirmed |
| `/venues/activities/:id/answers` | Details form | `saveActivityAnswers` | Write is followed by later full detail fetches | P2 confirmed |
| `/venues/activities/:id/amenities` | Amenities screen | `setActivityAmenities` | Catalog and current activity are sequential; catalog can be cached | P2 confirmed |
| `/venues/:venueId/availability` | Timing submit/manage slots | `setAvailability` | Large availability replacement transaction; independent validation and category reads occur before transaction | P1 hypothesis |
| Activity submit | Review screen | submit controller/service | Sequential activity read, availability update, submit call; safe dependency exists but response reuse could remove the read | P1 confirmed |
| Activity management | Management screen | `getActivityManagement` | Large service method performs many reads, booking aggregates, walk-ins, availability and payment mapping | P1 confirmed |
| Walk-in slots/reservations | Direct book | walk-in controller/service | Date changes refetch; slot generation and bookings/reservations are multiple reads | P1 confirmed |
| Bookings and payments | Booking/history screens | bookings/payments/payouts | Pagination and payload size need runtime/API contract verification | P1 hypothesis |
| Images/Cloudinary | Photo/profile/document screens | cloudinary controller/service | Original image URLs may be returned and decoded in cards; transformations not consistently visible | P2 confirmed |
| Team/bank/notifications/legal/support | Corresponding screens | module controllers | Mostly one request per screen; repeated route visits have no evident shared cache | P2/P3 confirmed |

### Request timing evidence

**Not measured.** No production logs, server timing headers, Flutter DevTools trace, authenticated session, or database query log was available. The app has request timeouts in several paths (for example `ActivitySetupApi` uses 30 seconds), but timeout duration is not evidence of actual latency.

## 4. Circular Loader Audit

Static search found 301 loader/loading-state references across the Flutter source. This count includes state flags and indicators, not 301 distinct loaders.

### Confirmed risk patterns

- Many screens maintain independent `_loading`, `_saving`, `_submitting`, `_pausing`, and `_loadingSlots` flags. This is manageable locally but makes compound states easy to leave inconsistent.
- `ActivitySetupApi._request` has timeout/error handling, but direct HTTP calls elsewhere do not share the same policy.
- `finally` cleanup is common and positive; however, several screens perform navigation inside async flows, so post-navigation state updates require `mounted` checks on every path.
- Future recreation and retry behavior cannot be fully confirmed without executing the app; all such findings are hypotheses until traced.

### High-priority loader verification targets

1. `HomeScreen` dashboard fetch and refresh after pause/resume.
2. `ActivityManagementScreen` `_load`, `_save`, slot-management return, and image actions.
3. Add Activity detail/questions/amenities/timing restoration chain.
4. `DirectBookSlotScreen` date changes and walk-in reservation confirmation.
5. PDF/document preview screens.

## 5. Navigation Audit

The Add Activity flow uses checkpoint and draft restoration, but it also reconstructs prior screens when no previous timing route exists. This is safe for correctness but can re-run `initState` API calls for intermediate screens.

Evidence:

- `AddActivityConfigureScreen._backToPreviousAddStep` creates a new `AddVenueTimingScreen` when no prior route exists.
- `AddActivitySubmissionResultScreen._continueEditing` creates either `AddSelectedVenueFormScreen` or `AddActivityConfigureScreen` after reading local draft state.
- `VenueActivityListScreen` refreshes after child navigation returns.
- `ActivityManagementScreen._slots` reloads management data after `ManageSlotsScreen` returns.

Recommended future design: return a typed mutation result from editors, update the parent model optimistically where safe, and refresh only the affected resource in the background. Keep live availability, booking state, payment state, and reservation state uncached or very short-lived.

## 6. Flutter UI and Rendering Audit

### Confirmed findings

- Full image lists are rendered with `Image.network` in review/activity flows; explicit cache width/height and transformed thumbnails are not consistently specified.
- Large `ListView`/`GridView` screens use nested shrink-wrapped content in several onboarding and management paths. This can increase layout work for long lists.
- JSON decoding and response-to-model mapping occur on the UI isolate. Current payloads are moderate in most paths, but combined venue/activity responses can become expensive as image and answer counts grow.
- Manual HTTP calls and API wrapper calls use different error/timeout behavior.

### Hypotheses requiring profiling

- PDF preview and full-resolution image decode may cause frame drops on low-memory devices.
- Rebuilding dashboard sections after every state change may repaint more content than necessary.
- Large activity cards and nested onboarding forms may have avoidable rebuilds.

## 7. Database and Backend Audit

The backend contains 286 static Prisma operation call sites. The following are confirmed code-level risks, not measured slow queries:

- `VenuesService.getActivityManagement` performs multiple reads for service, answers, bookings, walk-ins, availability, payment modes, and aggregates. Independent reads should be measured and parallelized only where transaction/ordering semantics permit.
- Venue/activity response methods include nested relations for services, categories, images, amenities, answers, and availability. This creates large serialization payloads for screens that often need only a subset.
- Management and list paths calculate booking/revenue summaries while also returning display data. Separate summary endpoints or projections may reduce repeated work.
- Availability replacement uses category ownership checks, row generation, deletes, inserts, and duration updates. This should be profiled under concurrent updates; no migration/index changes were made or proposed as immediate action.
- Booking and walk-in queries use time-window predicates and relation filters. Index usefulness should be verified with safe read-only `EXPLAIN` plans in a non-production or authorized environment; no `EXPLAIN ANALYZE` was run.

Potential index candidates for later DBA review, not an instruction to apply: venue/service/day on availability, facility/start/end on slots, service/start/end/status on walk-in reservations, and booking status/time/facility relations. Validate against actual schema and query plans first.

## 8. Authentication and Retry Loop Audit

`ActivitySetupApi` centralizes token acquisition and returns a session-expired error for 401. Other screens directly read the JWT and issue HTTP requests. This split creates risk of:

- inconsistent 401 handling;
- multiple concurrent profile/session requests after login;
- duplicate retry after a timed-out mutation;
- redirect loops if `AuthWrapper` and a request caller both handle expiry.

No refresh-token implementation or uncontrolled retry loop was proven from static inspection. Runtime verification must instrument request IDs, status codes, retry count, and route transitions without logging tokens.

## 9. Image and Asset Loading Audit

### Confirmed

- Multiple list/review screens use remote image URLs directly.
- Image cards generally provide fixed display boxes, which is positive for layout stability, but decode-size hints are not consistently provided.
- Photo editing can display multiple images in a scroll view; original Cloudinary URLs can increase transfer and decode cost.
- PDF/document preview paths may download and render large files on the UI path.

### Recommended investigation

- Confirm Cloudinary delivery URLs and use width/quality/format transformations for card thumbnails.
- Compare original versus transformed byte size and decode time.
- Verify Flutter image cache hit rate on warm navigation.
- Remove or isolate any remaining Firebase Storage request paths if unused; no active Firebase image request was proven by this static pass.

## 10. Root Cause Analysis

### F-001 — Broad repeated activity/venue fetches

- Severity: P1
- Status: Confirmed code risk; latency not measured
- Files: `activ-frontend/lib/Screens/Home/HomeScreen.dart`, `VenueActivityListScreen.dart`, `ActivityManagementScreen.dart`, `api_calling/activity_setup_api.dart`
- Root cause: screen-local loading and models are discarded on navigation; parent screens refresh after child routes.
- Solution: resource-scoped repository cache with TTL/stale-while-revalidate; invalidate only after mutations.
- Benefit: faster warm navigation and lower API/database load.
- Risk: stale data if invalidation is incomplete; never apply long TTL to availability/bookings/payments.
- Verification: request-count trace and cold/warm TTFV comparison.

### F-002 — Sequential Add Activity request waterfall

- Severity: P1
- Status: Confirmed
- Files: `AddActivityAmenitiesScreen.dart`, `AddActivitySubmitReviewScreen.dart`, `ActivitySetupApi.submit`
- Root cause: activity read, questions/catalog read, availability write, and submit are separate route-driven operations.
- Solution: reuse already loaded activity/questions and return mutation results; parallelize only independent reads.
- Benefit: shorter transitions and fewer duplicate requests.
- Risk: stale review state; verify invalidation.
- Verification: route/request timeline with IDs.

### F-003 — Large management payload and Prisma work

- Severity: P1
- Status: Confirmed broad query shape; database latency not measured
- Files: `activ-backend/src/modules/venues/venues.service.ts`, `venues.controller.ts`
- Root cause: management response combines details, bookings, walk-ins, availability, images, answers and aggregates.
- Solution: projection-specific endpoints/selects and measured parallel query batches; paginate histories.
- Benefit: lower DB/serialization/network time.
- Risk: API contract fragmentation.
- Verification: payload bytes, server stage timings, Prisma query durations.

### F-004 — Inconsistent HTTP policy

- Severity: P1
- Status: Confirmed
- Files: `ActivitySetupApi.dart`, `HomeScreen.dart`, `DirectBookSlotScreen.dart`, booking/profile screens
- Root cause: wrapper and direct clients have different timeout, 401, retry, and cancellation behavior.
- Solution: one request layer with bounded retry, auth coordination, cancellation, and request IDs.
- Benefit: fewer duplicate requests and stuck loaders.
- Risk: behavior changes around auth expiry.
- Verification: forced 401/timeout tests and retry-count assertions.

### F-005 — Image transfer/decode cost

- Severity: P2
- Status: Confirmed missing optimization evidence; exact cost not measured
- Files: review/activity/photo/profile/document screens
- Root cause: remote images are rendered without consistently enforced thumbnail transformations and decode sizing.
- Solution: Cloudinary thumbnail URLs, `cacheWidth`/`cacheHeight`, placeholders, and bounded image lists.
- Benefit: faster first content and lower memory.
- Risk: image quality regressions.
- Verification: bytes downloaded, decode time, memory and frame rasterization.

### F-006 — Loader state complexity

- Severity: P1 if reproduced, otherwise P2
- Status: Risk confirmed; stuck instance not proven
- Files: all screens with `_loading`, `_saving`, `_submitting`, `_loadingSlots`
- Root cause: many independent flags and direct HTTP paths.
- Solution: operation state objects, one owner per request, exhaustive `try/catch/finally`, bounded retry UI.
- Benefit: no indefinite spinner and clearer recovery.
- Risk: state transition regressions.
- Verification: error, timeout, dispose, and navigation interruption tests.

## 11. Prioritized Optimization Plan

### P0 — Critical

- Instrument and eliminate any reproduced infinite loaders or auth retry loops.
- Add request correlation IDs and bounded retry counts before changing caching.

### P1 — High

- Consolidate HTTP/auth behavior.
- Add request deduplication and resource-scoped caching for venue/activity/profile data.
- Split or slim management/activity detail payloads.
- Measure and optimize `getActivityManagement`, activity detail, availability, booking, and walk-in endpoints.
- Remove avoidable Add Activity request waterfalls.

### P2 — Medium

- Add Cloudinary thumbnails and Flutter decode sizing.
- Paginate bookings, payouts, notifications, and other histories.
- Reduce nested shrink-wrap rebuilds and isolate dashboard sections.
- Cache static catalogs: categories, amenities, legal/FAQ content with explicit invalidation/TTL.

### P3 — Low

- Minor widget const/rebuild cleanup.
- Standardize loading placeholders and retry copy.
- Add route transition timing diagnostics.

## 12. Before/After Measurement Plan

No baseline was available. Before implementing, capture:

1. Cold and warm time to first visible content and usable state for Home, Activity List, Management, Add Activity, Slots, Bookings, and Profile.
2. Request count, endpoint duration, response bytes, status, retry count, and route transition IDs.
3. Backend controller duration, Prisma query duration/count, serialization duration, and response bytes.
4. Flutter frame build/raster time, image decode time, memory, and loader duration.
5. Auth-expiry, timeout, offline, back-navigation, and rapid date-change scenarios.

Targets for later validation, not current measurements: cached visible content under 500 ms where feasible, common API p95 under 1 second in the deployed region, immediate route feedback, zero uncontrolled loaders/retries, and no unnecessary duplicate requests.

## 13. Implementation Roadmap

### Phase 1 — Observability, no behavior change

- Files: request wrapper, direct HTTP callers, NestJS request/interceptor layer, performance logging utilities.
- Change: request IDs, timings, payload bytes, retry count, route IDs; redact tokens and personal data.
- Risk: low.
- Tests: auth/timeout/error instrumentation tests.

### Phase 2 — Request and state consolidation

- Files: `ActivitySetupApi.dart`, `HomeScreen.dart`, `VenueActivityListScreen.dart`, `ActivityManagementScreen.dart`, Add Activity screens.
- Change: shared repository, deduplication, bounded retry, mutation result propagation, selective invalidation.
- Risk: medium.
- Tests: cold/warm navigation and mutation consistency.

### Phase 3 — Backend projections and query optimization

- Files: `venues.controller.ts`, `venues.service.ts`, bookings/notifications/payout services.
- Change: endpoint-specific Prisma `select`, pagination, measured parallel reads, separate summaries where justified.
- Risk: medium/high due API compatibility.
- Tests: contract, authorization, response-shape, query-plan and load tests.

### Phase 4 — Images and rendering

- Files: activity/photo/profile/document screens and image URL helpers.
- Change: transformed thumbnails, decode sizing, placeholders, bounded lists, PDF lazy loading.
- Risk: medium.
- Tests: visual quality, memory, low-end-device frame tests.

### Phase 5 — Database review

- Files: none initially; DBA/schema review only.
- Change: run read-only `EXPLAIN` in an authorized non-production environment; propose indexes only after query-plan evidence.
- Risk: low if read-only; do not apply migrations during audit.
- Tests: representative query plans and concurrency/load tests.

## Audit Limitations

- No authenticated runtime session was used.
- No production requests, bookings, payments, uploads, invitations, or database mutations were performed.
- No production database `EXPLAIN ANALYZE` was run.
- No hosting dashboard, Supabase region/plan metrics, Cloudinary byte metrics, Flutter DevTools trace, or server perf-stage log was available.
- Findings explicitly labelled hypothesis require runtime evidence before prioritizing implementation.
