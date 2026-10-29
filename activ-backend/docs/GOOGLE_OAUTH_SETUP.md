# Gmail OAuth setup

Use [Gmail production runbook](./GMAIL_PRODUCTION_RUNBOOK.md) for provider migration, persistent token storage, protected authorization, delivery retries and rollback.

Production callback: `https://activ-partner.onrender.com/api/v1/auth/google/callback`.
Required sender: `support@activ.live`.

A successful new callback confirms verified primary Google account identity and encrypted token persistence. Setup now requests `openid email gmail.send` and requires fresh consent. The sender must be the primary Workspace account `support@activ.live`; aliases/groups are rejected. Old env/file tokens are not retroactively verified. No token is exposed by the setup API.

Render Free uses `GOOGLE_TOKEN_SOURCE=database`, the additive credential migration and a stable separate `GOOGLE_REFRESH_TOKEN_STORAGE_KEY`; no persistent disk is required. Unset env/file token sources before an explicitly approved cutover. Keep setup disabled and EMAIL_PROVIDER=legacy until authorization is completed. Read sanitized metadata with admin-only `GET /api/v1/auth/google/status`.
