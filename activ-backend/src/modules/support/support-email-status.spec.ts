import { SupportService } from './support.service';
import { SupportController } from './support.controller';
import { CallbackStatus } from '../../common/enums/callback-status.enum';
import { UserRole } from '../../common/enums/user-role.enum';

describe('support email submission', () => {
  it.each([
    { role: UserRole.PARTNER as const, id: 'partner', userId: 'owner-user' },
    { role: UserRole.TEAM_MEMBER as const, id: 'staff-profile', partnerId: 'partner', userId: 'staff-user' },
  ])('saves a request under the partner and attributes it to the $role sender', async (user) => {
    const record = { id: 'support' };
    const findFirst = jest.fn().mockResolvedValue({ id: 'sender-link', users: { email: 'sender@example.com' } });
    const create = jest.fn().mockResolvedValue(record);
    const prisma = { partner_users: { findFirst }, partner_support_requests: { create } };
    const mail = { sendSupportRequestEmail: jest.fn().mockResolvedValue(true) };
    const notifications = { notify: jest.fn().mockResolvedValue(undefined) };
    const service = new SupportService(mail as any, {} as any, prisma as any, notifications as any);
    const dto = { subject: 'Booking question', message: 'Please help with this booking.' };

    await expect(new SupportController(service).createEmail(dto, user)).resolves.toMatchObject({ data: record });

    expect(findFirst).toHaveBeenCalledWith({ where: { partner_id: 'partner', user_id: user.userId }, include: { users: true } });
    expect(create).toHaveBeenCalledWith({ data: expect.objectContaining({ partner_id: 'partner', partner_user_id: 'sender-link' }) });
    expect(mail.sendSupportRequestEmail).toHaveBeenCalledWith(expect.objectContaining({ partnerEmail: 'sender@example.com', ...dto }));
  });
});

describe('support partner status emails', () => {
  const statusCases = [
    [CallbackStatus.IN_PROGRESS, 'IN_PROGRESS', 'in_progress'],
    [CallbackStatus.CONTACTED, 'CONTACTED', 'in_progress'],
    [CallbackStatus.RESOLVED, 'RESOLVED', 'resolved'],
    [CallbackStatus.CANCELLED, 'CLOSED', 'cancelled'],
  ] as const;

  it.each(statusCases)('emails the partner when support changes to %s and excludes internal notes', async (dtoStatus, status, suffix) => {
    const current = { id: 'support', partner_id: 'partner', status: 'PENDING', subject: 'Help with venue', message: 'Original question' };
    const prisma = { partner_support_requests: {
      findUnique: jest.fn().mockResolvedValue(current), update: jest.fn().mockResolvedValue({ ...current, status }),
    } };
    const notices = { send: jest.fn().mockResolvedValue(true) };
    const service = new SupportService({} as any, {} as any, prisma as any, {} as any, notices as any);
    await service.updateEmail('support', { status: dtoStatus, adminNotes: 'Internal staff-only note' });
    expect(notices.send).toHaveBeenCalledWith('partner', `support_${suffix}`, { reference: 'support', subject: 'Help with venue', deliveryKey: expect.stringContaining('support-status:support:') });
    expect(JSON.stringify(notices.send.mock.calls)).not.toContain('Internal staff-only');
  });

  it('does not email for repeated support status or notes-only edits', async () => {
    const record = { id: 'support', partner_id: 'partner', status: 'RESOLVED' };
    const prisma = { partner_support_requests: { findUnique: jest.fn().mockResolvedValue(record), update: jest.fn().mockResolvedValue(record) } };
    const notices = { send: jest.fn() };
    const service = new SupportService({} as any, {} as any, prisma as any, {} as any, notices as any);
    await service.updateEmail('support', { status: CallbackStatus.RESOLVED });
    await service.updateEmail('support', { adminNotes: 'Notes only' });
    expect(notices.send).not.toHaveBeenCalled();
  });

  it.each(statusCases)('emails the original callback contact on %s', async (dtoStatus, status, suffix) => {
    const record = { id: 'callback', status: 'PENDING', notes: 'Partner: Owner\nEmail: owner@example.com\nVenue: Arena\nPreferred date: 2026-10-28\nPreferred time: 10:00' };
    const prisma = { partner_callback_requests: { findUnique: jest.fn().mockResolvedValue(record), update: jest.fn().mockResolvedValue({ ...record, status }) } };
    const mail = { sendTemplateEmail: jest.fn().mockResolvedValue(true) };
    const service = new SupportService(mail as any, {} as any, prisma as any, {} as any);
    await service.update('callback', { status: dtoStatus, adminNotes: 'Internal-only' });
    expect(mail.sendTemplateEmail).toHaveBeenCalledWith('owner@example.com', `callback_${suffix}`, {
      deliveryKey: expect.stringContaining('callback-status:callback:'), partnerName: 'Owner', venueName: 'Arena', reference: 'callback', callbackDate: '2026-10-28', callbackTime: '10:00',
    });
  });
});
