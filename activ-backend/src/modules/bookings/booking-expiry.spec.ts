import { attendanceStatus, bookingHasEnded } from './booking-expiry';
import { BookingExpiryService } from './booking-expiry.service';

describe('automatic no-show attendance', () => {
  const now = new Date('2026-10-28T04:30:00Z'); // 10:00 India
  const booking = { status: 'CONFIRMED', startsAt: new Date('2026-10-28T03:30:00Z'),
    endsAt: now };
  it('uses the end boundary, not the start time', () => {
    expect(attendanceStatus(booking, new Date(now.getTime() - 1))).toBe('Ongoing');
    expect(attendanceStatus(booking, now)).toBe('No Show');
    expect(attendanceStatus(booking, new Date(now.getTime() + 1))).toBe('No Show');
  });
  it('does not expire checked-in or terminal bookings', () => {
    expect(attendanceStatus({ ...booking, checkedIn: true }, now)).toBe('Ongoing');
    expect(attendanceStatus({ ...booking, attendance: 'CHECKED_IN' }, now)).toBe('Ongoing');
    expect(attendanceStatus({ ...booking, status: 'COMPLETED' }, now)).toBe('Completed');
    expect(attendanceStatus({ ...booking, status: 'CANCELLED' }, now)).toBe('Canceled');
    expect(attendanceStatus({ ...booking, status: 'PENDING_PAYMENT' }, now)).toBe('Pending Payment');
  });
  it('converts wall-clock walk-ins to India instants, including midnight', () => {
    expect(bookingHasEnded(new Date('2026-10-28T10:00:00Z'), now, true)).toBe(true);
    expect(bookingHasEnded(new Date('2026-10-29T00:30:00Z'), new Date('2026-10-28T18:59:59Z'), true)).toBe(false);
    expect(bookingHasEnded(new Date('2026-10-29T00:30:00Z'), new Date('2026-10-28T19:00:00Z'), true)).toBe(true);
  });
  function setup(walkIn = false) {
    const record: any = { id: 'booking', status: walkIn ? 'RESERVED' : 'CONFIRMED',
      checked_in_at: null, notes: null, ends_at: new Date('2026-10-28T10:00:00Z'), slots: { ends_at: now } };
    let event: any;
    const tx: any = { $executeRaw: jest.fn(), $queryRaw: jest.fn(),
      bookings: { findUnique: jest.fn(async () => record) },
      partner_walk_in_reservations: { findUnique: jest.fn(async () => record),
        updateMany: jest.fn(async ({ data }) => Object.assign(record, data)) },
      booking_events: { findFirst: jest.fn(async () => event),
        create: jest.fn(async ({ data }) => { event = data; }) } };
    const prisma: any = { $transaction: async callback => callback(tx) };
    return { record, tx, service: new BookingExpiryService(prisma) };
  }
  it('persists an event once and rechecks attendance under the shared lock', async () => {
    const { tx, service } = setup();
    await service.expire('booking', false, now);
    await service.expire('booking', false, now);
    expect(tx.$executeRaw).toHaveBeenCalledTimes(2);
    expect(tx.booking_events.create).toHaveBeenCalledTimes(1);
    expect(tx.booking_events.create.mock.calls[0][0].data.to_status).toBe('NO_SHOW');
  });
  it.each(['CHECKED_IN', 'NO_SHOW'])('preserves concurrent %s attendance', async to_status => {
    const { tx, service } = setup();
    tx.booking_events.findFirst.mockResolvedValue({ to_status });
    await service.expire('booking', false, now);
    expect(tx.booking_events.create).not.toHaveBeenCalled();
  });
  it.each(['CANCELLED', 'COMPLETED'])('rechecks concurrent %s before writing', async status => {
    const { record, tx, service } = setup();
    record.status = status;
    await service.expire('booking', false, now);
    expect(tx.booking_events.create).not.toHaveBeenCalled();
  });
  it('persists walk-in no-show once and preserves checked-in walk-ins', async () => {
    const { record, tx, service } = setup(true);
    await service.expire('booking', true, now);
    await service.expire('booking', true, now);
    expect(record.status).toBe('NO_SHOW');
    expect(tx.partner_walk_in_reservations.updateMany).toHaveBeenCalledTimes(1);
    record.status = 'RESERVED'; record.notes = 'Checked-in: earlier';
    await service.expire('booking', true, now);
    expect(record.status).toBe('RESERVED');
  });
});
