CREATE TABLE "google_oauth_credentials" (
  "id" UUID NOT NULL,
  "provider" TEXT NOT NULL,
  "sender" TEXT NOT NULL,
  "client_fingerprint" TEXT NOT NULL,
  "account_subject" TEXT NOT NULL,
  "encrypted_refresh_token" TEXT NOT NULL,
  "status" TEXT NOT NULL,
  "version" INTEGER NOT NULL DEFAULT 1,
  "verified_at" TIMESTAMP(3) NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "google_oauth_credentials_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "google_oauth_credentials_status_check" CHECK ("status" IN ('VERIFIED', 'REAUTH_REQUIRED')),
  CONSTRAINT "google_oauth_credentials_version_check" CHECK ("version" > 0),
  CONSTRAINT "google_oauth_credentials_identity_check" CHECK ("provider" = 'gmail' AND "sender" = lower("sender") AND length("sender") > 0 AND length("account_subject") > 0)
);
CREATE UNIQUE INDEX "google_oauth_credentials_provider_sender_key" ON "google_oauth_credentials"("provider", "sender");
