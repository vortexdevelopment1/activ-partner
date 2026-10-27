# ACTIV Partner email templates

Open [index.html](index.html) to review all 27 templates. Each template has a standalone HTML preview and a plain-text alternative using fictitious data. Previews never access the database or send email.

Regenerate from `activ-backend`:

```sh
npm run email:preview
```

The shared design uses the existing project logo, white email panel, highlighted heading, status/details card, Team ACTIV sign-off, app badges and social footer from the supplied reference. The logo is embedded as a CID attachment in delivered emails. Signed agreements retain their PDF attachment.

## Coverage and existing templates

| Flow | Template IDs | Integration |
| --- | --- | --- |
| Finish / submitted application | `venue_under_review` | First successful venue review submission |
| Signed agreement | `agreement_signed` | Existing Gmail/SMTP agreement methods |
| Venue approval/rejection | `venue_approved`, `venue_rejected` | Existing admin review methods |
| Requested venue corrections | `venue_changes_requested` | Existing request-changes method |
| Suspension | `venue_suspended`, `partner_suspended` | Existing venue/account suspension methods |
| Venue removal | `venue_deleted` | After a successful removal/archive transaction; repeated archives skipped |
| Venue change request | `venue_update_submitted`, `venue_update_approved`, `venue_update_rejected` | Submission and admin decision |
| Activity approval | `activity_submitted`, `activity_approved`, `activity_rejected` | Submission and admin decision |
| Bank account verification | `bank_submitted`, `bank_approved`, `bank_rejected` | Submission/resubmission and review; account digits limited to last four |
| Partner support | `support_received`, `support_in_progress`, `support_resolved`, `support_cancelled` | Creation and changed status |
| Callback requests | `callback_received`, `callback_in_progress`, `callback_resolved`, `callback_cancelled` | Creation and changed status |
| Password reset | `password_reset` | Existing reset-code method |
| Team invitation | `team_invitation` | Existing invitation method |

Agreements and suspensions previously had plain-text messages; venue approval, rejection, change requests, invitations and password resets used MSG91-hosted templates. They now use the shared branded renderer when SMTP or Gmail is configured. Existing internal staff support/callback alerts and invitation SMS remain in their existing flows.

## Delivery configuration

New branded notices use SMTP when `MAIL_USER` and `MAIL_PASS` are present; otherwise they use the existing Gmail OAuth configuration. SMTP accepts `MAIL_HOST`, `MAIL_PORT`, `MAIL_FROM_EMAIL`. Gmail uses the project's existing OAuth setup and sender settings. This change does not create credentials or modify provider settings.

Existing MSG91 email methods retain their current hosted-template fallback when no branded transport is configured. That fallback continues to render the template stored in MSG91; these local HTML files do not automatically update a provider-hosted template. Configure SMTP/Gmail to use the new design and deliver the new notice types.

Notice delivery is best effort. Provider failures are logged and do not undo saved requests or status changes. There is no persistent delivery queue/retry worker in this change, and no guarantee of exactly-once delivery across concurrent status changes. Existing agreement delivery receipts/retry behavior is preserved.

## Branding / footer links

As requested, store and social buttons currently point to the project URL (`PARTNER_APP_URL`, default `https://activ-partner.vercel.app/`). Replace these settings when official destinations are available:

```dotenv
PARTNER_APP_URL=https://activ-partner.vercel.app/
EMAIL_WEBSITE_URL=https://activ.live/
SUPPORT_EMAIL=support@activ.live
EMAIL_APP_STORE_URL=https://activ-partner.vercel.app/
EMAIL_PLAY_STORE_URL=https://activ-partner.vercel.app/
EMAIL_INSTAGRAM_URL=https://activ-partner.vercel.app/
EMAIL_LINKEDIN_URL=https://activ-partner.vercel.app/
EMAIL_YOUTUBE_URL=https://activ-partner.vercel.app/
EMAIL_X_URL=https://activ-partner.vercel.app/
```

Templates, copy and dynamic fields: `src/modules/mail/templates/partner-email.ts`.
Delivery: `src/modules/mail/mail.service.ts` and `partner-email.service.ts`.

Status notifications exclude internal support notes, credentials and bank documents. Temporary account passwords and password reset codes are included only in their existing intended account-access flows. No real emails were sent during preview/test validation.
