-- Public references are additive display identifiers. UUID primary keys and
-- all existing foreign-key/API identifiers remain unchanged.
CREATE SEQUENCE IF NOT EXISTS venue_public_reference_seq AS BIGINT START WITH 1;
CREATE SEQUENCE IF NOT EXISTS activity_public_reference_seq AS BIGINT START WITH 1;
ALTER SEQUENCE venue_public_reference_seq NO CYCLE MAXVALUE 9223372036854775807;
ALTER SEQUENCE activity_public_reference_seq NO CYCLE MAXVALUE 9223372036854775807;

CREATE OR REPLACE FUNCTION generate_venue_reference()
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE seq_num BIGINT;
BEGIN
  seq_num := nextval('venue_public_reference_seq'::regclass);
  RETURN 'VEN-' || lpad(seq_num::text, GREATEST(6, length(seq_num::text)), '0');
END;
$$;

CREATE OR REPLACE FUNCTION generate_activity_reference()
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE seq_num BIGINT;
BEGIN
  seq_num := nextval('activity_public_reference_seq'::regclass);
  RETURN 'ACTV-' || lpad(seq_num::text, GREATEST(6, length(seq_num::text)), '0');
END;
$$;

ALTER TABLE "venues" ADD COLUMN IF NOT EXISTS "public_reference" VARCHAR(32);
ALTER TABLE "partner_venue_services" ADD COLUMN IF NOT EXISTS "public_reference" VARCHAR(32);

-- Synchronize before filling NULLs. The third setval argument is false when
-- there are no valid references, so the first generated value is 000001.
SELECT setval(
  'venue_public_reference_seq'::regclass,
  COALESCE((SELECT max(substring("public_reference" from 5)::bigint) FROM "venues" WHERE "public_reference" ~ '^VEN-[0-9]+$'), 1),
  COALESCE((SELECT max(substring("public_reference" from 5)::bigint) FROM "venues" WHERE "public_reference" ~ '^VEN-[0-9]+$'), 0) > 0
);
SELECT setval(
  'activity_public_reference_seq'::regclass,
  COALESCE((SELECT max(substring("public_reference" from 6)::bigint) FROM "partner_venue_services" WHERE "public_reference" ~ '^ACTV-[0-9]+$'), 1),
  COALESCE((SELECT max(substring("public_reference" from 6)::bigint) FROM "partner_venue_services" WHERE "public_reference" ~ '^ACTV-[0-9]+$'), 0) > 0
);

-- Existing non-NULL values, including valid references, are untouched.
UPDATE "venues"
SET "public_reference" = generate_venue_reference()
WHERE "public_reference" IS NULL;

UPDATE "partner_venue_services"
SET "public_reference" = generate_activity_reference()
WHERE "public_reference" IS NULL;

ALTER TABLE "venues" ALTER COLUMN "public_reference" SET DEFAULT generate_venue_reference();
ALTER TABLE "partner_venue_services" ALTER COLUMN "public_reference" SET DEFAULT generate_activity_reference();
ALTER TABLE "venues" ALTER COLUMN "public_reference" SET NOT NULL;
ALTER TABLE "partner_venue_services" ALTER COLUMN "public_reference" SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "venues_public_reference_key" ON "venues"("public_reference");
CREATE UNIQUE INDEX IF NOT EXISTS "partner_venue_services_public_reference_key" ON "partner_venue_services"("public_reference");
