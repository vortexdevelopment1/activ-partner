# Manage Team MSG91 implementation and setup

Updated: 19 November 2026.

## Status

Implemented in the existing NestJS/Prisma and Flutter flow. Automated provider tests use mocks. No live SMS/email was sent, production settings changed, template submitted, database migration applied, or deployment performed.

The following account information was supplied by the owner, not independently verified against the MSG91 dashboard:

| Setting | Value |
| --- | --- |
| MSG91 SMS template | `ACTIV_TEAM_INVITE`, v1.0 |
| MSG91 SMS/Flow template ID | `6afdeef436aedc84d2040fc4` |
| DLT content-template ID | `1777179489551953334` |
| Sender/header | `ACTPVT` |
| DLT category/status | Service Implicit / Active, per supplied details |
| MSG91 approval | Must be rechecked; previously pending |

The earlier successful dashboard SMS test was reported by the owner. It is not an application end-to-end test.

## Implemented flow

1. The existing partner JWT and role guards protect team CRUD and resend operations.
2. Team creation preserves transactional account linking, ownership checks, staff permissions and durable email preparation. The profile starts at `INVITE_PENDING`.
3. For a newly created user, the existing cryptographic password generator supplies the same temporary password to the password hash, invitation email and SMS. No existing password is reset or disclosed.
4. Invitation SMS uses the configured Flow template with exactly lowercase `var1` and `var2`. It accepts Indian mobile numbers in local, `91`, or `+91` form and formats the recipient as `91` plus ten digits. SMS variables contain the ten-digit login mobile and generated temporary password.
5. A successful HTTP response must also contain `type: success` and a 24-character hexadecimal message/request ID. Provider acceptance sets the existing `smsSent` compatibility field, not confirmed handset delivery. Flutter labels it “accepted; delivery unconfirmed”.
6. Email and SMS still have independent outcomes. Neither provider acceptance nor email success activates the staff profile. Existing password/OTP login activates it and routes staff to the existing team dashboard.
7. Existing accounts and invitation resends have no new plaintext password. The password-only SMS template is skipped, and the response includes `smsSent: false` and `smsUnavailableReason: password_template_requires_new_account`. Email invitation behavior remains available. Flutter explains SMS unavailability and existing phone-OTP login remains available.

### Invitation request

`POST https://control.msg91.com/api/v5/flow`, with backend-only `authkey`, JSON Content-Type and Accept headers. The request has a ten-second timeout.

```json
{
  "template_id": "6afdeef436aedc84d2040fc4",
  "short_url": "0",
  "recipients": [{
    "mobiles": "919876543210",
    "var1": "9876543210",
    "var2": "<secure temporary password generated for this new user>"
  }]
}
```

The number is an example. The app sends no SMS text, name, role, link, uppercase `VAR1`–`VAR4`, or OTP instruction to this template. Fixed wording, punctuation and variable positions remain controlled by the approved provider template.

## Configuration

Inject values into the backend's existing deployment configuration; do not paste credentials into Flutter, chat, logs or source control. Real `.env` files and deployed secrets were not read or overwritten.

```dotenv
MSG91_AUTHKEY=<existing backend authkey>
MSG91_TEAM_INVITE_TEMPLATE_ID=6afdeef436aedc84d2040fc4
MSG91_OTP_TEMPLATE_ID=<existing separate login OTP template ID>
MSG91_OTP_ENABLED=true
PARTNER_APP_URL=<verified existing staff login URL for invitation emails>
```

The DLT content-template ID and header are mapped in MSG91; they are not substitutes for either MSG91 template ID. The new invitation template does not contain a link; `PARTNER_APP_URL` remains relevant to email. Confirm the actual route rather than assuming a domain's homepage is a login page.

Production (`NODE_ENV=production` or `APP_ENV=production`) now refuses startup with disabled OTP, missing OTP credentials/template configuration, or a malformed/missing invitation template ID. Configure deployment settings before rolling out this code. Runtime provider failures also fail closed. Development mock OTP remains offline and available only outside production. This validation checks local configuration syntax/readiness, not account approval, credits or authkey validity at MSG91.

## OTP security and policy

