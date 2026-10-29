# ACTIV Partner App — Phase 1 Performance Instrumentation

Date: 2026-10-28  
Scope: Flutter API/request timing and NestJS request timing only.  
Phase boundary: no caching, optimization, navigation change, API contract change, business-logic change, schema change, migration, or database configuration change was made.

## 1. Files modified

- `activ-frontend/lib/Utills/performance_logger.dart` — new opt-in, debug-only structured Flutter logger.
- `activ-frontend/lib/api_calling/activity_setup_api.dart` — timing around the shared `ActivitySetupApi` request path.
- `activ-frontend/lib/Screens/Home/HomeScreen.dart` — timing for the direct approved-venues request.
- `activ-frontend/lib/Screens/Home/Activities/DirectBookSlotScreen.dart` — timing for the direct slot-availability request and its existing retry attempt.
- `activ-backend/src/common/interceptors/performance.interceptor.ts` — new opt-in NestJS request timing interceptor.
- `activ-backend/src/app.module.ts` — registers the interceptor globally.

No Prisma schema, migration, database, API route, response shape, timeout, retry behavior, navigation, or UI behavior was changed.

## 2. Instrumentation added

### Flutter structured API events

`PerformanceLogger` is enabled only when both conditions are true:

```text
ACTIV_PERF_LOGGING=true
Flutter debug mode
```

It emits `ACTIV_PERF` developer-log records containing:

- correlation ID;
- HTTP method;
- sanitized URL path, with query strings removed;
- attempt number;
- duration in milliseconds;
- outcome (`success`, `http_error`, `timeout`, `network_error`, `auth_missing`, or `invalid_response`);
- status code when available;
- response byte length when available.

It never logs authorization headers, request bodies, response bodies, OTPs, names, email addresses, phone numbers, or query parameters.

The shared `ActivitySetupApi` path is covered for categories, approved venues, questions, amenities, activity detail, answers, images, drafts, and submit-related calls. The existing timeout and error behavior is unchanged.

Direct HTTP coverage was added for the high-priority paths that bypass `ActivitySetupApi`:

- Home approved-venue/dashboard bootstrap request;
- Direct Book Slot availability request, including the existing second attempt after a 5xx response.

The direct paths retain their existing timeouts and retry behavior.

### Backend structured request events

`PerformanceInterceptor` is enabled only when:

```text
PERF_LOGGING=true
```

It emits `ACTIV_PERF` NestJS log lines for successful and failed requests with:

- request correlation ID from `x-request-id`, or a server-generated ID;
- method;
- sanitized route template/path;
- elapsed controller/request time in milliseconds;
- HTTP status;
- outcome;
- response `Content-Length` when the server provides it.

No headers, tokens, request bodies, response bodies, route parameters, or customer data are logged. When disabled, the interceptor returns the request stream without timing work.

### Prisma timing status

No Prisma query instrumentation was added in this phase because the current Prisma client is configured through the PostgreSQL adapter and existing `DB_LOGGING` controls Prisma logging. Changing Prisma client event configuration would risk changing query logging behavior and could expose SQL/query metadata. The existing `DB_LOGGING=true` mode remains available for an authorized development environment, but query parameter logging must not be enabled or copied into reports.

Controller/request timing can now be correlated with existing Prisma logs by request ID only after a future, controlled Prisma stage logger is approved. No database connection, pooling, schema, index, or migration setting was changed.

## 3. Example sanitized logs

Flutter developer log:

```text
event=api_start id=flutter-1761650000123456-0 method=GET endpoint=/api/v1/venues/my-approved-venues attempt=1
event=api_end id=flutter-1761650000123456-0 method=GET endpoint=/api/v1/venues/my-approved-venues attempt=1 duration_ms=842 outcome=success status=200 response_bytes=18420
```

Flutter timeout:

```text
event=api_end id=flutter-1761650000789012-1 method=GET endpoint=/api/v1/venues/activities/:id/slots attempt=1 duration_ms=15004 outcome=timeout
```

Backend:

```text
[ACTIV_PERF] event=request_start id=flutter-1761650000123456-0 method=GET route=/venues/my-approved-venues
[ACTIV_PERF] event=request_end id=flutter-1761650000123456-0 method=GET route=/venues/my-approved-venues duration_ms=791.4 status=200 outcome=success response_bytes=18420
```

The examples intentionally contain no real IDs, tokens, query strings, bodies, or personal data.

## 4. Enable/disable performance logging

### Flutter

Run the debug app with:

```bash
flutter run --dart-define=ACTIV_PERF_LOGGING=true
```

Disable it by omitting the define or setting it to false. Because the logger also requires `kDebugMode`, release builds do not emit these records.

View records in the Flutter/Dart developer console and filter for `ACTIV_PERF`.

### Backend

In a development or approved staging process only, set:

