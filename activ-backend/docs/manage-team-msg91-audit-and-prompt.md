# Manage Team: MSG91 audit and ChatGPT setup prompt

> Historical audit from 18 November. The approved two-variable template integration and subsequent fixes are documented in [Manage Team MSG91 setup](manage-team-msg91-setup.md), updated 19 November 2026. The four-variable drafts below describe the earlier implementation.

Audited: 18 November 2026. Scope: repository code and official MSG91 documentation. No live account, credentials, DLT approval, SMS delivery, or deployed configuration was inspected. No application code or environment settings were changed.

## What already exists

- Flutter `lib/Screens/Home/ManageTeamScreen.dart` lists, creates, edits, removes, and resends invitations for staff. It displays email/SMS invitation results, including partial failure.
- NestJS `src/modules/team/team.controller.ts` and `team.service.ts` implement `/api/v1/team` CRUD and `POST /api/v1/team/:id/invite`. Invitations create a staff profile with `INVITE_PENDING`; provider acceptance changes the invitation status. Successful staff login activates the profile.
- `src/modules/mail/legacy-mail.service.ts::sendTeamMemberInviteSms` already sends invitation messages through MSG91 Flow. `MailService` inherits it, so selecting Gmail for email does not replace invitation SMS delivery.
- Staff use the shared phone-login flow: `POST /api/v1/auth/partner/request-otp?intent=login`, `POST /api/v1/auth/partner/verify-otp?intent=login`, and `POST /api/v1/auth/partner/resend-otp`. Request/resend bodies contain `phone`; verify contains `phone` and `otp`. Do not invent a separate team OTP API.
- `src/modules/otp/otp.service.ts` delegates OTP generation and verification to MSG91. `auth.service.ts` stores local challenges and claims a challenge atomically during staff login. Flutter routes a successful team-member login to `ManagerHomeScreen`.
- Existing JWT guards reload staff permissions/status from the database. Existing account ownership, removal, permissions, email delivery, and password login must be preserved.

## Two separate SMS templates

| Purpose | Existing environment variable | Template/API |
| --- | --- | --- |
| Login OTP | `MSG91_OTP_TEMPLATE_ID` | MSG91 OTP template; Send/Verify/Resend OTP APIs |
| Team invitation | `MSG91_TEAM_INVITE_TEMPLATE_ID` | MSG91 SMS/Flow template; `POST https://control.msg91.com/api/v5/flow` |

Shared backend secret: `MSG91_AUTHKEY`. OTP toggle: `MSG91_OTP_ENABLED`. Invitation link: `PARTNER_APP_URL`. These names exist in `.env.example`; real deployment values were not inspected. The example disables real OTP.

The existing Flow payload is:

```json
{
  "template_id": "<MSG91_TEAM_INVITE_TEMPLATE_ID>",
  "short_url": "0",
  "recipients": [{
    "mobiles": "91XXXXXXXXXX",
    "VAR1": "<fullName>",
    "VAR2": "<role>",
    "VAR3": "<PARTNER_APP_URL>",
    "VAR4": "<new-account temporary password OR Use phone OTP to sign in>"
  }]
}
```

Invitation resends do not generate another temporary password. Existing users keep their existing password. Roles include `manager`, `receptionist`, `trainer`, `staff`, `floor_manager`, and `security`.

## Findings before production setup

| Priority | Finding | Required follow-up |
| --- | --- | --- |
| High | OTP falls back to the phone number's last four digits whenever `MSG91_OTP_ENABLED` is not exactly `true`. | Fail closed in production if real OTP is disabled or required configuration is missing. Keep explicit development mocks only. Actual deployed settings remain unknown. |
| High | `verifyOtp` accepts a message containing `already verified`, and does not require a successful HTTP status for a success result. | Verify the provider contract; reject ambiguous/error responses. Add regression tests covering replay, resends, and multiple local challenges. Existing atomic challenge consumption is useful but does not establish that this fallback is safe. |
| High | Phone OTP verification does not use the existing challenge `attempts` field; no broader OTP rate limiter was found in the inspected auth flow. | Add bounded attempts and appropriate request/IP abuse protection using existing project conventions; a per-phone resend cooldown alone is insufficient. |
| Medium | Backend sends retry using POST; official MSG91 OTP overview lists GET for Resend OTP. | Confirm the current endpoint contract and correct the method, with contract-focused tests. Existing mocked tests do not validate provider compatibility. |
| Medium | Flutter resend countdown is 40 seconds; backend cooldown is 60 seconds. | Align UI and backend behavior and show useful cooldown errors. |
| Medium | Flutter accepts four digits; backend DTO accepts four to six; provider length/expiry are omitted. Local challenges expire after ten minutes; MSG91 documents a default expiry of fifteen. | Explicitly align digit count, expiry, validation, UI, and approved message text. Retaining four digits is the smallest compatible choice; six digits requires coordinated changes. |
| Medium | Resend creates another local unconsumed challenge. | Define and test which challenge is valid, supersede old challenges as appropriate, and avoid extending validity inconsistently with the provider's same-OTP retry behavior. |
| Medium | New-account invitations can include a reusable temporary password in SMS/email. | Offer an OTP-only invitation design. Removing `VAR4` or changing the password path requires an explicit coordinated code/template change; do not silently break password login. |
| Medium | Invitation acceptance allows any HTTP-success JSON whose `type` is not `error`. | Validate the documented success shape. Provider acceptance must not be presented as confirmed handset delivery. |
| Medium | SMS fetch calls have no explicit timeout; logs include full phone numbers and raw provider error data. | Add bounded network handling and mask phone numbers; never log OTPs, credentials, or verification URLs containing OTPs. |

