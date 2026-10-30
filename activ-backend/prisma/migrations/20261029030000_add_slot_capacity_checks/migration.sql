-- Production already has equivalent, stronger named checks. Verify them and
-- do not add duplicate constraints under new names.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'slots_booked_quantity_valid')
     OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'slots_capacity_positive')
     OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'slots_time_order') THEN
    RAISE EXCEPTION 'Expected production slot capacity constraints are missing; review before applying';
  END IF;
END $$;
