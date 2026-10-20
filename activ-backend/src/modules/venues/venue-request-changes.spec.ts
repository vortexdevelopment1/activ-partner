import { BadRequestException } from '@nestjs/common';
import { VenuesService } from './venues.service';
import { VenueStatus } from '../../common/enums/venue-status.enum';

describe('venue corrections before approval', () => {
  let service: VenuesService;
  let prisma: any;
  let record: any;
  let notificationsService: any;
  let mailService: any;
  beforeEach(() => {
    record = { id: 'venue', partner_id: 'partner', status: 'DRAFT', submitted_at: new Date() };
    prisma = {
      venues: {
        findUnique: jest.fn(async () => record),
        update: jest.fn(async ({ data }) => { Object.assign(record, data); return record; }),
        updateMany: jest.fn(async ({ data }) => { Object.assign(record, data); return { count: 1 }; }),
      },
      partner_venue_services: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      audit_events: { findFirst: jest.fn().mockResolvedValue({ id: 'existing-email-receipt' }) },
      $transaction: jest.fn((operations) => Promise.all(operations)),
    };
    notificationsService = { notify: jest.fn().mockResolvedValue(undefined) };
    mailService = { sendVenueChangesRequestedEmail: jest.fn().mockResolvedValue(true) };
    service = Object.assign(Object.create(VenuesService.prototype), {
      prisma, notificationsService, mailService,
      pushNotificationsService: { sendToPartner: jest.fn().mockResolvedValue(true) },
      adminNotificationsService: { notify: jest.fn().mockResolvedValue(undefined) },
      findOne: jest.fn(async () => ({
        id: 'venue', partnerId: 'partner', name: 'Arena', partner: { email: 'owner@example.com' },
        status: record.submitted_at ? 'pending' : 'draft',
        termsAcceptedAt: new Date(), electronicSignature: 'Owner',
      })),
    });
  });

  it('returns the venue and its activities to editable drafts, then permits resubmission', async () => {
    await service.processApproval('venue', { status: VenueStatus.PENDING, reason: ' Clearer photos ' }, 'admin');
    expect(record).toMatchObject({ status: 'DRAFT', submitted_at: null, review_status: 'pending', rejection_reason: 'Clearer photos' });
    expect(prisma.partner_venue_services.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ status: 'DRAFT', submitted_at: null }),
    }));
    expect(notificationsService.notify).toHaveBeenCalledWith('partner', 'admin_update', expect.any(String), 'Arena: Clearer photos', { venueId: 'venue' });
    expect(mailService.sendVenueChangesRequestedEmail).toHaveBeenCalledWith({ toEmail: 'owner@example.com', venueName: 'Arena', reason: 'Clearer photos' });
    const enabled = process.env.SIGNED_AGREEMENT_EMAIL_ENABLED;
    process.env.SIGNED_AGREEMENT_EMAIL_ENABLED = 'false';
    try {
      await service.submitForReview('venue', 'partner');
      expect(record).toMatchObject({ status: 'DRAFT', submitted_at: expect.any(Date), rejection_reason: null });
      expect(prisma.partner_venue_services.updateMany).toHaveBeenLastCalledWith(expect.objectContaining({ data: expect.objectContaining({ status: 'PENDING' }) }));
      expect((service as any).adminNotificationsService.notify).toHaveBeenCalledWith('venue_submitted', expect.any(String), expect.any(String), { partnerId: 'partner', venueId: 'venue' });
    } finally {
      if (enabled === undefined) delete process.env.SIGNED_AGREEMENT_EMAIL_ENABLED;
      else process.env.SIGNED_AGREEMENT_EMAIL_ENABLED = enabled;
    }
  });

  it.each(['PUBLISHED', 'ARCHIVED'])('rejects changes requests against %s venues', async (status) => {
    record.status = status;
    await expect(service.processApproval('venue', { status: VenueStatus.PENDING, reason: 'Fix photos' }, 'admin')).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
  it.each([undefined, '', '   '])('requires a nonempty changes reason (%s)', async (reason) => {
    await expect(service.processApproval('venue', { status: VenueStatus.PENDING, reason }, 'admin')).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
});
