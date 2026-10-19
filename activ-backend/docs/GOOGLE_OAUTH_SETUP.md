# Gmail OAuth 2.0 setup

The backend exposes a setup-only OAuth flow. Flutter does not participate in Gmail authorization.

## Environment

Set these in the untracked backend `.env` or Render environment settings:

```env
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_REDIRECT_URI=http://localhost:3000/api/v1/auth/google/callback
GOOGLE_REFRESH_TOKEN=
GOOGLE_SENDER_EMAIL=jangidlucky444@gmail.com
GOOGLE_OAUTH_SETUP_ENABLED=false
GOOGLE_OAUTH_SETUP_KEY=
GOOGLE_REFRESH_TOKEN_STORAGE_KEY=
GOOGLE_REFRESH_TOKEN_FILE=./.secrets/google-refresh-token.enc
```

For production, use:

```env
GOOGLE_REDIRECT_URI=https://activ-partner.onrender.com/api/v1/auth/google/callback
GOOGLE_SENDER_EMAIL=support@activ.live
```

Register the exact redirect URI in Google Cloud Console. The setup key must be a random value of at least 32 characters and must never be committed.

## Authorize

1. Set `GOOGLE_OAUTH_SETUP_ENABLED=true` temporarily and restart the backend.
2. Sign in as an admin and obtain an admin JWT.
3. Open `GET /api/v1/auth/google/connect` with the bearer token and header `x-google-oauth-setup-key`.
4. Complete consent using the Gmail account that exactly matches `GOOGLE_SENDER_EMAIL`.
5. The callback validates the one-time state, exchanges the code, binds the grant to the configured sender account, and never places tokens in the browser response or logs. Because `gmail.send` does not grant Gmail profile-read permission, the owner must ensure the consent account is the configured sender.
6. Configure `GOOGLE_REFRESH_TOKEN` in the protected environment, or configure `GOOGLE_REFRESH_TOKEN_STORAGE_KEY` (32+ random characters) so the callback stores the token encrypted at `GOOGLE_REFRESH_TOKEN_FILE`. Do not commit that file. Then set setup back to `false` and restart.

The OAuth state is one-time and expires after ten minutes. The requested scope is only `gmail.send`. Gmail API provider acceptance means Google accepted the message; it does not guarantee inbox delivery.

## Test email

Set `GOOGLE_TEST_RECIPIENT` to an explicitly approved test address, then run from `activ-backend`:

```sh
node scripts/send-gmail-test.cjs --confirm
```

The script prints only the Gmail message ID, never the token or message contents.

## Testing-mode limitation

An External OAuth app in Google Testing status can issue refresh tokens that expire after seven days. For stable production use, complete Google OAuth verification as required, publish the consent screen, and ensure the Workspace account/domain is authorized for the requested scope. A personal Gmail authorization does not authorize sending as `support@activ.live`; that account must authorize the grant and the sender must be configured accordingly.
