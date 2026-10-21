import { VenuesService } from './venues.service';
import { VenueStatus } from '../../common/enums/venue-status.enum';

describe('venue suspension email trigger', () => {
  const setup = (reviewStatus?: string) => {
    const mailService = { sendSuspensionEmail: jest.fn().mockResolvedValue(true) };
    const service = Object.assign(Object.create(VenuesService.prototype), {
      prisma: {
        venues: { findUnique: jest.fn().mockResolvedValue({ status: reviewStatus ? 'ARCHIVED' : 'PUBLISHED', review_status: reviewStatus }), update: jest.fn() },
        partner_venue_services: { updateMany: jest.fn() },
        $transaction: jest.fn().mockResolvedValue([]),
      },
      mailService,
      findOne: jest.fn().mockResolvedValue({ id: 'venue', name: 'Arena', partner: { email: 'owner@example.com', firstName: 'Test', lastName: 'Owner' } }),
    }) as VenuesService;
    return { service, mailService };
  };
  it('sends the suspension reason to the registered partner after saving', async () => {
    const { service, mailService } = setup();
    await service.processApproval('venue', { status: VenueStatus.SUSPENDED, reason: 'Invalid business details' }, 'admin');
    expect(mailService.sendSuspensionEmail).toHaveBeenCalledWith({ toEmail: 'owner@example.com', partnerName: 'Test Owner', venueName: 'Arena', reason: 'Invalid business details' });
  });
  it('does not send another email for an already suspended venue', async () => {
    const { service, mailService } = setup('suspended');
    await service.processApproval('venue', { status: VenueStatus.SUSPENDED, reason: 'Same reason' }, 'admin');
    expect(mailService.sendSuspensionEmail).not.toHaveBeenCalled();
  });
  it('does not email if the suspension transaction fails', async () => {
    const { service, mailService } = setup();
    (service as any).prisma.$transaction.mockRejectedValue(new Error('Database unavailable'));
    await expect(service.processApproval('venue', { status: VenueStatus.SUSPENDED, reason: 'Reason' }, 'admin')).rejects.toThrow('Database unavailable');
    expect(mailService.sendSuspensionEmail).not.toHaveBeenCalled();
  });
});
