BEGIN;

ALTER TABLE public.partner_payouts
  DROP CONSTRAINT partner_payouts_partner_id_fkey;

ALTER TABLE public.partner_payouts
  ADD CONSTRAINT partner_payouts_partner_id_fkey
  FOREIGN KEY (partner_id)
  REFERENCES public.partners(id)
  ON DELETE RESTRICT
  ON UPDATE CASCADE;

ALTER TABLE public.partner_payouts
  DROP CONSTRAINT partner_payouts_bank_account_id_fkey;

ALTER TABLE public.partner_payouts
  ADD CONSTRAINT partner_payouts_bank_account_id_fkey
  FOREIGN KEY (bank_account_id)
  REFERENCES public.partner_bank_accounts(id)
  ON DELETE SET NULL
  ON UPDATE CASCADE;

COMMIT;
