# ACTIV Partner Gmail migration

## Scope and provider selection

`EMAIL_PROVIDER=legacy` (also the default) preserves the old SMTP/Gmail/MSG91
email routing. `EMAIL_PROVIDER=gmail` routes every application email, including
internal callback requests, through Gmail API with no SMTP/MSG91 fallback.
`EMAIL_PROVIDER=smtp` explicitly routes all emails through SMTP without fallback.
MSG91 SMS OTP and team invitation SMS are unchanged.

Database mode requires the primary Google account `support@activ.live`. New consent
requests `openid email gmail.send`. Google's signed ID token is validated by the
SDK (signature, issuer, expiry, audience), plus a request-specific nonce, subject,
email_verified=true, exact sender email and Workspace hd=activ.live. Configuration
and login_hint are not proof of identity. Aliases, send-as addresses and groups are
rejected by this path. Account verification does not prove Gmail service enablement
or delivery; the intended primary mailbox must be Gmail-enabled. No mailbox-content
permission is requested. Old env/file grants remain compatible but are not
retroactively labelled verified. New verified setup requires fresh consent.

No production configuration, authorization, database migration, or message send
is performed by this development change.

## Database and encrypted email payloads

The additive migration is `prisma/migrations/20261029000000_email_deliveries`.
Apply it through the existing approved database migration process before enabling
durable delivery. Do not use `db push` or reset the database in production.
Generate the Prisma client during the build (`npm run build` already does so).

Explicit Gmail/SMTP always require durable delivery. Legacy deployments opt in
for general notices with `EMAIL_DELIVERY_ENABLED=true`. Venue approvals always
require the delivery table and `EMAIL_DELIVERY_STORAGE_KEY`, even in legacy mode
with general durable delivery disabled. Install both before accepting approvals;
missing storage/encryption configuration fails approval without publishing it.
`EMAIL_DELIVERY_STORAGE_KEY` must have at least 32 random characters.
Keep this key in deployment secrets and preserve it across deploys/rollbacks.
Changing it without re-encrypting pending records prevents their recovery.

Email payloads (including codes, temporary passwords and PDFs) are AES-256-GCM
encrypted in `email_deliveries`, authenticated to the record ID. List/retry API
responses never include those payloads. Successful/expired payloads are erased;
delivery metadata and idempotency keys remain. Establish an operational retention
policy for failed/uncertain encrypted payloads; do not delete unresolved work.

Venue publication, partner/owner activation, initial credentials, encrypted approval
email, activity approval, booking-slot synchronization and the approval audit event
commit in one database transaction. Row locks are acquired in partner, venue,
owner order, with the venue and owner reread after locking. Concurrent approvals
for the same venue produce one approval and one delivery; different venues of the
same partner cannot generate competing initial passwords. Stale concurrent
moderation decisions are rejected instead of overwriting a completed approval.

Any preparation or database failure rolls the entire transaction back. Only after
commit are email transport, in-app notification and push attempted; failures there
do not undo approval. The saved email can be recovered through delivery operations.
Duplicate approval requests for an already published venue are no-ops: they do not
resend mail, recreate credentials, change approval timestamps or repeat notifications.
An interrupted post-commit notification is not durably retried by this change.

Existing passwords are preserved, including when a second venue is approved.
Email retries never run approval or change a password. Approvals without a new
password tell the partner to use existing credentials, phone OTP or Forgot Password.
The email uses the current venue profile display name (falling back to venue name)
and registered owner details; existing HTML, inline logo and attachment handling
are retained. Missing owners/registered email or suspended owner/partner accounts
block approval pending correction.

Approval idempotency is per venue and independent of provider/recipient changes.
Historical `partner_approval.email_sent` audit receipts are imported as SENT without
resending a welcome. Before rollout, reconcile any approval delivery records from
an earlier implementation using provider/recipient-based hashes; those old keys
are not automatically converted. Already published but inconsistent historical
rows are not repaired by duplicate approval: review and reconcile them separately
through an audited process, without blindly replaying business actions.

Other email notices are queued after their business action commits. Provider
failures cannot roll back the action. There is still a commit-to-enqueue gap if
the process/database fails before insertion; use business records to reconcile
missing notices, not blind replay of business endpoints. A database outage cannot
itself be durably recorded in that same database; sanitized logs report it.

## Encrypted OAuth credentials in PostgreSQL (Phase 5)

