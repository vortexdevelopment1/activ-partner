CREATE TABLE IF NOT EXISTS "booking_reference_sequences" (
  "sequence_date" DATE NOT NULL,
  "last_number" INTEGER NOT NULL,
  CONSTRAINT "booking_reference_sequences_pkey" PRIMARY KEY ("sequence_date"),
  CONSTRAINT "booking_reference_sequences_last_number_check" CHECK ("last_number" > 0)
);

ALTER TABLE "bookings"
  ADD COLUMN IF NOT EXISTS "booking_reference" TEXT;

WITH ranked AS (
  SELECT
    "id",
    TO_CHAR("created_at" AT TIME ZONE 'Asia/Kolkata', 'YYMMDD') AS date_key,
    ROW_NUMBER() OVER (
      PARTITION BY DATE("created_at" AT TIME ZONE 'Asia/Kolkata')
      ORDER BY "created_at", "id"
    ) AS sequence_number
  FROM "bookings"
  WHERE "booking_reference" IS NULL
)
UPDATE "bookings" AS booking
SET "booking_reference" =
  'ACT-' || ranked.date_key || '-' || LPAD(ranked.sequence_number::TEXT, 4, '0')
FROM ranked
WHERE booking."id" = ranked."id";

INSERT INTO "booking_reference_sequences" ("sequence_date", "last_number")
SELECT
  TO_DATE('20' || SUBSTRING("booking_reference" FROM 5 FOR 6), 'YYYYMMDD'),
  MAX(CAST(SUBSTRING("booking_reference" FROM 12) AS INTEGER))
FROM "bookings"
WHERE "booking_reference" ~ '^ACT-[0-9]{6}-[0-9]+$'
GROUP BY TO_DATE('20' || SUBSTRING("booking_reference" FROM 5 FOR 6), 'YYYYMMDD')
ON CONFLICT ("sequence_date") DO UPDATE
SET "last_number" = GREATEST(
  "booking_reference_sequences"."last_number",
  EXCLUDED."last_number"
);

ALTER TABLE "bookings"
  ALTER COLUMN "booking_reference" SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "bookings_booking_reference_key"
  ON "bookings" ("booking_reference");

CREATE OR REPLACE FUNCTION generate_booking_reference()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  business_date DATE := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;
  date_key TEXT := TO_CHAR(business_date, 'YYMMDD');
  next_number INTEGER;
BEGIN
  INSERT INTO "booking_reference_sequences" ("sequence_date", "last_number")
  VALUES (business_date, 1)
  ON CONFLICT ("sequence_date")
  DO UPDATE SET "last_number" = "booking_reference_sequences"."last_number" + 1
  RETURNING "last_number" INTO next_number;

  RETURN 'ACT-' || date_key || '-' || LPAD(next_number::TEXT, 4, '0');
END;
$$;

ALTER TABLE "bookings"
  ALTER COLUMN "booking_reference" SET DEFAULT generate_booking_reference();
