export const INDIA_TIMEZONE = 'Asia/Kolkata';

export function formatIndiaDate(
  date: string | number | Date | null | undefined,
  options?: Intl.DateTimeFormatOptions,
): string {
  if (!date) return '-';
  const d = new Date(date);
  if (isNaN(d.getTime())) return '-';
  return d.toLocaleDateString('en-IN', {
    timeZone: INDIA_TIMEZONE,
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    ...options,
  });
}

export function formatIndiaDateTime(
  date: string | number | Date | null | undefined,
  options?: Intl.DateTimeFormatOptions,
): string {
  if (!date) return '-';
  const d = new Date(date);
  if (isNaN(d.getTime())) return '-';
  return d.toLocaleString('en-IN', {
    timeZone: INDIA_TIMEZONE,
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true,
    ...options,
  });
}