## Draft messages for review

These are drafts, not registered or approved templates. Confirm the registered brand/header, permitted variable sizes, message category, link requirements, and exact DLT content before submission. DLT Entity/PE ID, sender/header, DLT content-template ID, MSG91 OTP-template ID, and MSG91 SMS/Flow-template ID are different identifiers.

**Login OTP (requires explicitly aligning provider and backend expiry to ten minutes):**

MSG91:
```text
Your ACTIV Partner login OTP is ##OTP##. It is valid for 10 minutes. Do not share it.
```

DLT draft:
```text
Your ACTIV Partner login OTP is {#var#}. It is valid for 10 minutes. Do not share it.
```

**Invitation compatible with the current four-variable payload:**

MSG91:
```text
Hi ##VAR1##, you have been added as ##VAR2## on ACTIV Partner. Sign in at ##VAR3##. Login details: ##VAR4##.
```

DLT draft:
```text
Hi {#var#}, you have been added as {#var#} on ACTIV Partner. Sign in at {#var#}. Login details: {#var#}.
```

**Recommended OTP-only invitation alternative (requires changing the Flow payload/template together):**

```text
Hi ##VAR1##, you have been added as ##VAR2## on ACTIV Partner. Sign in with your mobile number and OTP at ##VAR3##. Do not share your OTP.
```

The approved entity's brand wording may differ from ACTIV Partner. Do not submit these drafts unchanged until that is confirmed. Provider/DLT approval cannot be guaranteed by the application or ChatGPT.

## Copy into ChatGPT

Copy the following prompt. For code changes, use ChatGPT/Codex with repository access or supply the listed relevant files with secrets removed.

