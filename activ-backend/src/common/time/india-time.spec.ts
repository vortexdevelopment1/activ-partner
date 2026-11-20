import { formatIndiaDate, indiaDateBounds, weekdayForIndiaDate } from './india-time';

describe('India time contract', () => {
  it('maps an India calendar date to half-open UTC bounds', () => {
    const bounds = indiaDateBounds('2026-11-21');
    expect(bounds.start.toISOString()).toBe('2026-11-20T18:30:00.000Z');
    expect(bounds.end.toISOString()).toBe('2026-11-21T18:30:00.000Z');
  });

  it('is independent of the Node host timezone', () => {
    expect(weekdayForIndiaDate('2026-11-21')).toBe('saturday');
    expect(formatIndiaDate(new Date('2026-11-20T20:00:00Z'))).toBe('21 November 2026');
  });
});
