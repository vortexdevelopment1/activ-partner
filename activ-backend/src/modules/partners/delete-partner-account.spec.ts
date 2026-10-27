import { BadRequestException, NotFoundException } from '@nestjs/common';
import { deletePartnerAccount } from './delete-partner-account';
import { PartnersService } from './partners.service';
import { ACTIVE_BOOKING_PREDICATE } from '../bookings/active-booking-predicate';

describe('partner account deletion', () => {
  it.each(['deleteAccount', 'remove'] as const)('%s uses the current database schema inside an atomic transaction', async (method) => {
    const tx = { $queryRawUnsafe: jest.fn().mockResolvedValueOnce([{ id: 'partner' }])
      .mockResolvedValue([]), $executeRawUnsafe: jest.fn().mockResolvedValue(1) };
    const prisma = { $transaction: jest.fn(async (callback) => callback(tx)) };
    const legacy = { findOne: jest.fn() };
    const service = Object.assign(Object.create(PartnersService.prototype), { prisma, partnerRepository: legacy });
    await service[method]('partner');
    expect(legacy.findOne).not.toHaveBeenCalled();
    expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Function),
      { maxWait: 10000, timeout: 60000, isolationLevel: 'Serializable' });
    expect(tx.$executeRawUnsafe).toHaveBeenCalledWith(expect.stringContaining('DELETE FROM "users"'));
    expect(tx.$executeRawUnsafe).toHaveBeenCalledWith(expect.stringContaining('DELETE FROM "otp_challenges"'));
    expect(tx.$queryRawUnsafe).toHaveBeenCalledWith(
      'SELECT id FROM partners WHERE id = $1::uuid FOR UPDATE', 'partner',
    );
  });

  it('rejects missing accounts without deleting anything', async () => {
    const tx = { $queryRawUnsafe: jest.fn().mockResolvedValue([]), $executeRawUnsafe: jest.fn() };
    await expect(deletePartnerAccount(tx as any, 'missing')).rejects.toThrow(NotFoundException);
    expect(tx.$executeRawUnsafe).not.toHaveBeenCalled();
  });

  it('checks latest attendance along with lifecycle status before deleting a scoped account', async () => {
    const tx = { $queryRawUnsafe: jest.fn(async (sql: string) =>
      sql.startsWith('SELECT id FROM partners') ? [{ id: 'partner' }] : []),
      $executeRawUnsafe: jest.fn().mockResolvedValue(1) };
    await deletePartnerAccount(tx as any, 'partner');
    expect(tx.$queryRawUnsafe).toHaveBeenCalledWith(
      `SELECT booking.id FROM account_delete_bookings booking WHERE ${ACTIVE_BOOKING_PREDICATE} LIMIT 1`,
    );
  });

  it.each(['shared login', 'active booking'])('blocks %s before any delete is performed', async (reason) => {
    const tx = { $queryRawUnsafe: jest.fn(async (sql: string) => {
      if (sql.startsWith('SELECT id FROM partners')) return [{ id: 'partner' }];
      if (reason === 'shared login' && sql.includes('WHERE is_admin')) return [{ id: 'user' }];
      if (reason === 'active booking' && sql.includes("status IN ('PENDING_PAYMENT'")) return [{ id: 'booking' }];
      return [];
    }), $executeRawUnsafe: jest.fn().mockResolvedValue(0) };
    await expect(deletePartnerAccount(tx as any, 'partner')).rejects.toThrow(BadRequestException);
    expect(tx.$executeRawUnsafe.mock.calls.some(([sql]) => sql.startsWith('DELETE'))).toBe(false);
  });

  it('propagates deletion failures through the admin endpoint transaction', async () => {
    const failure = new BadRequestException('Cannot delete account: active bookings');
    const prisma = { $transaction: jest.fn().mockRejectedValue(failure) };
    const service = Object.assign(Object.create(PartnersService.prototype), { prisma });
    await expect(service.remove('partner')).rejects.toBe(failure);
  });
});
