import { BadRequestException, NotFoundException } from '@nestjs/common';
import { deletePartnerAccount } from './delete-partner-account';
import { PartnersService } from './partners.service';

describe('partner account deletion', () => {
  it('uses the current database schema inside an atomic transaction', async () => {
    const tx = { $queryRawUnsafe: jest.fn().mockResolvedValueOnce([{ id: 'partner' }])
      .mockResolvedValue([]), $executeRawUnsafe: jest.fn().mockResolvedValue(1) };
    const prisma = { $transaction: jest.fn(async (callback) => callback(tx)) };
    const legacy = { findOne: jest.fn() };
    const service = Object.assign(Object.create(PartnersService.prototype), { prisma, partnerRepository: legacy });
    await service.deleteAccount('partner');
    expect(legacy.findOne).not.toHaveBeenCalled();
    expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Function),
      { maxWait: 10000, timeout: 60000, isolationLevel: 'Serializable' });
    expect(tx.$executeRawUnsafe).toHaveBeenCalledWith(expect.stringContaining('DELETE FROM "users"'));
    expect(tx.$executeRawUnsafe).toHaveBeenCalledWith(expect.stringContaining('DELETE FROM "otp_challenges"'));
  });

  it('rejects missing accounts without deleting anything', async () => {
    const tx = { $queryRawUnsafe: jest.fn().mockResolvedValue([]), $executeRawUnsafe: jest.fn() };
    await expect(deletePartnerAccount(tx as any, 'missing')).rejects.toThrow(NotFoundException);
    expect(tx.$executeRawUnsafe).not.toHaveBeenCalled();
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
});
