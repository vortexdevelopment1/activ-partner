-- Repair only legacy links managed by this partner backend. Do not change
-- shared catalogue activity statuses, partner approval decisions, or bookings.
-- Lock in the same order as partner pause/resume and schedule generation.
SELECT venue.id FROM venues AS venue
WHERE EXISTS (SELECT 1 FROM partner_venue_services AS service WHERE service.venue_id = venue.id)
ORDER BY venue.id FOR UPDATE;

WITH stale_links AS (
  SELECT link.venue_id, link.activity_id
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
    ))
)
UPDATE venue_activities AS link
SET status = 'ARCHIVED'
FROM stale_links AS stale
WHERE link.venue_id = stale.venue_id AND link.activity_id = stale.activity_id;
