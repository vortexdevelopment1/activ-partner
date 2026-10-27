// The surrounding query must alias its scoped booking rows as "booking".
// Older attendance actions recorded NO_SHOW in events while leaving the
// payment lifecycle CONFIRMED. Match the management screen's latest attendance.
export const ACTIVE_BOOKING_PREDICATE = `booking.status IN ('PENDING_PAYMENT', 'CONFIRMED')
  AND (booking.status <> 'CONFIRMED' OR (
    SELECT event.to_status FROM booking_events event
    WHERE event.booking_id = booking.id
      AND event.to_status IN ('CHECKED_IN', 'NO_SHOW')
    ORDER BY event.created_at DESC
    LIMIT 1
  ) IS DISTINCT FROM 'NO_SHOW')`;
