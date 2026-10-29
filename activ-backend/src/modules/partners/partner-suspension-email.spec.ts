import { PartnersService } from './partners.service';

describe('partner account suspension email', () => {
  let service: PartnersService;
  let mailService: any;
  let prisma: any;
  beforeEach(() => {
    mailService = { sendSuspensionEmail: jest.fn().mockResolvedValue(true) };
    prisma = { partners: {
      findUnique: jest.fn().mockResolvedValue({ status: 'ACTIVE' }),
      update: jest.fn().mockResolvedValue({ id: 'partner', updated_at: new Date('2026-10-29T00:00:00Z'), status: 'SUSPENDED', legal_name: 'Business', partner_users: [
        { role: 'PARTNER_USER', users: { email: 'staff@example.com', name: 'Staff' } },
        { role: 'PARTNER_ADMIN', users: { email: 'owner@example.com', name: 'Owner' } },
      ] }),
    } };
    service = Object.assign(Object.create(PartnersService.prototype), { prisma, mailService });
  });
  it('notifies the account owner rather than the first staff member', async () => {
    await service.update('partner', { isActive: false });
    expect(mailService.sendSuspensionEmail).toHaveBeenCalledWith({ toEmail: 'owner@example.com', partnerName: 'Owner',
      deliveryKey: 'partner-suspended:partner:2026-10-29T00:00:00.000Z' });
  });
  it('does not send a suspension email on reactivation', async () => {
    await service.update('partner', { isActive: true });
    expect(mailService.sendSuspensionEmail).not.toHaveBeenCalled();
  });
  it('does not send again when the account is already suspended', async () => {
    prisma.partners.findUnique.mockResolvedValue({ status: 'SUSPENDED' });
    await service.update('partner', { isActive: false });
    expect(mailService.sendSuspensionEmail).not.toHaveBeenCalled();
  });
});
