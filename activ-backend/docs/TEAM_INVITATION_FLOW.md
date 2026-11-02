# Partner team invitations

Partners use **Manage Team → New Member** to enter a name, Indian mobile number,
email, designation, and booking-management permission. The app requires an email
for new invitations. Older API clients may still create phone-only members.

## Audit findings and fixes

- The old form/API supported only SMS even though the controller claimed email
  was sent. New invitations prepare an encrypted email in the account transaction,
  then attempt Gmail/selected mail transport and SMS after commit.
- Provider failure previously appeared as “invite sent.” Responses and saved
  metadata now expose `invitationDelivery.emailSent` and `smsSent`. Neither means
  inbox/handset delivery is guaranteed. `invite_pending` means no send was confirmed;
  `invite_sent` means at least one channel was confirmed. The member becomes `active`
  after successful login. The roster displays the last invitation attempt.
- Existing users previously could receive a generated password that was not their
  actual password. They now keep their credentials and receive OTP instructions.
  Partners cannot change pre-existing customer-account login contact details.
- Staff requesting a Login OTP previously failed verification because the verifier
  required a partner-admin membership. Staff can now complete that same Login flow.
- Staff may change their own password through `/auth/partner/change-password`.
  The controller passes their actual partner ID and authenticated user ID.
- Team tokens reread permissions on each request. Removed members and staff of
  pending/suspended partners cannot authenticate. Team administration remains
  partner-only; booking APIs continue to check booking-management permission.

## API

All `/api/v1/team` management endpoints require a partner JWT and scope records to
that partner. A designation such as “manager” does not grant extra permissions.

- `GET /team`: list members and their last invitation-delivery metadata.
- `POST /team`: create the member and attempt both channels.
- `PATCH /team/:id`: update details and individual permissions.
- `POST /team/:id/invite`: explicitly resend sign-in instructions for a member who
  has not joined. Limited to once per minute. Does not reset passwords.
- `DELETE /team/:id`: remove access; existing team tokens fail subsequent validation.

New accounts receive a random password; only its bcrypt hash is stored on the user.
The email payload is encrypted using the existing outbox. Passwords are never
returned by team APIs. Resends use OTP instructions rather than generating another
password. SMS has no background retry queue; its failures require explicit resend.
Email can remain pending/failed/uncertain in the existing delivery system. Review
provider logs before retrying uncertain outcomes; do not replay member creation.

Existing phone/email account conflicts return 409. A pre-existing customer can be
linked only when the supplied email matches their registered email. Their account
credentials are not modified. Incomplete accounts need to establish their contact
details themselves before an email invitation can use those details.

## Configuration required before live use

- Keep the verified Gmail configuration, `EMAIL_PROVIDER=gmail`, and stable
  `EMAIL_DELIVERY_STORAGE_KEY` and `GOOGLE_REFRESH_TOKEN_STORAGE_KEY`.
- Set `PARTNER_APP_URL` to the actual member login URL.
- Set `MSG91_AUTHKEY` and the approved `MSG91_TEAM_INVITE_TEMPLATE_ID`.
- SMS template variables: `VAR1` member name, `VAR2` designation, `VAR3` login URL,
  `VAR4` password or the instruction “Use phone OTP to sign in.” The approved
  template must accommodate both types of sign-in instruction; no WhatsApp
  delivery is implemented or advertised.
- Keep `GOOGLE_OAUTH_SETUP_ENABLED=false` after authorization.
- Keep automatic email retries disabled until pending deliveries have been reviewed.

No schema migration is needed: invitation state uses the existing staff JSON
permissions field and email outbox. No live invitations, SMS, emails, production
configuration changes, or production database operations were performed for this
implementation. Provider tests mock network calls; real acceptance and delivery
remain deployment checks after the SMS template/login URL are supplied.