```text
Act as a senior Flutter + NestJS + Prisma engineer familiar with MSG91 SMS/OTP and India's DLT template setup. Help me finish the existing ACTIV Partner Manage Team flow and create the correct SMS templates. Audit the supplied code before proposing patches. Reuse the existing implementation; do not build another OTP system or install an unnecessary SDK.

Existing repository facts:
- Flutter: activ-frontend/lib/Screens/Home/ManageTeamScreen.dart manages team CRUD, invitations, resends, and partial email/SMS results. MobileNumberScreen.dart and OTPVerificationScreen.dart implement shared phone OTP login. Successful staff OTP login routes to ManagerHomeScreen.
- Backend: activ-backend/src/modules/team/{team.controller.ts,team.service.ts}; src/modules/mail/{mail.service.ts,legacy-mail.service.ts}; src/modules/otp/otp.service.ts; src/modules/auth/{auth.controller.ts,auth.service.ts,strategies/jwt.strategy.ts}; prisma/schema.prisma; .env.example. Read relevant DTOs and tests too.
- Team endpoints use /api/v1/team, including POST /api/v1/team/:id/invite. Staff OTP uses POST /api/v1/auth/partner/request-otp?intent=login and /verify-otp?intent=login, plus POST /api/v1/auth/partner/resend-otp. Request/resend body: {phone}; verify: {phone,otp}. Do not invent /auth/team OTP endpoints.
- Team creation transactionally creates/links the user and staff profile. Invitation status begins INVITE_PENDING. Email and SMS can succeed independently. Successful staff login marks ACTIVE and returns a team_member JWT with permissions. Current guards enforce current database membership/status. Preserve these checks and existing password login.
- Invitation SMS already uses POST https://control.msg91.com/api/v5/flow with the authkey header and body {template_id: MSG91_TEAM_INVITE_TEMPLATE_ID, short_url:"0", recipients:[{mobiles,VAR1:fullName,VAR2:role,VAR3:PARTNER_APP_URL,VAR4:password || "Use phone OTP to sign in"}]}.
- VAR4 contains a generated temporary password only when a new user is created. Resends use the OTP instruction instead. Existing users retain their passwords. SMS is inherited from LegacyMailService even when email uses Gmail.
- Shared login OTP uses MSG91_OTP_TEMPLATE_ID and MSG91_AUTHKEY. MSG91_OTP_ENABLED must equal "true" for real OTP; otherwise the current mock is the phone's last four digits. This must not authenticate production users.
- Flutter OTP length is 4 and countdown is 40 seconds. Backend cooldown is 60 seconds and local challenge validity is 10 minutes. Backend verify DTO accepts 4-6 digits. Send OTP currently omits explicit otp_length/otp_expiry.
- Retry currently uses POST /api/v5/otp/retry; MSG91's official OTP overview lists GET Resend OTP. Verify current documentation and fix any mismatch.
- verifyOtp currently accepts an "already verified" message as success and does not check response.ok on a success body. Resends leave another unconsumed local challenge. Phone OTP attempts are not bounded locally even though otp_challenges has an attempts field. Atomic local consumption already exists and must remain.
- Invitation SMS success detection is permissive; provider acceptance is not proof of handset delivery. Fetch timeouts/config validation/PII logging also need review.

What I need from you:
1. Explain the owner-adds-staff -> invitation -> phone OTP login -> permission-based staff home journey, separating what exists, dashboard setup, and required code fixes.
2. Create TWO separate message templates: team invitation in MSG91 SMS/Flow and login OTP in MSG91 OTP. Provide exact draft text in both MSG91 and DLT placeholder syntax, a variable mapping table, rendered examples with dummy values, and explain which identifier goes into each existing environment variable. Use ##OTP## for the OTP template and preserve current VAR1-VAR4 names for the compatible invitation option.
3. Offer an OTP-only invitation as the safer alternative to sending passwords. Clearly state the payload/template changes needed. Do not remove existing password login or break existing users without an explicit decision. Avoid unsupported claims about DLT approval, category, variable limits, or URL whitelisting; verify current official guidance and identify account-specific decisions.
4. Give dashboard steps for entity/header/content-template approval and mapping, MSG91 OTP-template creation, SMS/Flow-template creation, template activation, backend-only key configuration, credits, and delivery-report troubleshooting. Distinguish DLT Entity/PE ID, sender/header, DLT content-template ID, MSG91 OTP-template ID, and MSG91 SMS/Flow-template ID. Do not put an authkey into Flutter or ask me to paste secrets into chat.
5. Provide an environment-variable table using MSG91_AUTHKEY, MSG91_OTP_ENABLED, MSG91_OTP_TEMPLATE_ID, MSG91_TEAM_INVITE_TEMPLATE_ID, PARTNER_APP_URL. Use placeholders only and do not assume the fallback URL is our real deployed login URL.
6. Propose minimal file-specific patches for production fail-closed configuration, strict verification/provider responses, correct retry method, bounded attempts/rate limiting, challenge invalidation/replay handling, timeout/error handling, and masked logs. Align OTP length/expiry and the UI resend countdown. Keep four digits unless we explicitly choose six and update every affected layer. A template saying ten minutes requires matching provider settings and local behavior.
7. Reuse class-validator, existing ConfigService, native server fetch, existing JWT guards, Prisma and Jest/Flutter testing. Preserve transactional ownership checks, permissions, account activation, removal/revocation, durable email delivery and partial invitation results.
8. Include focused mocked regression tests and an end-to-end staging checklist: valid/wrong/expired/reused OTP, resend before/after cooldown, old challenges after resend, disabled production OTP, missing keys, malformed/provider-error responses, invitation partial failure, unauthorized CRUD, inactive/removed staff, and successful staff routing. Never claim tests pass unless run. No live SMS or production changes without an explicit authorized test plan.

Start by asking only for missing non-secret account facts: registered brand/entity and DLT approval status, approved header/template IDs if available, actual app login URL, target country, and whether to retain four digits or coordinate a six-digit migration. If I cannot answer yet, continue with clearly labelled placeholders and drafts. Browse current official MSG91 documentation and cite it. Finish with an ordered setup checklist and a short list of code changes required before launch.
```

## Verification

- Backend: `npm.cmd test -- --runInBand team.service.spec.ts auth-team-login.spec.ts team-session.spec.ts otp-sms-regression.spec.ts` — 4 suites, 24 tests passed. Network is mocked; this does not prove delivery or actual provider API compatibility.
- Flutter: `flutter test --no-pub test/manage_team_test.dart` — all 5 tests passed using mocked HTTP. The initial sandboxed invocation stalled without output and was stopped; the rerun with SDK-cache access passed.
- No live SMS, dashboard edits, DLT submission, environment changes, deployment, or production verification performed.

## Official sources checked

- [MSG91 Send OTP API](https://docs.msg91.com/otp/sendotp): managed OTP, required template/authkey, length and expiry parameters/defaults.
- [MSG91 OTP API overview](https://docs.msg91.com/otp): lists Send, Verify, and GET Resend OTP; describes resend as retrying the same OTP.
- [Create an OTP template](https://msg91.com/help/sendotp/where-to-find-the-sendotp-api-how-to-get-template-id): OTP section, template ID and `##OTP##` placeholder.
- [Configure OTP](https://msg91.com/help/sendotp/step-by-step-process-to-configure-otp): sender approval and India DLT guidance; backend API integration option.
- [Create an SMS/Flow template](https://msg91.com/help/template/how-to-create-flow-id-to-send-sms-via-api): DLT content-template ID, mapped sender and exact approved content for India.
- [Map a DLT template to a Flow template](https://msg91.com/help/dlt-registration-in-india/map-approved-dlt-template-id-with-respective-flow-id-on-msg91-panel): separate identifiers and approved content/sender mapping.
