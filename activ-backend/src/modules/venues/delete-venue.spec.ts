import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { VenuesService } from './venues.service';
import { ACTIVE_BOOKING_PREDICATE } from '../bookings/active-booking-predicate';

describe('single-request admin venue deletion', () => {
  const setup = (venue: any, activeBooking = false) => {
    const tx = {
      $queryRawUnsafe: jest.fn(async (sql: string) => {
        if (sql.startsWith('SELECT id, partner_id')) return venue ? [venue] : [];
        if (sql.includes('FROM venue_delete_bookings') && activeBooking) return [{ id: 'booking' }];
        return [];
      }),
      $executeRawUnsafe: jest.fn().mockResolvedValue(1),
      venues: { update: jest.fn(), delete: jest.fn() },
    };
    const prisma = { $transaction: jest.fn(async (callback) => callback(tx)) };
    const service = Object.assign(Object.create(VenuesService.prototype), { prisma }) as VenuesService;
    return { tx, prisma, service };
  };
  const admin = { id: 'admin', role: 'admin' };
  const venue = { id: 'venue', partner_id: 'owner', status: 'PUBLISHED', booking_accept: true };

  it('permanently deletes a published venue on the first admin request', async () => {
    const { service, tx, prisma } = setup({ ...venue });
    await expect(service.remove('venue', admin)).resolves.toEqual({ permanentlyDeleted: true });
    expect(tx.venues.update).not.toHaveBeenCalled();
    expect(tx.venues.delete).toHaveBeenCalledWith({ where: { id: 'venue' } });
    expect(tx.$queryRawUnsafe).toHaveBeenCalledWith(
      `SELECT booking.id FROM venue_delete_bookings booking WHERE ${ACTIVE_BOOKING_PREDICATE} LIMIT 1`,
    );
    expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Function),
      { maxWait: 10000, timeout: 60000, isolationLevel: 'Serializable' });
    const sql = tx.$executeRawUnsafe.mock.calls.map(([query]) => query).join('\n');
    for (const table of ['payments', 'bookings', 'booking_attempts', 'slots', 'facilities']) {
      expect(sql).toContain(`DELETE FROM "${table}"`);
    }
    expect(sql).toContain('DELETE FROM partner_venue_services');
    expect(sql).toContain('DELETE FROM partner_venue_answers');
    expect(sql).toContain('DELETE FROM partner_venue_images');
  });

  it.each(['DRAFT', 'ARCHIVED'])('permanently deletes a %s venue without archiving first', async (status) => {
    const { service, tx } = setup({ ...venue, status });
    await expect(service.remove('venue', admin)).resolves.toEqual({ permanentlyDeleted: true });
    expect(tx.venues.update).not.toHaveBeenCalled();
    expect(tx.venues.delete).toHaveBeenCalledWith({ where: { id: 'venue' } });
  });

  it('keeps partner deletions as archives even when repeated', async () => {
    const { service, tx } = setup({ ...venue, status: 'ARCHIVED', booking_accept: false });
    await expect(service.remove('venue', { id: 'owner', role: 'partner' })).resolves.toEqual({ permanentlyDeleted: false });
    expect(tx.venues.delete).not.toHaveBeenCalled();
  });

  it.each([{ id: 'other', role: 'partner' }, { id: 'owner', role: 'user' }])('rejects unauthorized deletion by $role', async (user) => {
    const { service, tx } = setup(venue);
    await expect(service.remove('venue', user)).rejects.toBeInstanceOf(ForbiddenException);
    expect(tx.venues.update).not.toHaveBeenCalled();
    expect(tx.venues.delete).not.toHaveBeenCalled();
  });

  it('returns 404 when the venue is already gone', async () => {
    const { service } = setup(null);
    await expect(service.remove('missing', admin)).rejects.toBeInstanceOf(NotFoundException);
  });

  it('blocks permanent deletion before removing records when there are active bookings', async () => {
    const { service, tx } = setup({ ...venue }, true);
    await expect(service.remove('venue', admin)).rejects.toBeInstanceOf(BadRequestException);
    expect(tx.venues.delete).not.toHaveBeenCalled();
    expect(tx.$executeRawUnsafe.mock.calls.some(([sql]) => sql.startsWith('DELETE'))).toBe(false);
  });

  it('propagates child cleanup failures so the transaction rolls back', async () => {
    const { service, tx } = setup({ ...venue, status: 'ARCHIVED', booking_accept: false });
    const failure = new Error('Cleanup failed');
    tx.$executeRawUnsafe.mockRejectedValueOnce(failure);
    await expect(service.remove('venue', admin)).rejects.toBe(failure);
    expect(tx.venues.delete).not.toHaveBeenCalled();
  });
});
