-- AlterTable
ALTER TABLE "venues" ADD COLUMN     "approved_at" TIMESTAMP(3),
ADD COLUMN     "approved_by" UUID,
ADD COLUMN     "booking_accept" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "commission_percent" DECIMAL(7,4),
ADD COLUMN     "has_seen_welcome" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "rejection_reason" TEXT,
ADD COLUMN     "review_status" TEXT,
ADD COLUMN     "submitted_at" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "partner_venue_images" ADD COLUMN     "is_cover" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "venue_service_id" UUID;

-- AlterTable
ALTER TABLE "partner_venue_profiles" ADD COLUMN     "closing_time" TEXT,
ADD COLUMN     "electronic_signature" TEXT,
ADD COLUMN     "location_url" TEXT,
ADD COLUMN     "opening_time" TEXT,
ADD COLUMN     "owner_phone_e164" TEXT,
ADD COLUMN     "rules" TEXT;

-- AlterTable
ALTER TABLE "partner_venue_services" ADD COLUMN     "capacity" INTEGER,
ADD COLUMN     "is_active" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "max_duration_minutes" INTEGER,
ADD COLUMN     "min_duration_minutes" INTEGER,
ADD COLUMN     "pause_reason" TEXT,
ADD COLUMN     "submitted_at" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "partner_venue_amenities" (
    "venue_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "partner_venue_amenities_pkey" PRIMARY KEY ("venue_id","title")
);

-- CreateTable
CREATE TABLE "partner_service_amenities" (
    "venue_service_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "partner_service_amenities_pkey" PRIMARY KEY ("venue_service_id","title")
);

-- CreateTable
CREATE TABLE "partner_venue_availability" (
    "id" UUID NOT NULL,
    "venue_id" UUID NOT NULL,
    "service_category_id" UUID NOT NULL,
    "day" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "open_time" TEXT NOT NULL,
    "close_time" TEXT NOT NULL,
    "capacity" INTEGER NOT NULL DEFAULT 0,
    "price_paise" BIGINT NOT NULL DEFAULT 0,
    "discounted_price_paise" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "partner_venue_availability_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "partner_venue_legal_documents" (
    "venue_id" UUID NOT NULL,
    "aadhaar_name" TEXT,
    "aadhaar_number" TEXT,
    "aadhaar_card_url" TEXT,
    "pan_number" TEXT,
    "pan_card_url" TEXT,
    "gst_number" TEXT,
    "gst_name" TEXT,
    "gstin_doc_url" TEXT,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_venue_legal_documents_pkey" PRIMARY KEY ("venue_id")
);

-- CreateTable
CREATE TABLE "partner_service_paused_slots" (
    "venue_service_id" UUID NOT NULL,
    "slot_id" UUID NOT NULL,

    CONSTRAINT "partner_service_paused_slots_pkey" PRIMARY KEY ("venue_service_id","slot_id")
);

-- CreateIndex
CREATE INDEX "partner_venue_availability_service_category_id_day_idx" ON "partner_venue_availability"("service_category_id", "day");

-- CreateIndex
CREATE UNIQUE INDEX "partner_venue_availability_venue_id_service_category_id_day_key" ON "partner_venue_availability"("venue_id", "service_category_id", "day", "sort_order");

-- CreateIndex
CREATE INDEX "partner_service_paused_slots_slot_id_idx" ON "partner_service_paused_slots"("slot_id");

-- CreateIndex
CREATE INDEX "partner_venue_images_venue_service_id_sort_order_idx" ON "partner_venue_images"("venue_service_id", "sort_order");

