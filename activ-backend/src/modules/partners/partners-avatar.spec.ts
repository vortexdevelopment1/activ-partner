import { NotFoundException } from '@nestjs/common';
import { PartnersService } from './partners.service';

describe('partner avatar storage', () => {
  it('updates the owner photo used by the auth profile', async () => {
    const prisma = { partner_users: { findFirst: jest.fn(async () => ({ user_id: 'owner' })) },
      users: { update: jest.fn() } };
    const service = Object.assign(Object.create(PartnersService.prototype), { prisma });
    expect(await service.updateAvatar('partner', '/uploads/avatar.jpg')).toEqual({
      id: 'partner', avatarUrl: '/uploads/avatar.jpg',
    });
    expect(prisma.users.update).toHaveBeenCalledWith({ where: { id: 'owner' },
      data: { profile_photo: '/uploads/avatar.jpg' } });
  });

  it('does not update anyone else if the partner has no owner', async () => {
    const prisma = { partner_users: { findFirst: jest.fn(async () => null) }, users: { update: jest.fn() } };
    const service = Object.assign(Object.create(PartnersService.prototype), { prisma });
    await expect(service.updateAvatar('partner', '/photo')).rejects.toThrow(NotFoundException);
    expect(prisma.users.update).not.toHaveBeenCalled();
  });
});