```text
PERF_LOGGING=true
```

Restart the NestJS process and filter stdout/stderr for `ACTIV_PERF`. Remove the setting or set it to false to disable request timing. Do not enable this in production without an approved log-retention and redaction policy.

## 5. Capturing cold and warm navigation measurements

For each target screen, record a run ID outside the app and collect the corresponding Flutter and backend log lines:

1. Cold run: force-stop the debug app, clear only the test session state if needed, launch, and open Home, Activity List, Activity Management, Add Activity, Direct Book Slot, Manage Slots, Manage Bookings, and Profile.
2. Warm run: return to the same screen without force-stopping the app.
3. Record route start and first usable UI manually or with DevTools; this phase does not yet add a global route observer.
4. Match Flutter API IDs to backend IDs through the `x-request-id` header where the caller supplies it, or compare timestamps until a future shared header propagation change is approved.
5. Repeat each case at least five times and report median and p95. Do not treat a timeout value as measured latency.

The current instrumentation captures API timing, not automatic route-first-frame timing. Route timing requires a future approved `NavigatorObserver` or screen-specific lifecycle instrumentation and must not trigger a rebuild or request.

## 6. Identifying duplicate requests

Group records by:

```text
method + endpoint + short time window + screen action
```

Examples to inspect:

- `/venues/my-approved-venues` after Home child-screen return;
- `/venues/my-approved-venues` after Activity List child-screen return;
- activity detail on Configure, Submit Review, and Submission Result;
- management detail after save and after Manage Slots returns;
- slot availability during rapid date changes.

Two records with distinct correlation IDs for one user action indicate separate requests. A retry is only expected when the attempt number increments for the same request operation. Do not count a backend log line and its matching Flutter log line as two network requests.

## 7. Tracing a slow API through NestJS and Prisma

1. Start with the Flutter `api_start` ID and endpoint.
2. Match the backend `request_start` ID where `x-request-id` was propagated by the caller; otherwise match method/path and timestamp.
3. Compare Flutter duration with backend duration to estimate client/network overhead without calling it a measured network split.
4. Enable existing `DB_LOGGING=true` only in an approved non-production environment if SQL query timing is required.
5. Correlate Prisma query timestamps with the backend request interval. Never copy SQL parameter values into the report.
6. Prioritize `getActivityManagement`, `getActivityDetail`, approved venue retrieval, walk-in slots, bookings, and dashboard aggregates.
7. Record query count, query duration, controller duration, response bytes, and request outcome in a separate measurement sheet.

No production `EXPLAIN ANALYZE`, booking, payment, upload, SMS, email, or database mutation is required or performed by this instrumentation.

## 8. Validation and test results

- Backend compilation: **passed** with `npm run build --if-present`; Prisma client generation completed as part of the existing prebuild script.
- Flutter static analysis: **not completed** because the local Flutter SDK attempted to update its engine cache outside the workspace and was denied permission:

  ```text
  /opt/homebrew/share/flutter/bin/internal/update_engine_version.sh ... Operation not permitted
  ```

- API contracts: no endpoint, request body, response body, route, timeout, or retry behavior intentionally changed.
- Authentication: no auth logic or token handling changed; logs omit auth headers/tokens.
- Database: no schema, migration, connection pool, table, record, or index changed.
- Additional API calls: instrumentation is passive around existing calls; it adds no network request.
- UI/loading behavior: no loader visibility or navigation behavior changed.
- Sensitive logging: bodies, headers, query strings, and private identifiers are excluded from the new logs.

## 9. Remaining uninstrumented paths

The following direct callers are not individually wrapped yet and should be covered in a later instrumentation increment only if the first logs show they are relevant:

- remaining direct HTTP calls in profile, bookings, payouts, notifications, team, bank/KYC, legal/support, and venue onboarding screens;
- global route first-frame/usable-state timing;
- individual loader start/end events across every screen;
- Prisma query count/duration and connection acquisition stages;
- Cloudinary upload/download byte and decode timing;
- PDF parsing/render timing;
- authentication refresh/redirect correlation across all callers.

These paths were intentionally left untouched rather than introducing broad widget or request refactors in Phase 1.

## 10. Known limitations

- Flutter debug-only logs are not production telemetry and can be affected by debug overhead.
- Backend response size is only reported when `Content-Length` is available; chunked responses show no byte value.
- Backend route information can be a concrete path when Nest route metadata is unavailable; query strings are never logged.
- Flutter and backend correlation is strongest when the request ID is propagated as `x-request-id`; the current shared Flutter wrapper logs an ID but does not alter request headers, preserving the API/request behavior contract.
- No route observer was added, so first-frame and usable-state timings remain a manual/DevTools measurement for now.
- Existing Prisma logging is not automatically correlated to request IDs.
- No production latency, p95, database duration, connection wait, or hosting-region measurement is claimed.