-- AddForeignKey
ALTER TABLE "partner_venue_images" ADD CONSTRAINT "partner_venue_images_venue_service_id_fkey" FOREIGN KEY ("venue_service_id") REFERENCES "partner_venue_services"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_amenities" ADD CONSTRAINT "partner_venue_amenities_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "venues"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_service_amenities" ADD CONSTRAINT "partner_service_amenities_venue_service_id_fkey" FOREIGN KEY ("venue_service_id") REFERENCES "partner_venue_services"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_availability" ADD CONSTRAINT "partner_venue_availability_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "venues"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_availability" ADD CONSTRAINT "partner_venue_availability_service_category_id_fkey" FOREIGN KEY ("service_category_id") REFERENCES "partner_service_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_venue_legal_documents" ADD CONSTRAINT "partner_venue_legal_documents_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "venues"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_service_paused_slots" ADD CONSTRAINT "partner_service_paused_slots_venue_service_id_fkey" FOREIGN KEY ("venue_service_id") REFERENCES "partner_venue_services"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_service_paused_slots" ADD CONSTRAINT "partner_service_paused_slots_slot_id_fkey" FOREIGN KEY ("slot_id") REFERENCES "slots"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- Keep source JSON intact for rollback and audit; application reads now use these tables.
UPDATE venues SET
  booking_accept = COALESCE((metadata->>'bookingAccept')::boolean, true),
  has_seen_welcome = COALESCE((metadata->>'hasSeenWelcome')::boolean, false),
  commission_percent = NULLIF(metadata->>'commission', '')::numeric,
  submitted_at = NULLIF(metadata->>'submittedAt', '')::timestamp,
  approved_at = NULLIF(metadata->>'approvedAt', '')::timestamp,
  approved_by = NULLIF(metadata->>'approvedBy', '')::uuid,
  review_status = metadata->>'reviewStatus',
  rejection_reason = metadata->>'rejectionReason';

INSERT INTO partner_venue_profiles (id, venue_id, partner_id, display_name, updated_at)
SELECT gen_random_uuid(), id, partner_id, name, now() FROM venues
ON CONFLICT (venue_id) DO NOTHING;

UPDATE partner_venue_profiles p SET
  opening_time = COALESCE(v.metadata->>'openingTime', p.operating_hours->>'openingTime'),
  closing_time = COALESCE(v.metadata->>'closingTime', p.operating_hours->>'closingTime'),
  rules = v.metadata->>'rules', location_url = v.metadata->>'locationUrl',
  owner_phone_e164 = v.metadata->>'ownerPhone',
  electronic_signature = v.metadata->>'electronicSignature'
FROM venues v WHERE v.id = p.venue_id;

INSERT INTO partner_venue_amenities (venue_id, title, sort_order)
SELECT p.venue_id, a.title, (a.n - 1)::int FROM partner_venue_profiles p,
LATERAL jsonb_array_elements_text(p.amenities::jsonb) WITH ORDINALITY a(title, n)
WHERE a.title <> '' ON CONFLICT DO NOTHING;

INSERT INTO partner_venue_legal_documents
(venue_id, aadhaar_name, aadhaar_number, aadhaar_card_url, pan_number, pan_card_url, gst_number, gst_name, gstin_doc_url, updated_at)
SELECT id, metadata->'legalInfo'->>'aadhaarName', metadata->'legalInfo'->>'aadhaarNumber',
metadata->'legalInfo'->>'aadhaarCardUrl', metadata->'legalInfo'->>'panNumber',
metadata->'legalInfo'->>'panCardUrl', metadata->'legalInfo'->>'gstNumber',
metadata->'legalInfo'->>'gstName', metadata->'legalInfo'->>'gstinDocUrl', now()
FROM venues WHERE metadata->'legalInfo' IS NOT NULL ON CONFLICT DO NOTHING;

UPDATE partner_venue_services SET
  is_active = COALESCE((onboarding_data->>'isActive')::boolean, true),
  pause_reason = onboarding_data->>'pauseReason',
  submitted_at = NULLIF(onboarding_data->>'submittedAt', '')::timestamp;

-- Original create payloads also kept pricing and capacity in metadata.services.
UPDATE partner_venue_services s SET
  description = COALESCE(j.value->>'description', s.description),
  price_per_hour_paise = COALESCE(round(NULLIF(j.value->>'pricePerHour', '')::numeric * 100)::bigint, s.price_per_hour_paise),
  min_duration_minutes = NULLIF(j.value->>'minDuration', '')::int,
  max_duration_minutes = NULLIF(j.value->>'maxDuration', '')::int,
  capacity = NULLIF(j.value->>'capacity', '')::int
FROM venues v, LATERAL jsonb_array_elements(COALESCE(v.metadata->'services', '[]'::jsonb)) j(value)
WHERE s.venue_id = v.id AND lower(s.title) = lower(j.value->>'name');

