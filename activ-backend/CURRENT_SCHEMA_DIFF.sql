-- DropForeignKey
ALTER TABLE "partner_payouts" DROP CONSTRAINT "partner_payouts_bank_account_id_fkey";

-- DropForeignKey
ALTER TABLE "partner_payouts" DROP CONSTRAINT "partner_payouts_partner_id_fkey";

-- DropIndex
DROP INDEX "bookings_status_payment_deadline_idx";

-- DropTable
DROP TABLE "booking_reference_sequences";

-- DropTable
DROP TABLE "migrations";

-- DropTable
DROP TABLE "partner_schema_migrations";

-- RenameForeignKey
ALTER TABLE "bookings" RENAME CONSTRAINT "bookings_user_id_fkey" TO "FK_64cd97487c5c42806458ab5520c";

-- RenameForeignKey
ALTER TABLE "partner_notification_preferences" RENAME CONSTRAINT "partner_notification_preferences_partner_id_fkey" TO "FK_65d58cceac8173a64699dc7b5b9";

-- RenameForeignKey
ALTER TABLE "payments" RENAME CONSTRAINT "payments_booking_id_fkey" TO "FK_e86edf76dc2424f123b9023a2b2";

-- RenameForeignKey
ALTER TABLE "reviews" RENAME CONSTRAINT "reviews_user_id_fkey" TO "FK_728447781a30bc3fcfe5c2f1cdf";

-- RenameForeignKey
ALTER TABLE "venues" RENAME CONSTRAINT "venues_partner_id_fkey" TO "FK_138a0fe0060464fb15d4cda5bc6";

-- AddForeignKey
ALTER TABLE "partner_payouts" ADD CONSTRAINT "partner_payouts_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "partners"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_payouts" ADD CONSTRAINT "partner_payouts_bank_account_id_fkey" FOREIGN KEY ("bank_account_id") REFERENCES "partner_bank_accounts"("id") ON DELETE SET NULL ON UPDATE CASCADE;