- Existing shared endpoints remain: `POST /api/v1/auth/partner/request-otp?intent=login`, `/verify-otp?intent=login`, and `/resend-otp`.
- Flutter resend now calls `/resend-otp`, rather than accidentally issuing a fresh OTP through `/request-otp`.
- Send explicitly requests four digits and ten-minute provider validity. Local validity is ten minutes; backend DTO and UI also use four digits. The widget's settings do not configure this implementation: this app uses the server-side OTP API, not the widget API.
- Both Flutter and backend use a 60-second resend cooldown. New sends are serialized per phone with PostgreSQL advisory locks and invalidate earlier challenges.
- Resend retries the same OTP using the documented GET provider API. It keeps the same local challenge, original expiry and remaining attempts, and advances only the resend cooldown timestamp. It does not extend OTP validity or reset the attempt budget. Expired/exhausted codes require a fresh request through the mobile-number flow.
- Verification reserves one of five attempts atomically before contacting MSG91. Failed, timed-out and concurrent guesses cannot bypass that cap. Successful login still requires atomic consumption of an unexpired, unconsumed challenge. Verification always inspects the latest challenge, preventing fallback to an older unconsumed record.
- Ambiguous/error responses, including the previous `already verified` error fallback, are rejected. Successful verification requires both HTTP success and `type: success`.
- Shared PostgreSQL phone/IP limits cover request, resend and verification endpoints. In a ten-minute window: six sends per phone, thirty sends per IP, fifteen verification requests per phone, ninety per IP. Exhaustion returns HTTP 429 and Retry-After. Send and resend share a budget. These use namespaced hashed counter keys in the existing `otp_challenges` table; no new schema or dependency is needed.
- OTP and invitation requests time out after ten seconds. Their logs omit phone numbers, passwords, OTPs, authkeys, raw provider errors and verification URLs.
- Existing account-status checks, database-backed JWT membership/permission checks, staff removal/revocation, Gmail/email delivery, password login and password reset are preserved.

For deployments behind a reverse proxy, verify Express's trusted-proxy configuration against the actual network topology before launch. The limiter uses `req.ip` and does not trust arbitrary forwarding headers. Without correctly configured trusted proxies, several clients may share a proxy's IP budget. Retain an operational retention policy for expired OTP/counter rows. Database locks and counters still require a disposable PostgreSQL/staging integration check; unit tests mock persistence.

## Modified files

Paths below are relative to the repository root.

Application/configuration:

```text
activ-backend/.env.example
activ-backend/src/config/msg91.ts (new)
activ-backend/src/common/domain-types.ts
activ-backend/src/modules/team/team.service.ts
activ-backend/src/modules/team/dto/create-team-member.dto.ts
activ-backend/src/modules/mail/legacy-mail.service.ts
activ-backend/src/modules/otp/otp.service.ts
activ-backend/src/modules/auth/auth.controller.ts
activ-backend/src/modules/auth/auth.module.ts
activ-backend/src/modules/auth/auth.service.ts
activ-backend/src/modules/auth/dto/verify-otp.dto.ts
activ-backend/src/modules/auth/phone-otp-rate-limit.guard.ts (new)
activ-frontend/lib/Screens/Home/ManageTeamScreen.dart
activ-frontend/lib/Screens/OTPVerificationScreen.dart
activ-frontend/lib/api_calling/api_constant.dart
```

Tests:

```text
activ-backend/src/modules/team/team.service.spec.ts
activ-backend/src/modules/otp/otp-sms-regression.spec.ts
activ-backend/src/modules/otp/msg91-security.spec.ts (new)
activ-backend/src/modules/auth/phone-otp-security.spec.ts (new)
activ-backend/src/modules/auth/phone-otp-rate-limit.guard.spec.ts (new)
activ-backend/src/modules/auth/auth-partner-registration-audit.spec.ts
activ-backend/src/modules/auth/auth-venue-corrections.spec.ts
activ-backend/src/modules/mail/email-admin-access.spec.ts
activ-frontend/test/manage_team_test.dart
activ-frontend/test/onboarding_flow_test.dart
```

Documentation: this file and the historical audit's link to this implementation. No Prisma schema/migration or package dependency changes.

## Verification

- Backend full suite: `npm.cmd test -- --runInBand` — **97 suites passed; 743 tests passed, 40 skipped**. The first full run exposed an isolated email-controller test module missing a dependency for the new OTP guard; its scoped guard override was added and the full rerun passed. No live provider calls occurred.
- Backend build: `npm.cmd run build` — passed, including Prisma client generation. No migration or database data changes. A log-redirection attempt into `dist` hit a Windows file lock because the build cleans `dist`; rerunning normally passed.
- Dart analysis of modified Flutter screens/constants and the Manage Team test completed with exit code 0: no errors or warnings, 44 informational style diagnostics (including the existing uppercase constant/file naming conventions). The Flutter analyzer wrapper stalled, so the installed Dart analyzer was used directly. Repository-wide auto-fixing lint was not run.
- Flutter Manage Team, password-reset and session suites: `flutter test --no-pub test/manage_team_test.dart test/password_reset_flow_test.dart test/session_navigation_test.dart` — **15 passed, 8 skipped**.
- Focused Flutter OTP checks: `flutter test --no-pub test/onboarding_flow_test.dart --name 'OTP resend countdown|staff OTP login|login validates and sends existing payload once|network errors do not pop login or verification'` — **4 passed**. Combined focused Flutter checks: **19 passed, 8 skipped**.
- Full onboarding suite: **70 passed, 29 failed**. A separate copy of the unchanged `HEAD` frontend under the ignored Flutter build directory produced **69 passed, the same 29 failed**. The failing test-name sets were compared and matched exactly; no new failing test was introduced. The extra passing test checks staff OTP routing. Existing failures include slot-price handling, outdated onboarding layout expectations and support/login navigation assertions; they were left outside this integration's scope.
- Provider errors, malformed responses, missing configuration, timeout, production mock rejection, bounded/concurrent attempts, expiry/replay, resend behavior, rate limits, ownership/role guards, email independence, loading/duplicate submission and partial channel results have focused mocked coverage. Real PostgreSQL locking/limits and live SMS delivery remain pending.

