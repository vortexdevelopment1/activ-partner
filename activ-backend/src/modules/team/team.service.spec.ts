import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { TeamService } from './team.service';
import { TeamMemberRole } from '../../common/enums/team-member-role.enum';
import * as bcrypt from 'bcryptjs';
import { AuthService } from '../auth/auth.service';
import { MailService } from '../mail/mail.service';

describe('current-schema team management', () => {
  const staff = {
    id: 'staff', partner_user_id: 'link', display_name: 'Alex', designation: 'manager', contact_phone_e164: '+919876543210',
    permissions: { bookingManagement: true, setupStatus: 'invite_sent' },
    partner_users: { partner_id: 'partner', user_id: 'user', role: 'PARTNER_USER', users: { name: 'Alex', status: 'ACTIVE', email: 'alex@example.com', phone_e164: '+919876543210' } },
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
  it('replaces the shared password for an existing user and sends matching SMS/email credentials', async () => {
    prisma.users.findUnique.mockResolvedValue({ id: 'user', status: 'ACTIVE', email: 'alex@example.com', password_hash: 'existing-hash' });
    const member = await service.create('partner', dto);
    const password = mail.sendTeamMemberInviteSms.mock.calls[0][0].password;
    const saved = prisma.users.update.mock.calls[0][0];
    expect(saved.where).toEqual({ id: 'user' });
    expect(password).toMatch(/^Activ@[A-Za-z0-9_-]{24}$/);
    expect(await bcrypt.compare(password, saved.data.password_hash)).toBe(true);
    expect(mail.prepareTeamMemberInviteEmail.mock.calls[0][0].password).toBe(password);
    expect(member.invitationDelivery).toEqual({ emailSent: true, smsSent: true });
    expect(JSON.stringify(member)).not.toContain(password);
  });
  it('sets a generated password for an existing account without one', async () => {
    prisma.users.findUnique.mockResolvedValue({ id: 'user', status: 'ACTIVE', email: 'alex@example.com', password_hash: null });
    await service.create('partner', dto);
    const password = mail.sendTeamMemberInviteSms.mock.calls[0][0].password;
    expect(await bcrypt.compare(password, prisma.users.update.mock.calls[0][0].data.password_hash)).toBe(true);
    expect(mail.prepareTeamMemberInviteEmail.mock.calls[0][0].password).toBe(password);
  });
  it('sends a working random password through MSG91 after removal and re-addition', async () => {
    const oldHash = await bcrypt.hash('old-password', 4);
    const existingAccount = { id: 'user', status: 'ACTIVE', email: 'alex@example.com', password_hash: oldHash };
    prisma.users.findUnique.mockResolvedValue(existingAccount);
    prisma.users.update.mockImplementation(async ({ data }) => Object.assign(existingAccount, data));
    const smsService = new MailService({ get: (key: string) => ({
      MSG91_AUTHKEY: 'synthetic-key', MSG91_TEAM_INVITE_TEMPLATE_ID: '6afdeef436aedc84d2040fc4',
    })[key] } as any, {} as any);
    mail.sendTeamMemberInviteSms.mockImplementation(params => smsService.sendTeamMemberInviteSms(params));
    const fetchMock = global.fetch as jest.Mock;
    fetchMock.mockClear();
    fetchMock.mockResolvedValue({ ok: true, json: async () => ({ type: 'success', message: 'aaaaaaaaaaaaaaaaaaaaaaaa' }) });
    await service.remove('staff', 'partner');
    const member = await service.create('partner', dto);
    expect(prisma.partner_users.delete).toHaveBeenCalledWith({ where: { id: 'link' } });
    expect(prisma.users.create).not.toHaveBeenCalled();
    expect(existingAccount.password_hash).not.toBe(oldHash);
    expect(mail.deliverPreparedEmail).toHaveBeenCalledWith('delivery');
    const payload = JSON.parse(fetchMock.mock.calls[0][1].body);
    const password = payload.recipients[0].var2;
    expect(payload).toEqual({ template_id: '6afdeef436aedc84d2040fc4', short_url: '0',
      recipients: [{ mobiles: '919876543210', var1: '9876543210', var2: password }] });
    expect(await bcrypt.compare(password, existingAccount.password_hash)).toBe(true);
    expect(mail.prepareTeamMemberInviteEmail.mock.calls[0][0].password).toBe(password);
    expect(member.invitationDelivery).toEqual({ emailSent: true, smsSent: true });

    prisma.partner_staff_profiles.findMany.mockResolvedValue([{ ...staff, partner_users: {
      ...staff.partner_users, users: existingAccount, partners: { status: 'ACTIVE' },
    } }]);
    const auth = Object.assign(Object.create(AuthService.prototype), { prisma, teamService: service,
      configService: { get: jest.fn() }, jwtService: { sign: jest.fn().mockReturnValue('staff-token') } }) as AuthService;
    await expect(auth.partnerLogin({ email: '+919876543210', password })).resolves.toMatchObject({ accessToken: 'staff-token' });
    await expect(auth.partnerLogin({ email: '+919876543210', password: 'old-password' })).rejects.toThrow('Invalid email or password');
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
  it('resends owned invitations with a fresh shared password and the same credentials on both channels', async () => {
    const member = await service.resendInvitation('staff', 'partner');
    expect(member.invitationDelivery).toEqual({ emailSent: true, smsSent: true });
    const password = mail.sendTeamMemberInviteSms.mock.calls[0][0].password;
    expect(mail.prepareTeamMemberInviteEmail.mock.calls[0][0].password).toBe(password);
    expect(await bcrypt.compare(password, prisma.users.update.mock.calls[0][0].data.password_hash)).toBe(true);
    prisma.partner_staff_profiles.findFirst.mockResolvedValue(null);
    prisma.users.update.mockClear();
    await expect(service.resendInvitation('staff', 'other')).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.users.update).not.toHaveBeenCalled();
  });
  it('rejects rapid resends and already joined members', async () => {
    for (const permissions of [{ lastInvitationAt: new Date().toISOString() }, { setupStatus: 'active' }]) {
      prisma.partner_staff_profiles.findFirst.mockResolvedValue({ ...staff, permissions });
      await expect(service.resendInvitation('staff', 'partner')).rejects.toBeInstanceOf(BadRequestException);
    }
    expect(mail.prepareTeamMemberInviteEmail).not.toHaveBeenCalled();
    expect(prisma.users.update).not.toHaveBeenCalled();
  });
  it('generates distinct valid passwords for separate resend attempts', async () => {
    await service.resendInvitation('staff', 'partner');
    prisma.partner_staff_profiles.findFirst.mockResolvedValue({ ...staff,
      permissions: { ...staff.permissions, lastInvitationAt: new Date(Date.now() - 61_000).toISOString() } });
    await service.resendInvitation('staff', 'partner');
    const passwords = mail.sendTeamMemberInviteSms.mock.calls.map(([params]) => params.password);
    expect(passwords[0]).not.toBe(passwords[1]);
    for (let index = 0; index < 2; index++) {
      expect(await bcrypt.compare(passwords[index], prisma.users.update.mock.calls[index][0].data.password_hash)).toBe(true);
    }
  });
  it.each(['inactive', 'admin', 'wrong-role', 'suspended'])('does not rotate credentials on %s resend', async state => {
    const row = { ...staff, permissions: { ...staff.permissions }, partner_users: {
      ...staff.partner_users, users: { ...staff.partner_users.users, is_admin: state === 'admin' },
    } };
    if (state === 'inactive') Object.assign(row.permissions, { isActive: false });
    if (state === 'wrong-role') row.partner_users.role = 'PARTNER_ADMIN';
    if (state === 'suspended') row.partner_users.users.status = 'SUSPENDED';
    prisma.partner_staff_profiles.findFirst.mockResolvedValue(row);
    await expect(service.resendInvitation('staff', 'partner')).rejects.toThrow('unavailable for invitation');
    expect(prisma.users.update).not.toHaveBeenCalled();
    expect(mail.sendTeamMemberInviteSms).not.toHaveBeenCalled();
  });
  it('attempts SMS for a re-added account even when no invitation email was supplied', async () => {
    prisma.users.findUnique.mockResolvedValue({ id: 'user', status: 'ACTIVE' });
    const member = await service.create('partner', { fullName: 'Alex', phone: dto.phone, role: dto.role });
    expect(member.invitationDelivery).toEqual({ emailSent: false, smsSent: true });
    expect(mail.prepareTeamMemberInviteEmail).not.toHaveBeenCalled();
    const password = mail.sendTeamMemberInviteSms.mock.calls[0][0].password;
    expect(await bcrypt.compare(password, prisma.users.update.mock.calls[0][0].data.password_hash)).toBe(true);
  });
});
