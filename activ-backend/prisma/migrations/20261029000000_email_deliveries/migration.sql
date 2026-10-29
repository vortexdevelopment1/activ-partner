CREATE TABLE "email_deliveries" (
  "id" UUID NOT NULL,
  "idempotency_key" TEXT NOT NULL,
  "provider" TEXT NOT NULL,
  "kind" TEXT NOT NULL,
  "payload" TEXT,
  "status" TEXT NOT NULL DEFAULT 'PENDING',
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "next_attempt_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "locked_at" TIMESTAMP(3),
  "expires_at" TIMESTAMP(3),
  "provider_message_id" TEXT,
  "error_code" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "sent_at" TIMESTAMP(3),
  CONSTRAINT "email_deliveries_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "email_deliveries_status_check" CHECK ("status" IN ('PENDING','PROCESSING','RETRY','SENT','FAILED','UNCERTAIN','EXPIRED'))
);
CREATE UNIQUE INDEX "email_deliveries_idempotency_key_key" ON "email_deliveries"("idempotency_key");
CREATE INDEX "email_deliveries_status_next_attempt_at_idx" ON "email_deliveries"("status", "next_attempt_at");