## Remaining manual setup and one authorized staging test

1. Recheck MSG91 approval/active template version, exact fixed content, lowercase variable names, header `ACTPVT`, DLT entity/content-template mapping, authkey permissions and available SMS credits. Confirm that the password variable permits the current securely generated password length (30 characters); do not shorten it to the dummy sample password.
2. Inject the values above into the intended backend environment, preserving the separate OTP template and existing Gmail configuration. Confirm the registered OTP template's wording matches the four-digit, ten-minute policy and verify the actual login URL used by email.
3. Obtain a separately approved OTP-only invitation template before enabling SMS for existing accounts or resends. This implementation intentionally reports those scenarios unavailable; changing variable text to OTP instructions is not a substitute for approval.
4. Validate advisory-lock/attempt-limit behavior using a disposable local PostgreSQL or staging database, including concurrent sends/verifications, expiry, replay, removed/inactive staff and multiple backend instances. Check trusted proxy identity and expected shared-IP traffic.
5. Only after explicit authorization, choose one consenting, controlled phone number not already linked to another partner/team. Confirm the test environment and expected SMS cost. Avoid logging or recording plaintext credentials.
6. In that environment, sign in as the partner, add one team member with a role and permissions, and click Send Invite once. Confirm a saved pending/invited profile, the separate email/SMS results and the Flow payload shape. Do not treat API acceptance as delivery.
7. Check MSG91 delivery reports and the actual received message. Verify the mobile/password variables and fixed wording. Sign in through the existing phone/password path and confirm the team dashboard and permissions. Separately exercise OTP login for the same controlled account if that additional SMS is authorized.
8. Verify that successful login activates the staff profile, restricted actions remain blocked, and removal revokes access. A resend before activation must preserve the password and report the password-only SMS template unavailable. Do not reset an existing password to make resend work.

Current production blockers/pending verification: actual backend environment values, current MSG91 approval and exact dashboard content, provider delivery, approved no-password resend template, and staging database/proxy behavior. No live verification has been claimed.

## Troubleshooting accepted invitations without an SMS

The acceptance log now includes MSG91's validated request ID, which can be searched under **MSG91 → SMS → Logs**. Search the earlier request by the recipient (including country code) and date/time if its ID was not logged. Inspect the per-recipient delivery status and failure reason; HTTP/API acceptance alone cannot establish why a handset did not receive the message.

- `POST /team 409` with “phone number already belongs…” means creation was rejected before sending an invitation. Repeatedly adding that number does not retry SMS. Existing-account/resend SMS remains unavailable with the password-only template.
- A successful `DELETE /team/:id` followed by `POST /team 201` can still skip SMS: deletion removes staff membership, preserving the underlying user and password. Re-adding that phone links the existing account, so there is no new plaintext password for `var2`. The backend now explicitly logs `Team invite SMS skipped` for this case. HTTP 201 means the member was created, not that SMS was sent. A focused delete/re-add regression test verifies credential preservation and the SMS-unavailable response. Resolving this limitation requires a separately approved invitation template that does not require a password; do not delete the user or reset the password to fill the current template.
- Expired admin-token `401` errors require signing into the admin dashboard again. Those requests do not establish an SMS failure.
- Submitted/Pending, Failed, Blocked and Delivered are distinct provider outcomes. Check the exact failure code before changing template mappings, sender/header or message variables. Do not reset credentials, delete accounts, or send additional SMS solely to diagnose an accepted request.
- Provide only the delivery status/failure reason when sharing diagnostics; do not share the message body, password, phone number or authkey.

References: [locating SMS logs](https://msg91.com/help/text-sms/where-can-i-check-the-delivery-reports), [delivery status meanings](https://msg91.com/help/delivery-report/what-is-the-meaning-of-different-status-in-the-delivery-reports), [DLT failure reasons](https://msg91.com/help/delivery-report/dlt-related-failure-reasons).

Request-ID logging regression check: `npm.cmd test -- --runInBand otp-sms-regression.spec.ts msg91-security.spec.ts` — 2 suites, 35 tests passed with mocked requests. No additional live SMS was sent.

## Provider references

- [Send SMS / Flow API](https://docs.msg91.com/en/sms/send-sms): response includes success type and message/request identifier; success alone does not establish delivery.
- [Send OTP](https://docs.msg91.com/otp/sendotp): configurable digit count/expiry and send request ID.
- [Verify OTP](https://docs.msg91.com/en/otp/verify-otp): distinguish successful verification from HTTP-200 error bodies.
- [OTP overview](https://docs.msg91.com/otp): GET resend retries the same OTP.
