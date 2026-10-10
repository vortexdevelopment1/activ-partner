DO $$ BEGIN
  CREATE TYPE "PartnerPayoutStatus" AS ENUM ('PENDING', 'SUCCESS', 'FAILED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS partner_payouts (
  id UUID PRIMARY KEY,
  partner_id UUID NOT NULL REFERENCES partners(id),
  bank_account_id UUID REFERENCES partner_bank_accounts(id),
  reference TEXT NOT NULL UNIQUE,
  amount_paise BIGINT NOT NULL CHECK (amount_paise > 0),
  status "PartnerPayoutStatus" NOT NULL DEFAULT 'PENDING',
  payout_date TIMESTAMP(3) NOT NULL,
  failure_reason TEXT,
  created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP(3) NOT NULL
);
CREATE INDEX IF NOT EXISTS partner_payouts_partner_id_payout_date_idx ON partner_payouts(partner_id, payout_date);
CREATE INDEX IF NOT EXISTS partner_payouts_partner_id_status_payout_date_idx ON partner_payouts(partner_id, status, payout_date);
