ALTER TABLE "slots" ADD CONSTRAINT "slots_time_order" CHECK ("ends_at" > "starts_at");
ALTER TABLE "slots" ADD CONSTRAINT "slots_capacity_positive" CHECK ("capacity" > 0);
ALTER TABLE "slots" ADD CONSTRAINT "slots_booked_quantity_valid" CHECK ("booked_quantity" >= 0 AND "booked_quantity" <= "capacity");
ALTER TABLE "facilities" ADD CONSTRAINT "facilities_capacity_positive" CHECK ("capacity" > 0);
ALTER TABLE "payments" ADD CONSTRAINT "payments_amount_non_negative" CHECK ("amount_paise" >= 0);
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_amounts_non_negative" CHECK ("subtotal_paise" >= 0 AND "discount_paise" >= 0 AND "total_paise" >= 0);
ALTER TABLE "booking_attempts" ADD CONSTRAINT "booking_attempts_quantity_positive" CHECK ("quantity" > 0);
ALTER TABLE "coupons" ADD CONSTRAINT "coupons_dates_valid" CHECK ("ends_at" > "starts_at");
ALTER TABLE "coupons" ADD CONSTRAINT "coupons_discount_valid" CHECK (("percent_off" IS NOT NULL AND "percent_off" BETWEEN 1 AND 100) OR ("amount_off_paise" IS NOT NULL AND "amount_off_paise" > 0));
