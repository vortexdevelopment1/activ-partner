-- Capacity safety constraints for normalized slots.
-- Apply through reviewed migration tooling; do not use db push as a substitute.
ALTER TABLE "slots"
  ADD CONSTRAINT "slots_capacity_nonnegative_check"
  CHECK ("capacity" >= 0);

ALTER TABLE "slots"
  ADD CONSTRAINT "slots_booked_quantity_nonnegative_check"
  CHECK ("booked_quantity" >= 0);

ALTER TABLE "slots"
  ADD CONSTRAINT "slots_booked_quantity_capacity_check"
  CHECK ("booked_quantity" <= "capacity");
