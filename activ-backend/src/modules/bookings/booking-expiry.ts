// Walk-in reservations use India wall-clock timestamps; ACTIV slots use UTC instants.
export const INDIA_OFFSET_MS = 330 * 60 * 1000;

export function bookingHasEnded(end: Date | undefined, now = new Date(), walkIn = false): boolean {
  return !!end && end.getTime() - (walkIn ? INDIA_OFFSET_MS : 0) <= now.getTime();
}

export function attendanceStatus(input: {
  status: string; startsAt: Date; endsAt: Date; checkedIn?: boolean;
  attendance?: string; walkIn?: boolean;
}, now = new Date()): string {
  if (input.status === 'COMPLETED') return 'Completed';
  if (input.status === 'CANCELLED') return 'Canceled';
  if (input.status === 'NO_SHOW' || input.attendance === 'NO_SHOW') return 'No Show';
  if (input.status !== 'CONFIRMED' && input.status !== 'RESERVED') {
    return input.status === 'RESCHEDULED' ? 'Rescheduled' : 'Pending Payment';
  }
  if (input.checkedIn || input.attendance === 'CHECKED_IN') return 'Ongoing';
  if (bookingHasEnded(input.endsAt, now, input.walkIn)) return 'No Show';
  const start = input.startsAt.getTime() - (input.walkIn ? INDIA_OFFSET_MS : 0);
  return start <= now.getTime() ? 'Ongoing' : 'Upcoming';
}
