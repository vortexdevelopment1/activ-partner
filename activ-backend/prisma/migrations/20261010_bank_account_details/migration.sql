ALTER TABLE partner_bank_accounts
  ADD COLUMN IF NOT EXISTS account_type TEXT,
  ADD COLUMN IF NOT EXISTS branch_name TEXT,
  ADD COLUMN IF NOT EXISTS cancelled_cheque_url TEXT,
  ADD COLUMN IF NOT EXISTS has_seen_verified_screen BOOLEAN NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS partner_bank_accounts_one_pending
  ON partner_bank_accounts(partner_id) WHERE status = 'UNDER_REVIEW';
