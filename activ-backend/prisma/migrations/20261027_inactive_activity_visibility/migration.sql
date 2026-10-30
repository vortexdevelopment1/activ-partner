-- Review-only guard. Archival is a business decision and must be performed
-- by a separately approved data migration after an operator reviews the rows.
DO $$
DECLARE candidate_count integer;
BEGIN
  SELECT count(*) INTO candidate_count
  FROM venue_activities AS link
  JOIN venues AS venue ON venue.id = link.venue_id
  WHERE link.status = 'APPROVED'
    AND EXISTS (
      SELECT 1 FROM partner_venue_services AS service
      JOIN facilities AS facility ON facility.id = service.facility_id
      WHERE service.venue_id = link.venue_id
        AND facility.venue_id = link.venue_id AND facility.activity_id = link.activity_id
    )
    AND (venue.status <> 'PUBLISHED' OR NOT venue.booking_accept OR NOT EXISTS (
      SELECT 1 FROM partner_venue_services AS service
      JOIN facilities AS facility ON facility.id = service.facility_id
      WHERE service.venue_id = link.venue_id
        AND facility.venue_id = link.venue_id AND facility.activity_id = link.activity_id
        AND service.status = 'APPROVED' AND service.is_active = TRUE
    ));
  IF candidate_count <> 0 THEN
    RAISE EXCEPTION 'Activity archival requires explicit approval; % candidate rows found', candidate_count;
  END IF;
END $$;
