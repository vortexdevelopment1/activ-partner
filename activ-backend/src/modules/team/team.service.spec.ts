import { ConflictException, NotFoundException } from '@nestjs/common';
import { TeamService } from './team.service';
import { TeamMemberRole } from '../../common/enums/team-member-role.enum';

describe('current-schema team management', () => {
  const staff = {
    id: 'staff', partner_user_id: 'link', display_name: 'Alex', designation: 'manager',
    permissions: { bookingManagement: true, setupStatus: 'invite_sent' },
    partner_users: { partner_id: 'partner', user_id: 'user', users: { name: 'Alex', phone_e164: '+919876543210' } },
  };
  let prisma: any;
  let service: TeamService;
  beforeEach(() => {
    prisma = {
      partner_staff_profiles: { findMany: jest.fn().mockResolvedValue([staff]),
        findFirst: jest.fn().mockResolvedValue(staff), create: jest.fn().mockResolvedValue(staff) },
      partner_users: { findFirst: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue({ id: 'link' }), delete: jest.fn() },
      users: { findUnique: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue({ id: 'user' }) },
    };
    prisma.$transaction = jest.fn((callback) => callback(prisma));
    service = new TeamService(prisma);
  });
  it('lists only the signed-in partners staff and exposes no credentials', async () => {
    const members = await service.findAll('partner');
    expect(prisma.partner_staff_profiles.findMany.mock.calls[0][0].where).toEqual({ partner_users: { partner_id: 'partner' } });
    expect(members[0]).toMatchObject({ id: 'staff', fullName: 'Alex', status: 'invite_sent', permissions: { bookingManagement: true } });
    expect(members[0].password).toBeUndefined();
  });
  it('creates the account link and staff profile in one transaction', async () => {
    await service.create('partner', { fullName: 'Alex', phone: '+919876543210', role: TeamMemberRole.MANAGER });
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(prisma.partner_users.create.mock.calls[0][0].data.role).toBe('PARTNER_USER');
    expect(prisma.partner_staff_profiles.create.mock.calls[0][0].data.partner_user_id).toBe('link');
  });
  it('does not reuse admin accounts as staff', async () => {
    prisma.users.findUnique.mockResolvedValue({ id: 'admin', is_admin: true });
    await expect(service.create('partner', { fullName: 'Alex', phone: '+919876543210', role: TeamMemberRole.MANAGER })).rejects.toBeInstanceOf(ConflictException);
    expect(prisma.partner_users.create).not.toHaveBeenCalled();
  });
  it('checks ownership before removing a staff link', async () => {
    prisma.partner_staff_profiles.findFirst.mockResolvedValue(null);
    await expect(service.remove('other-staff', 'partner')).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.partner_users.delete).not.toHaveBeenCalled();
  });
});