INSERT INTO partner_service_amenities (venue_service_id, title, sort_order)
SELECT s.id, a.title, (a.n - 1)::int FROM partner_venue_services s
LEFT JOIN partner_venue_profiles p ON p.venue_id = s.venue_id,
LATERAL jsonb_array_elements_text(COALESCE(s.onboarding_data->'amenities', p.amenities::jsonb, '[]'::jsonb))
WITH ORDINALITY a(title, n) WHERE a.title <> '' ON CONFLICT DO NOTHING;

-- Link existing activity photos first, then add JSON-only URLs without duplicating them.
UPDATE partner_venue_images i SET venue_service_id = s.id,
  is_cover = COALESCE(i.url = COALESCE(s.onboarding_data->>'coverImageUrl', s.onboarding_data->'imageUrls'->>0), false)
FROM partner_venue_services s WHERE i.venue_id = s.venue_id
AND i.metadata->>'serviceId' = s.id::text;

INSERT INTO partner_venue_images (id, venue_id, venue_service_id, url, sort_order, is_cover, updated_at)
SELECT gen_random_uuid(), s.venue_id, s.id, image.url, (image.n - 1)::int,
image.url = COALESCE(s.onboarding_data->>'coverImageUrl', s.onboarding_data->'imageUrls'->>0), now()
FROM partner_venue_services s,
LATERAL jsonb_array_elements_text(COALESCE(s.onboarding_data->'imageUrls', '[]'::jsonb))
WITH ORDINALITY image(url, n)
WHERE NOT EXISTS (SELECT 1 FROM partner_venue_images i WHERE i.venue_service_id = s.id AND i.url = image.url);

INSERT INTO partner_venue_images (id, venue_id, venue_service_id, url, sort_order, is_cover, updated_at)
SELECT gen_random_uuid(), s.venue_id, s.id, j.value->>'imageUrl', 0, true, now()
FROM venues v, LATERAL jsonb_array_elements(COALESCE(v.metadata->'services', '[]'::jsonb)) j(value),
partner_venue_services s WHERE s.venue_id = v.id AND lower(s.title) = lower(j.value->>'name')
AND NULLIF(j.value->>'imageUrl', '') IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM partner_venue_images i WHERE i.venue_service_id = s.id);

WITH source AS (
  SELECT DISTINCT ON (s.venue_id, s.service_category_id)
    s.venue_id, s.service_category_id,
    COALESCE(s.onboarding_data->'availability', v.metadata->'availability'->s.service_category_id::text, '[]'::jsonb) days
  FROM partner_venue_services s JOIN venues v ON v.id = s.venue_id
  ORDER BY s.venue_id, s.service_category_id, s.created_at DESC
)
INSERT INTO partner_venue_availability
(id, venue_id, service_category_id, day, sort_order, open_time, close_time, capacity, price_paise, discounted_price_paise)
SELECT gen_random_uuid(), source.venue_id, source.service_category_id, lower(day.value->>'day'), (slot.n - 1)::int,
slot.value->>'openTime', slot.value->>'closeTime',
COALESCE(NULLIF(slot.value->>'capacity', '')::int, 0),
round(COALESCE(NULLIF(slot.value->>'price', '')::numeric, 0) * 100)::bigint,
round(COALESCE(NULLIF(slot.value->>'discountedPrice', '')::numeric, 0) * 100)::bigint
FROM source, LATERAL jsonb_array_elements(source.days) day(value),
LATERAL jsonb_array_elements(COALESCE(day.value->'slots', '[]'::jsonb)) WITH ORDINALITY slot(value, n)
WHERE slot.value->>'openTime' <> '-' AND slot.value->>'closeTime' <> '-' ON CONFLICT DO NOTHING;

INSERT INTO partner_service_paused_slots (venue_service_id, slot_id)
SELECT s.id, slot.id FROM partner_venue_services s,
LATERAL jsonb_array_elements_text(COALESCE(s.onboarding_data->'pausedSlotIds', '[]'::jsonb)) paused(id)
JOIN slots slot ON slot.id::text = paused.id AND slot.status = 'BLOCKED'
WHERE slot.facility_id = s.facility_id ON CONFLICT DO NOTHING;

ALTER TABLE partner_venue_availability ADD CONSTRAINT partner_venue_availability_values_check
CHECK (day IN ('monday','tuesday','wednesday','thursday','friday','saturday','sunday')
AND capacity >= 0 AND price_paise >= 0 AND discounted_price_paise >= 0);
