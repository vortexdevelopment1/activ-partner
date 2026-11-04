-- Persist question presentation and validation rules so mobile clients render
-- the same activity form from the database, rather than from hard-coded UI.
ALTER TABLE "partner_service_questions"
  ADD COLUMN IF NOT EXISTS "placeholder" TEXT,
  ADD COLUMN IF NOT EXISTS "helper_text" TEXT,
  ADD COLUMN IF NOT EXISTS "min_length" INTEGER,
  ADD COLUMN IF NOT EXISTS "max_length" INTEGER;

-- Align legacy labels with the approved sheet. A few installations already
-- contain the canonical row, so never rename into a duplicate. In that case
-- archive the old catalogue entry; venue links remain unchanged and no data is
-- deleted. The canonical category stays visible to partners.
DO $$
DECLARE
  item RECORD;
  source_activity_id UUID;
BEGIN
  FOR item IN
    SELECT * FROM (VALUES
      ('yoga', 'yoga-studio', 'Yoga Studio'),
      ('dance-fitness', 'dance-studio', 'Dance Studio'),
      ('crossfit', 'crossfit', 'CrossFit'),
      ('hiit', 'hiit-studio', 'HIIT Studio'),
      ('pickle-ball', 'pickleball', 'Pickleball'),
      ('billiards', 'snooker', 'Snooker')
    ) AS mapping(old_slug, new_slug, new_name)
  LOOP
    IF item.old_slug = item.new_slug THEN
      UPDATE "partner_service_categories"
      SET name = item.new_name, updated_at = NOW()
      WHERE slug = item.old_slug;
    ELSIF EXISTS (SELECT 1 FROM "partner_service_categories" WHERE slug = item.new_slug) THEN
      UPDATE "partner_service_categories"
      SET status = 'ARCHIVED', updated_at = NOW()
      WHERE slug = item.old_slug;
    ELSE
      UPDATE "partner_service_categories"
      SET name = item.new_name, slug = item.new_slug, updated_at = NOW()
      WHERE slug = item.old_slug;
    END IF;

    IF EXISTS (
      SELECT 1 FROM "activities"
      WHERE sport_code = item.new_slug AND name = item.new_name
    ) THEN
      UPDATE "activities"
      SET status = 'ARCHIVED'
      WHERE sport_code = item.old_slug
        AND NOT (sport_code = item.new_slug AND name = item.new_name);
    ELSE
      SELECT id INTO source_activity_id
      FROM "activities"
      WHERE sport_code = item.old_slug
      ORDER BY created_at, id
      LIMIT 1;

      IF source_activity_id IS NOT NULL THEN
        UPDATE "activities"
        SET sport_code = item.new_slug, name = item.new_name
        WHERE id = source_activity_id;

        UPDATE "activities"
        SET status = 'ARCHIVED'
        WHERE sport_code = item.old_slug AND id <> source_activity_id;
      END IF;
    END IF;
  END LOOP;
END $$;

-- The previous Box Cricket catalogue item is no longer in the approved list.
-- Archive it without deleting partner data or historical bookings.
UPDATE "partner_service_categories" SET status = 'ARCHIVED', updated_at = NOW() WHERE slug = 'box-cricket';
UPDATE "activities" SET status = 'ARCHIVED' WHERE sport_code = 'box-cricket';
