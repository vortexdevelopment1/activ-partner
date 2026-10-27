/** Mirror partner availability into the venue-local catalogue consumed by the
 * user app. Never modify activities.status: that catalogue is shared by venues. */
export async function syncLegacyActivityVisibility(tx: any, venueId: string): Promise<void> {
  // Older lightweight service tests do not model the consumer projection.
  if (!tx.venue_activities) return;
  const venue = await tx.venues.findUnique({
    where: { id: venueId }, select: { status: true, booking_accept: true },
  });
  const links = await tx.venue_activities.findMany({
    where: { venue_id: venueId }, select: { activity_id: true },
  });
  for (const link of links) {
    const where = { venue_id: venueId, facilities: { venue_id: venueId, activity_id: link.activity_id } };
    // Leave unrelated activities owned solely by the consumer system alone.
    if (!(await tx.partner_venue_services.count({ where }))) continue;
    const active = venue?.status === 'PUBLISHED' && venue.booking_accept &&
      await tx.partner_venue_services.count({ where: { ...where, status: 'APPROVED', is_active: true } }) > 0;
    await tx.venue_activities.updateMany({
      where: { venue_id: venueId, activity_id: link.activity_id, status: { not: active ? 'APPROVED' : 'ARCHIVED' } },
      data: { status: active ? 'APPROVED' : 'ARCHIVED' },
    });
  }
}