Apply `prisma/migrations/20261029010000_google_oauth_credentials` after the email
delivery migration and before deploying database mode. It creates only a credential
table with unique (provider, sender), positive revision, and VERIFIED/REAUTH_REQUIRED
status constraints. No partner or venue data is modified. Stored metadata is sender,
Google subject, SHA-256 client-ID fingerprint, revision and timestamps. Client secrets,
authorization codes, ID tokens and access tokens are never stored.

Refresh tokens use the separate stable GOOGLE_REFRESH_TOKEN_STORAGE_KEY (at least
32 random characters) and versioned AES-256-GCM: fresh 12-byte nonce, 16-byte tag,
and provider/sender/client fingerprint/subject as associated data. Wrong keys,
tampering and mismatched OAuth clients fail closed. Plaintext exists only in memory.
Startup reads only; it never creates credentials or launches consent. Database mode
does not write token files. Missing credentials report NOT_CONFIGURED.

The protected setup request captures the current row revision. Callback identity
verification and transactional compare-and-set must succeed before reporting success.
Unique constraints prevent duplicate initial grants; stale callbacks cannot replace
newer grants. Normal refreshes without a new refresh_token preserve the stored value.
Rotations are encrypted with revision protection before sending. Late rotation storage
failure after a send is an uncertain delivery, requiring provider review. invalid_grant
marks only its matching revision REAUTH_REQUIRED and retains ciphertext; no automatic
consent starts. An older failed request cannot disable a newer grant.

Transient database failures preserve rows; subsequent sends/status calls retry reads.
If rotation persistence fails, the new token is retained only in process memory
and persistence is retried before a subsequent send. Google refresh and PostgreSQL
cannot commit atomically: if the process dies in that gap and Google invalidated
the old token, explicit reauthorization may still be required. Never claim an
exactly-once/zero-loss guarantee across Google's token endpoint and the database.
Startup logs only a generic warning. Protected status codes include DATABASE_UNAVAILABLE,
CREDENTIAL_UNREADABLE (key/tampering), OAUTH_CLIENT_MISMATCH, REAUTHORIZATION_REQUIRED,
PERSISTENCE_FAILED and CONFIGURATION_ERROR. No status response exposes credentials,
ciphertext, keys, subjects or SDK error bodies. Repair connectivity/key/config or
explicitly reauthorize as indicated; do not clear credentials to hide an error.

## Render Free configuration (prepare only; do not authorize yet)

User-provided hosting: Render Free, Docker, 512 MB RAM, no persistent disk. Database
mode survives restarts/redeploys/spin-down without a disk. Actual 512 MB memory
headroom has not been load-tested. Free-service sleep stops the in-process email
worker; polling resumes only while running. It is not a guaranteed background queue
while asleep. OAuth state expires in 10 minutes and is lost on restart: keep one
instance and a short uninterrupted consent window.

Render Free also blocks standard SMTP ports 25/465/587; Gmail API uses HTTPS.
Preserving legacy configuration does not prove its SMTP path works on that plan.
Free services lack one-off jobs and shell access, so migrate from a separate approved
runner. If the database itself is Free Render Postgres, verify its expiration and
backup limitations; do not assume the application's external PostgreSQL has that plan.

Future settings after reviewing live token/client dependencies:

```dotenv
APP_ENV=production
NODE_ENV=production
EMAIL_PROVIDER=legacy
EMAIL_DELIVERY_ENABLED=false
EMAIL_DELIVERY_STORAGE_KEY=<preserve existing stable delivery key>
EMAIL_RETRY_WORKER_ENABLED=false
GOOGLE_CLIENT_ID=<existing OAuth client ID>
GOOGLE_CLIENT_SECRET=<existing OAuth client secret>
GOOGLE_REDIRECT_URI=https://activ-partner.onrender.com/api/v1/auth/google/callback
GOOGLE_SENDER_EMAIL=support@activ.live
SUPPORT_EMAIL=support@activ.live
GOOGLE_TOKEN_SOURCE=database
GOOGLE_REFRESH_TOKEN_STORAGE_KEY=<separate random secret, at least 32 characters>
GOOGLE_OAUTH_SETUP_ENABLED=false
GOOGLE_OAUTH_SETUP_KEY=<separate random secret, at least 32 characters>
```

