import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { TeamService } from './team.service';
import { TeamMemberRole } from '../../common/enums/team-member-role.enum';

describe('current-schema team management', () => {
  const staff = {
    id: 'staff', partner_user_id: 'link', display_name: 'Alex', designation: 'manager',
    permissions: { bookingManagement: true, setupStatus: 'invite_sent' },
    partner_users: { partner_id: 'partner', user_id: 'user', users: { name: 'Alex', status: 'ACTIVE', email: 'alex@example.com', phone_e164: '+919876543210' } },
  };
  let prisma: any;
  let service: TeamService;
  let mail: any;
  beforeEach(() => {
    prisma = {
      partner_staff_profiles: { findMany: jest.fn().mockResolvedValue([staff]),
        findFirst: jest.fn().mockResolvedValue(staff), create: jest.fn().mockResolvedValue(staff),
        findUnique: jest.fn().mockResolvedValue(staff), update: jest.fn().mockResolvedValue(staff) },
      partner_users: { findFirst: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue({ id: 'link' }), delete: jest.fn() },
      users: { findUnique: jest.fn().mockResolvedValue(null), findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'user' }), update: jest.fn() },
      $queryRaw: jest.fn().mockResolvedValue([]),
      $executeRaw: jest.fn().mockResolvedValue(1),
    };
    prisma.$transaction = jest.fn((callback) => callback(prisma));
    mail = { prepareTeamMemberInviteEmail: jest.fn().mockResolvedValue('delivery'),
      deliverPreparedEmail: jest.fn().mockResolvedValue(true), sendTeamMemberInviteSms: jest.fn().mockResolvedValue(true) };
    service = new TeamService(prisma, mail);
  });
  it('lists only the signed-in partners staff and exposes no credentials', async () => {
    const members = await service.findAll('partner');
    expect(prisma.partner_staff_profiles.findMany.mock.calls[0][0].where).toEqual({ partner_users: { partner_id: 'partner' } });
    expect(members[0]).toMatchObject({ id: 'staff', fullName: 'Alex', status: 'invite_sent', permissions: { bookingManagement: true } });
    expect(members[0].password).toBeUndefined();
  });
  it('creates the account link and staff profile in one transaction', async () => {
    await service.create('partner', { fullName: 'Alex', phone: '+919876543210', role: TeamMemberRole.MANAGER });
    expect(prisma.$transaction).toHaveBeenCalledTimes(2);
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

  const dto = { fullName: 'Alex', phone: '+919876543210', email: 'Alex@Example.com', role: TeamMemberRole.MANAGER };
  it('encrypts email in the account transaction and delivers both channels after commit', async () => {
    let committed = false;
    prisma.$transaction.mockImplementation(async callback => { const result = await callback(prisma); committed = true; return result; });
    mail.prepareTeamMemberInviteEmail.mockImplementation(async (_, tx) => {
      expect(committed).toBe(false); expect(tx).toBe(prisma); return 'delivery';
    });
    mail.deliverPreparedEmail.mockImplementation(async () => { expect(committed).toBe(true); return true; });
    const member = await service.create('partner', dto);
    expect(prisma.users.create.mock.calls[0][0].data.email).toBe('alex@example.com');
    expect(member.invitationDelivery).toEqual({ emailSent: true, smsSent: true });
    expect(member.status).toBe('invite_sent');
    expect(JSON.stringify(member)).not.toContain('Activ@');
    expect(mail.sendTeamMemberInviteSms.mock.calls[0][0].password)
      .toBe(mail.prepareTeamMemberInviteEmail.mock.calls[0][0].password);
  });
  it('keeps a saved member recoverable when both providers fail', async () => {
    mail.deliverPreparedEmail.mockRejectedValue(new Error('mail offline'));
    mail.sendTeamMemberInviteSms.mockRejectedValue(new Error('SMS offline'));
    const member = await service.create('partner', dto);
    expect(member).toMatchObject({ status: 'invite_pending', invitationDelivery: { emailSent: false, smsSent: false } });
  });
  it('preserves an existing user password and sends OTP instructions', async () => {
    prisma.users.findUnique.mockResolvedValue({ id: 'user', status: 'ACTIVE', email: 'alex@example.com', password_hash: 'existing-hash' });
    await service.create('partner', dto);
    expect(prisma.users.update).not.toHaveBeenCalled();
    expect(mail.prepareTeamMemberInviteEmail.mock.calls[0][0].password).toBeUndefined();
    expect(mail.sendTeamMemberInviteSms.mock.calls[0][0].password).toBeUndefined();
  });
  it('never creates a password or recovery email for an existing consumer account', async () => {
    prisma.users.findUnique.mockResolvedValue({ id: 'user', status: 'ACTIVE', email: 'alex@example.com', password_hash: null });
    await service.create('partner', dto);
    expect(prisma.users.update).not.toHaveBeenCalled();
    expect(mail.prepareTeamMemberInviteEmail.mock.calls[0][0].password).toBeUndefined();
  });
  it('rolls back account preparation when durable email preparation fails', async () => {
    mail.prepareTeamMemberInviteEmail.mockRejectedValue(new Error('outbox unavailable'));
    await expect(service.create('partner', dto)).rejects.toThrow('outbox unavailable');
    expect(mail.deliverPreparedEmail).not.toHaveBeenCalled();
    expect(mail.sendTeamMemberInviteSms).not.toHaveBeenCalled();
  });
  it('preserves permissions not edited by the partner', async () => {
    await service.update('staff', 'partner', { permissions: { bookingManagement: false } });
    expect(prisma.partner_staff_profiles.update.mock.calls[0][0].data.permissions)
      .toMatchObject({ bookingManagement: false, setupStatus: 'invite_sent' });
  });
  it('cannot change contact details on a pre-existing consumer login', async () => {
    await expect(service.update('staff', 'partner', { phone: '+919999000001' })).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.users.update).not.toHaveBeenCalled();
  });
  it('rejects conflicting emails before linking an account', async () => {
    prisma.users.findFirst.mockResolvedValue({ id: 'another-user' });
    await expect(service.create('partner', dto)).rejects.toBeInstanceOf(ConflictException);
    expect(prisma.partner_users.create).not.toHaveBeenCalled();
    expect(mail.deliverPreparedEmail).not.toHaveBeenCalled();
  });
  it('resends only owned invitations without changing credentials', async () => {
    await service.resendInvitation('staff', 'partner');
    expect(mail.prepareTeamMemberInviteEmail.mock.calls[0][0].password).toBeUndefined();
    expect(prisma.users.update).not.toHaveBeenCalled();
    prisma.partner_staff_profiles.findFirst.mockResolvedValue(null);
    await expect(service.resendInvitation('staff', 'other')).rejects.toBeInstanceOf(NotFoundException);
  });
  it('rejects rapid resends and already joined members', async () => {
    for (const permissions of [{ lastInvitationAt: new Date().toISOString() }, { setupStatus: 'active' }]) {
      prisma.partner_staff_profiles.findFirst.mockResolvedValue({ ...staff, permissions });
      await expect(service.resendInvitation('staff', 'partner')).rejects.toBeInstanceOf(BadRequestException);
    }
    expect(mail.prepareTeamMemberInviteEmail).not.toHaveBeenCalled();
  });
});
