BEGIN;

SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '5min';

LOCK TABLE "partner_walk_in_reservations" IN SHARE ROW EXCLUSIVE MODE;

CREATE TABLE IF NOT EXISTS "walk_in_booking_reference_sequences" (
  "sequence_date" DATE NOT NULL,
  "last_number" INTEGER NOT NULL,
  CONSTRAINT "walk_in_booking_reference_sequences_pkey" PRIMARY KEY ("sequence_date"),
  CONSTRAINT "walk_in_booking_reference_sequences_last_number_check" CHECK ("last_number" > 0)
);

ALTER TABLE "partner_walk_in_reservations"
  ADD COLUMN IF NOT EXISTS "booking_reference" TEXT;

WITH ranked AS (
  SELECT
    "id",
    TO_CHAR(("created_at" AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Kolkata', 'YYYYMMDD') AS date_key,
    ROW_NUMBER() OVER (
      PARTITION BY DATE(("created_at" AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Kolkata')
      ORDER BY "created_at", "id"
    ) AS sequence_number
  FROM "partner_walk_in_reservations"
  WHERE "booking_reference" IS NULL
)
UPDATE "partner_walk_in_reservations" AS reservation
SET "booking_reference" =
  'WI-' || ranked.date_key || '-' || LPAD(
    ranked.sequence_number::TEXT,
    GREATEST(4, LENGTH(ranked.sequence_number::TEXT)),
    '0'
  )
FROM ranked
WHERE reservation."id" = ranked."id";

INSERT INTO "walk_in_booking_reference_sequences" ("sequence_date", "last_number")
SELECT
  TO_DATE(SUBSTRING("booking_reference" FROM 4 FOR 8), 'YYYYMMDD'),
  MAX(CAST(SUBSTRING("booking_reference" FROM 13) AS INTEGER))
FROM "partner_walk_in_reservations"
WHERE "booking_reference" ~ '^WI-[0-9]{8}-[0-9]+$'
GROUP BY TO_DATE(SUBSTRING("booking_reference" FROM 4 FOR 8), 'YYYYMMDD')
ON CONFLICT ("sequence_date") DO UPDATE
SET "last_number" = GREATEST(
  "walk_in_booking_reference_sequences"."last_number",
  EXCLUDED."last_number"
);

ALTER TABLE "partner_walk_in_reservations"
  ALTER COLUMN "booking_reference" SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "partner_walk_in_reservations_booking_reference_key"
  ON "partner_walk_in_reservations" ("booking_reference");

CREATE OR REPLACE FUNCTION generate_walk_in_booking_reference()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  business_date DATE := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;
  date_key TEXT := TO_CHAR(business_date, 'YYYYMMDD');
  next_number INTEGER;
BEGIN
  INSERT INTO "walk_in_booking_reference_sequences" ("sequence_date", "last_number")
  VALUES (business_date, 1)
  ON CONFLICT ("sequence_date")
  DO UPDATE SET "last_number" = "walk_in_booking_reference_sequences"."last_number" + 1
  RETURNING "last_number" INTO next_number;

  RETURN 'WI-' || date_key || '-' || LPAD(
    next_number::TEXT,
    GREATEST(4, LENGTH(next_number::TEXT)),
    '0'
  );
END;
$$;

ALTER TABLE "partner_walk_in_reservations"
  ALTER COLUMN "booking_reference" SET DEFAULT generate_walk_in_booking_reference();

COMMIT;