Unset GOOGLE_REFRESH_TOKEN and GOOGLE_REFRESH_TOKEN_FILE in database mode. An env
token, explicit file path, actual default/configured token file, or database row
accessed from env/file mode is a conflict. No source silently wins. Preserve old
credentials in the approved secret manager, not active env variables; do not delete
server files as an unreviewed shortcut. The same release cannot switch back to
env/file while the sender's database row exists; see rollback below.

Keep EMAIL_PROVIDER=legacy until verified authorization succeeds. Legacy agreements
and support can already depend on the same Google client/token pair. Do not replace
credentials or switch sources prematurely. Inventory and pause dependent operations
for the approved cutover window. Disabling the worker/general delivery flag does
not suppress immediate emails or durable approval sends. No actual Render settings
were changed by this task.

Env mode supports existing provisioned tokens but cannot receive callback exports.
File mode preserves encrypted fsync/atomic rename and needs an absolute persistent
path in production; it is unsuitable for Render Free. Neither key nor token belongs
in Git, images, logs or browser responses.

For old env/file grants, prefer fresh verified consent into PostgreSQL during the
approved cutover window. Old gmail.send-only consent cannot supply signed email
identity. There is no automatic startup import, token export endpoint or unprotected
migration endpoint. Preserve the old client/token pair for recovery. A future
no-consent import would require separately reviewed identity proof and tooling;
never insert an old token as VERIFIED merely on trust.

## OAuth authorization (wait for the mailbox owner)

Before asking the client for OTP, complete these operator checks without starting
OAuth: review the exact deployed release and Docker build, approve database history
and backups, apply/verify both additions, provision distinct stable keys, privately
inventory current Google-dependent legacy flows, agree a cutover/rollback window,
verify the matching Web OAuth client and exact callback, enable Gmail API and the
`openid email gmail.send` consent scopes, confirm support@activ.live is the primary
Gmail-enabled Workspace mailbox (not an alias/group), and review app audience/policy.
Keep setup disabled and Gmail provider disabled until that agreed window. Never
change client credentials without the existing token/client dependency review.

1. Enable Gmail API in the existing Google Cloud project. Verify the Web OAuth
   client has exactly this authorized redirect URI:
   `https://activ-partner.onrender.com/api/v1/auth/google/callback`.
2. Confirm consent audience/publishing status and organization app-access policy.
   New consent is required for signed identity (`openid email`) in addition to
   gmail.send. The callback rejects missing identity/scope, unverified/wrong email,
   invalid nonce, missing Workspace domain and invalid signature/audience/expiry.
   External Testing grants generally expire after seven days for Gmail scopes.
3. Apply both additive migrations, provision the stable OAuth key/database mode
   and resolve source conflicts before authorization. Use one service instance
   and avoid redeploys during setup: OAuth state is held in process memory for
   ten minutes, so restarts or a callback reaching another instance invalidate it.
4. Temporarily enable `GOOGLE_OAUTH_SETUP_ENABLED=true` and restart.
5. Using an authenticated API client, make this request without following redirects:

   ```http
   GET /api/v1/auth/google/connect
   Authorization: Bearer <valid application admin JWT>
   x-google-oauth-setup-key: <setup secret>
   ```

6. Open the Google `Location` URL in the mailbox owner's browser. Do not forward
   either request header to Google. Complete consent as the intended sender.
   Callback: `GET /api/v1/auth/google/callback` (public, single-use state protected).
7. Success requires exact sender verification and committed encrypted persistence.
   Using an admin JWT, check `GET /api/v1/auth/google/status`: source=database,
   status=VERIFIED, verified=true, sender=support@activ.live. Disable setup, restart,
   and verify that status and a single stored credential remain.
8. Only with explicit approval, send controlled tests for
   From/Reply-To, HTML/text, inline logo, PDF and the internal support/callback inbox.
9. Drain/reconcile provider-bound legacy jobs, then set EMAIL_PROVIDER=gmail and
   EMAIL_DELIVERY_ENABLED=true after readiness and authorized testing. Enable
   `EMAIL_RETRY_WORKER_ENABLED=true` when ready to process saved work.
   Worker polling is every 30 seconds, batches of ten, with database atomic claims.

Workspace Admin access is needed only for provisioning/policy changes that the
organization requires; ordinary user consent itself does not require a super
admin. Do not bypass mailbox OTP or organizational controls. No service-account
or domain-wide delegation workaround is introduced.

## Delivery operations and retry safety

Protected by the existing global JWT and ADMIN-role guards:

* `GET /api/v1/email-deliveries` lists the latest 100 sanitized records.
* `POST /api/v1/email-deliveries/:id/retry` retries a saved email only.

States: `PENDING`, `PROCESSING`, `RETRY`, `SENT`, `FAILED`, `UNCERTAIN`, `EXPIRED`.
Known configuration/429 rejections use exponential backoff (one minute up to one
hour), at most five automatic attempts. Permanent 4xx failures need correction
and an admin retry. Reset emails expire after ten minutes and are never sent
after their delivery deadline. A queued reset response keeps its reset challenge
valid; always use the latest requested code.

Network/timeouts/5xx or interrupted sends are `UNCERTAIN`, not automatically
resent. Processing leases older than five minutes are held as uncertain by the
worker. Check provider logs before retrying an uncertain delivery, then explicitly
submit `{ "confirmUnknownOutcome": true }`. There is no provider-supported
exactly-once guarantee: Gmail acceptance and the database acknowledgement are
separate operations. An uncertain manual replay can duplicate an accepted email.
Do not retry a SENT record or rerun venue/bank/activity approval to resend email.

Queued jobs remember their provider. After changing providers, jobs for the old
provider are held as rejected for migration review rather than sent through a
different transport. Inventory/drain the old queue before cutover.

The existing standalone Gmail test script's `--dry-run` checks local token loading
only, not OAuth validity or mailbox delivery. Do not run its send mode without
explicit authorization. SMTP verification scripts are legacy tools, not Gmail
readiness checks.

## Deployment and rollback

### Release prerequisites and database targeting

The repository contains 13 incremental migrations. The first,
`20261008_normalize_venue_data`, starts with ALTER TABLE against existing tables;
there is no initial empty-database baseline in this history. Do not run this
history against a fresh production database or automatically mark migrations as
applied. Production schema/history and backup restore readiness must be reviewed
by the database owner. The new email migration creates only `email_deliveries`,
its unique idempotency index, retry index and allowed-status CHECK constraint.
The OAuth credential migration is also additive and does not modify partner/venue
rows. `migrate deploy` applies ALL pending
migrations, which can include earlier data-changing SQL; inspect that list first.

Both runtime and Prisma ignore `.env`/`.env.local` when either `NODE_ENV` or
`APP_ENV` is `production`. Prisma loads local files only for development, without
mutating process.env; injected database settings override the whole local database
configuration. Production Prisma rejects a missing injected database target.
Use `NODE_ENV=production` and `APP_ENV=production` in Render AND the migration
runner. Inject the intended `DATABASE_URL`; inject `DIRECT_URL` only when it is
the intended direct/session endpoint of that SAME database. `DIRECT_URL` takes
precedence for migrations and TypeORM compatibility connections. Preserve required
`DB_SSL` and existing pooler settings. Do not copy local env files into a release.
Legacy maintenance/seed scripts have independent loaders: do not run them as
deployment steps. The approved migration commands below use prisma7.config.ts.

### Docker and Render

The Dockerfile has a separate `migrations` target containing the complete builder
toolchain, schema, migration SQL, config and config source dependencies. The final
`production` image remains an application runtime; migrations are never run at
image build or application startup. Build the migration image from the exact same
release as the runtime:

```sh
docker build --target migrations -t activ-partner-migrations:<release> .
docker build --target production -t activ-partner:<release> .
```

Run migration commands in an approved complete checkout (`npm ci`), or override
the migration image command to run status/deploy as below, injecting secrets
through the release platform. Never bake database secrets into image build args.
Docker packaging excludes root/nested env files and secret directories. Generated
Prisma JS and mail assets are included in the Nest output.

