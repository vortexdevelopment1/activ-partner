ALTER TABLE "partner_city_commissions" ADD COLUMN "state_code" TEXT;
CREATE INDEX "partner_city_commissions_state_code_idx" ON "partner_city_commissions" ("state_code");