No Render Blueprint or live service configuration was accessed. Free/Docker/512 MB
was supplied by the user; confirm the root directory, Docker target and overrides.
Confirm
the service uses root `activ-backend`, runtime image target `production` (the final
default stage), and `node dist/main`/Docker CMD. Do not select `migrations` as the
web service target. Database token mode needs no mount or persistent disk. Free
services cannot attach one. Use a separate approved complete migration runner;
do not assume Free provides a pre-deploy command/shell, and do not run production
migrations at application startup. Verify database durability, backups, availability
and restart recovery independently of the disposable application filesystem.
Docker engine was unavailable locally: image build/runtime remains a release check.
See [Render disks](https://render.com/docs/disks),
[Docker deployment](https://render.com/docs/docker) and
[deployment stages](https://render.com/docs/deploys).

### Migration execution (operator actions, not performed on production)

1. Back up the database and deployment secrets using the approved process. Rehearse
   restoration. Pause venue approvals for the cutover window; preserve current
   provider credentials and do not start Gmail authorization yet.
2. In a clean, exact release runner, inject production flags and the verified
   database target. Confirm the host/database identity privately; do not print a
   connection string or credentials. Query `_prisma_migrations` read-only and compare
   prior migration names/checksums with release files. Resolve existing failed,
   missing, divergent or untracked history with the database owner before proceeding.
3. Run `npx --no-install prisma migrate status --config ./prisma7.config.ts`.
   Pending migrations give a nonzero status; inspect the result. Stop if anything
   other than the reviewed email/OAuth credential migrations is unexpectedly pending. Do not blindly
   baseline, use `db push`, `migrate reset` or `migrate dev` in production.
4. Run `npx --no-install prisma migrate deploy --config ./prisma7.config.ts` once
   from the approved runner, then repeat `migrate status`. Require no pending or
   failed migrations. Verify both additions have finished receipts, email indexes
   and status CHECK, and the credential table's unique identity/status/revision
   constraints exist. A repeat deploy
   should report no pending migrations. Prisma deploy is not a general drift check;
   validate the existing business schema separately. See
   [Prisma 7 migration CLI](https://www.prisma.io/docs/cli/v7/migrate).
5. Provision the stable delivery key, then deploy the matching code in legacy mode.
   Preserve the old token source/client until the approved consent window. When
   ready, configure database mode and its separate stable key, remove active source
   conflicts, and enable protected setup only for the verified consent window.
   The migration and key must precede accepting venue approvals. General delivery
   can remain `EMAIL_DELIVERY_ENABLED=false`: approval is still durable and sends
   immediately after commit. Background retries in legacy mode additionally need
   `EMAIL_DELIVERY_ENABLED=true` and `EMAIL_RETRY_WORKER_ENABLED=true`.
6. Check startup/health, sanitized delivery admin records, approval audit/activation
   consistency and logs. Reconcile historical inconsistent published venues and
   old-format delivery hashes before replaying anything. A real approval sends an
   immediate email: use only explicitly authorized test accounts/messages.
7. Complete mailbox consent, restart recovery and explicitly authorized Gmail tests
   before provider cutover. Drain/reconcile provider-bound pending jobs first, then
   enable retries and monitor FAILED/UNCERTAIN/PENDING counts and oldest queue age.

### Rollback

Stop the retry worker and pause approvals and Google-dependent legacy operations.
Preserve both additive tables, all metadata, both encryption keys and any old
env/file credential backups. Prefer a fixed release that supports database mode.
For rollback to pre-database code, restore the previously backed-up matching
client/token configuration through the approved secret manager; that old code will
ignore the new table. The Phase 5 release deliberately rejects env/file mode when
a matching database row exists: do not delete or export that row to bypass checks.
Database credentials cannot be used by older code without reviewed conversion or
new consent. Restore known-good credentials/code; do not drop tables or run a down
migration. A code/provider rollback does not undo a committed approval or sent mail.
Any release predating the consistency fix reintroduces the original approval bug:
keep approvals unavailable until a fixed release is restored. Reconcile SENT,
PROCESSING and UNCERTAIN outcomes against provider logs before any resend. Pending
jobs retain their original provider and must not be silently rerouted. Validate
health, credential recovery and password preservation before reopening operations.

### Encryption-key backup and rotation

Back up GOOGLE_REFRESH_TOKEN_STORAGE_KEY separately from database snapshots using
an audited secret manager with restricted access. Preserve EMAIL_DELIVERY_STORAGE_KEY
independently; rotating either key without re-encryption breaks its own records.
Never put keys/tokens into SQL history, command-line arguments, tickets or logs.
Missing/lost OAuth keys require restoring the original key or explicit new consent;
restoring the database alone cannot decrypt ciphertext.

For planned rotation, first rehearse on isolated data. Pause sends, workers, setup
and all other writers. Take a database/key backup. An audited maintenance process
must read/decrypt each credential in memory with the old key and re-encrypt using
the same associated-data identity and a fresh nonce under the new key, performing
revision-checked updates in one transaction. No plaintext intermediate files or
output are allowed. Deploy the new secret to every instance before reopening
traffic; restart and verify protected status. This release intentionally has no
remote key-rotation/token-export endpoint or automatic re-encryption at startup.
If rotation fails, retain traffic pause and restore the matching database/key
snapshot pair. Keep the old key protected until all retained backups expire.

## Verification performed in development

The earlier venue-approval fix passed 60 Jest suites / 429 tests, and environment
checks passed 61 suites / 434 tests. Phase 5 adds credential security, identity,
rotation, status authorization and MSG91 SMS regressions: **64 suites / 476 unit
tests passed**, plus **2 suites / 15 real PostgreSQL integration tests passed**.
Prisma schema validation
and `npm run build` (explicit Prisma 7 client generation followed by NestJS build)
passed. Commands run from `activ-backend`:

```text
node node_modules/jest/bin/jest.js --runInBand --no-cache --silent
node node_modules/prisma/build/index.js validate --config prisma7.config.ts
node node_modules/@nestjs/cli/bin/nest.js build
npm run build
npm run test:postgres
```

Run `npm test -- --runInBand` for existing and new mocked tests. The Jest setup
blocks external sockets/fetch and permits loopback HTTP for controller tests.
No real OAuth, mail, SMS or production database access was performed. The dedicated
integration command applies migrations only inside its newly created test cluster.

The approval regression suite uses real mail/outbox code with mocked transport and
an in-memory READ COMMITTED transaction harness with per-row locks and discarded
rollback writes. It covers failure at each transaction stage, preparation failure,
Gmail rejection/uncertain outcomes, unchanged-password retries, duplicate requests,
same/different-venue concurrent approvals, historical receipts and stale moderation.
That unit harness is separate from the real PostgreSQL integration suite below.

### Real PostgreSQL results and reproduction

All **15 PostgreSQL integration tests passed** on a newly initialized PostgreSQL
16.14 cluster, separate from the machine's existing PostgreSQL service. The actual
email delivery and OAuth credential migrations were applied by Prisma 7 `migrate deploy`; status and a
second no-op deploy were verified. Tests use the generated Prisma client and
PostgreSQL row locks, foreign keys, unique indexes and status CHECK constraint.
The suite verified full rollback on a late audit FK failure, encrypted-email
preparation rollback, same-venue and same-owner/different-venue concurrency,
credential/delivery deduplication, durable legacy approvals with general tracking
disabled, post-commit delivery failure/retry and recovery in a fresh OS process.
OAuth tests additionally verify actual encrypted persistence through the callback
service with mocked Google exchange/identity, fresh-process startup recovery, real
unique/revision concurrency, wrong-sender rejection, PostgreSQL read-only write
failure, tampering/wrong keys and stale invalid_grant protection. No real Google
authorization was initiated; tests construct synthetic consent URLs without opening
them. All transport/notification providers were mocked; no production database or
existing local service was used. The temporary cluster was stopped afterward.

```sh
npm ci
npm run prisma:generate
npm run test:postgres
```

Install PostgreSQL 16 binaries first. On Windows the runner defaults to
`C:\Program Files\PostgreSQL\16\bin`; Linux defaults to
`/usr/lib/postgresql/16/bin`. Set `PG_BIN` to another installed binary directory
if needed. Run as an unprivileged account allowed to execute initdb/pg_ctl and
write temporary files. Windows sandbox restricted-token rules may require running
this local test command outside that sandbox. Docker is not required.

The runner creates a new temporary data directory, selects a free loopback port,
binds only 127.0.0.1, creates `activ_integration_test` under `activ_integration`,
and uses temporary trust auth without reusable credentials. It ignores existing
DATABASE_URL/DB_* targets, explicitly injects its synthetic URL and places a random
guard marker checked by the suite and recovery subprocess. Do not run the Jest
integration config directly or supply a production URL. External sockets are
blocked by the test setup; delivery uses mocked providers. Data/logs remain in the
printed temporary directory for inspection; pg_ctl stops only that new cluster.
If initdb/startup is unavailable, the command fails rather than skipping or passing.

**Migration coverage limit:** the runner generates a synthetic prior schema from
the current schema minus `email_deliveries` and `google_oauth_credentials`, using the reference functions from
the repository migrations, and explicitly marks prior migrations applied in that
DISPOSABLE database. It does not replay missing initial history, validate every
historical SQL operation, or prove compatibility with the live production schema.
Review production migration receipts/checksums and rehearse on an approved,
sanitized staging schema separately. No automatic production baseline/resolve is
authorized. Docker image build, live Render configuration/memory verification and
mailbox authorization remain pending release gates.

Sources: [Google profile scope requirements](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users/getProfile),
[OpenID identity claims](https://developers.google.com/identity/openid-connect/openid-connect),
[Render Free limitations](https://render.com/docs/free) and
[Render Docker deployments](https://render.com/docs/docker).

## Phase 5 files

```text
.env.example
prisma/schema.prisma
prisma/migrations/20261029010000_google_oauth_credentials/migration.sql
src/modules/mail/google-credential.store.ts
src/modules/mail/google-credential.store.spec.ts
src/modules/mail/google-oauth.service.ts
src/modules/mail/google-oauth.service.spec.ts
src/modules/mail/google-oauth-database.spec.ts
src/modules/mail/email-admin-access.spec.ts
src/modules/mail/mail.module.ts
src/modules/auth/auth.controller.ts
src/modules/otp/otp-sms-regression.spec.ts
scripts/run-postgres-integration.cjs
test/postgres/google-credential.integration.spec.ts
test/postgres/restart-google-worker.cjs
docs/GMAIL_PRODUCTION_RUNBOOK.md
docs/GOOGLE_OAUTH_SETUP.md
```

## Cumulative Gmail development files (including earlier phases)

```text
activ-backend/.dockerignore
activ-backend/.env.example
activ-backend/docs/GMAIL_PRODUCTION_RUNBOOK.md
activ-backend/docs/GOOGLE_OAUTH_SETUP.md
activ-backend/docs/signed-agreement-msg91.md
activ-backend/package.json
activ-backend/Dockerfile
activ-backend/prisma7.config.ts
activ-backend/src/app.module.ts
activ-backend/src/config/environment.ts
activ-backend/src/config/environment.spec.ts
activ-backend/scripts/run-postgres-integration.cjs
activ-backend/test/postgres/jest.config.cjs
activ-backend/test/postgres/venue-approval.integration.spec.ts
activ-backend/test/postgres/restart-worker.cjs
activ-backend/prisma/migrations/20261029000000_email_deliveries/migration.sql
activ-backend/prisma/schema.prisma
activ-backend/src/modules/auth/auth-team-login.spec.ts
activ-backend/src/modules/auth/auth.controller.ts
activ-backend/src/modules/auth/auth.service.ts
activ-backend/src/modules/bank-accounts/bank-accounts.service.ts
activ-backend/src/modules/mail/email-admin-access.spec.ts
activ-backend/src/modules/mail/email-deliveries.controller.ts
activ-backend/src/modules/mail/email-delivery.service.spec.ts
activ-backend/src/modules/mail/email-delivery.service.ts
activ-backend/src/modules/mail/email-job.ts
activ-backend/src/modules/mail/email-routing.spec.ts
activ-backend/src/modules/mail/google-oauth.service.spec.ts
activ-backend/src/modules/mail/google-oauth.service.ts
activ-backend/src/modules/mail/google-credential.store.ts
activ-backend/src/modules/mail/google-credential.store.spec.ts
activ-backend/src/modules/mail/google-oauth-database.spec.ts
activ-backend/src/modules/otp/otp-sms-regression.spec.ts
activ-backend/prisma/migrations/20261029010000_google_oauth_credentials/migration.sql
activ-backend/test/postgres/google-credential.integration.spec.ts
activ-backend/test/postgres/restart-google-worker.cjs
activ-backend/src/modules/mail/legacy-mail.service.ts
activ-backend/src/modules/mail/mail.module.ts
activ-backend/src/modules/mail/mail.service.ts
activ-backend/src/modules/mail/partner-email.service.ts
activ-backend/src/modules/mail/templates/partner-email.ts
activ-backend/src/modules/partners/partner-suspension-email.spec.ts
activ-backend/src/modules/partners/partners.service.ts
activ-backend/src/modules/support/support-email-status.spec.ts
activ-backend/src/modules/support/support.service.ts
activ-backend/src/modules/venues/activity-review-flow.spec.ts
activ-backend/src/modules/venues/approval-email-retry.spec.ts
activ-backend/src/modules/venues/venue-request-changes.spec.ts
activ-backend/src/modules/venues/venue-suspension-email.spec.ts
activ-backend/src/modules/venues/venues.service.ts
activ-backend/test/no-network.cjs
```
