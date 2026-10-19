import { BadRequestException, ForbiddenException, ServiceUnavailableException } from '@nestjs/common';
import { VenuesService } from './venues.service';
import { PDFDocument } from 'pdf-lib';

describe('Finish agreement email', () => {
  const originalEmailEnabled = process.env.SIGNED_AGREEMENT_EMAIL_ENABLED;
  let service: VenuesService;
  let prisma: any;
  let mailService: any;
  let signedVenue: any;

  beforeEach(() => {
    process.env.SIGNED_AGREEMENT_EMAIL_ENABLED = 'true';
    signedVenue = { id: 'venue-1', name: 'Club', partnerId: 'partner-1',
      electronicSignature: 'Lalit Jangid', termsAcceptedAt: new Date('2026-10-16T10:00:00Z'),
      partner: { email: 'registered@example.com' } };
    prisma = {
      venues: { findUnique: jest.fn().mockResolvedValue({ id: 'venue-1', partner_id: 'partner-1', status: 'DRAFT' }),
        update: jest.fn().mockResolvedValue({}), updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      partner_venue_services: { updateMany: jest.fn().mockResolvedValue({}) },
      audit_events: { findFirst: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue({}) },
      $transaction: jest.fn().mockImplementation((operations) => Promise.all(operations)),
    };
    mailService = { sendSignedPartnerAgreementEmail: jest.fn().mockResolvedValue(undefined) };
    service = Object.assign(Object.create(VenuesService.prototype), {
      prisma, mailService, logger: { error: jest.fn() }, findOne: jest.fn().mockResolvedValue(signedVenue),
      adminNotificationsService: { notify: jest.fn().mockResolvedValue(undefined) },
      generatePartnerAgreementPdf: jest.fn().mockResolvedValue({ base64: 'JVBERg==', filename: 'signed.pdf', mimeType: 'application/pdf' }),
    });
  });

  afterEach(() => {
    if (originalEmailEnabled === undefined) delete process.env.SIGNED_AGREEMENT_EMAIL_ENABLED;
    else process.env.SIGNED_AGREEMENT_EMAIL_ENABLED = originalEmailEnabled;
  });

  it.each([undefined, 'false'])('submits for admin review with email bypassed (%s)', async (enabled) => {
    if (enabled === undefined) delete process.env.SIGNED_AGREEMENT_EMAIL_ENABLED;
    else process.env.SIGNED_AGREEMENT_EMAIL_ENABLED = enabled;
    mailService.sendSignedPartnerAgreementEmail.mockRejectedValue(new Error('Not configured'));
    await expect(service.submitForReview('venue-1', 'partner-1')).resolves.toBe(signedVenue);
    expect(mailService.sendSignedPartnerAgreementEmail).not.toHaveBeenCalled();
    expect(service.generatePartnerAgreementPdf).not.toHaveBeenCalled();
    expect(prisma.audit_events.create).not.toHaveBeenCalled();
    expect(prisma.venues.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      data: { submitted_at: expect.any(Date), review_status: 'pending', rejection_reason: null },
    }));
    expect(prisma.partner_venue_services.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      data: { status: 'PENDING', updated_at: expect.any(Date) },
    }));
    expect(prisma.$transaction).toHaveBeenCalled();
    expect((service as any).adminNotificationsService.notify).toHaveBeenCalledWith(
      'venue_submitted', expect.any(String), expect.any(String),
      { partnerId: 'partner-1', venueId: 'venue-1' },
    );
  });

  it('emails the signed agreement to the saved profile email on Finish', async () => {
    await service.submitForReview('venue-1', 'partner-1');
    expect(mailService.sendSignedPartnerAgreementEmail).toHaveBeenCalledWith(expect.objectContaining({
      toEmail: 'registered@example.com', partnerName: 'Lalit Jangid',
      agreement: expect.objectContaining({ filename: 'signed.pdf' }),
    }));
    expect(prisma.audit_events.create).toHaveBeenCalled();
    expect(prisma.$transaction).toHaveBeenCalled();
  });

  it('surfaces delivery failure and leaves submission available to retry', async () => {
    mailService.sendSignedPartnerAgreementEmail.mockRejectedValue(new Error('SMTP unavailable'));
    await expect(service.submitForReview('venue-1', 'partner-1')).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
    expect(prisma.audit_events.create).not.toHaveBeenCalled();
  });

  it('does not resend a delivered agreement on submission retry', async () => {
    prisma.audit_events.findFirst.mockResolvedValue({ id: 'receipt' });
    await service.submitForReview('venue-1', 'partner-1');
    expect(mailService.sendSignedPartnerAgreementEmail).not.toHaveBeenCalled();
    expect(prisma.$transaction).toHaveBeenCalled();
  });

  it('does not duplicate admin notifications when Finish is retried', async () => {
    prisma.venues.updateMany.mockResolvedValue({ count: 0 });
    await service.submitForReview('venue-1', 'partner-1');
    expect((service as any).adminNotificationsService.notify).not.toHaveBeenCalled();
  });

  it('does not notify admins when the submission transaction fails', async () => {
    prisma.$transaction.mockRejectedValue(new Error('Submission failed'));
    await expect(service.submitForReview('venue-1', 'partner-1')).rejects.toThrow('Submission failed');
    expect((service as any).adminNotificationsService.notify).not.toHaveBeenCalled();
  });

  it('explains authentication failures without exposing SMTP details', async () => {
    mailService.sendSignedPartnerAgreementEmail.mockRejectedValue(
      Object.assign(new Error('sensitive provider response'), { code: 'EAUTH', responseCode: 535 }),
    );
    await expect(service.submitForReview('venue-1', 'partner-1')).rejects.toThrow(
      'Agreement email is temporarily unavailable. Please contact support@activ.live. Your signature is saved.',
    );
    expect((service as any).logger.error).toHaveBeenCalledWith(
      'Signed agreement email failed: code=EAUTH status=535',
    );
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('requires the signature and saved email', async () => {
    signedVenue.electronicSignature = '';
    await expect(service.submitForReview('venue-1', 'partner-1')).rejects.toBeInstanceOf(BadRequestException);
    signedVenue.electronicSignature = 'Lalit';
    signedVenue.partner.email = '';
    await expect(service.submitForReview('venue-1', 'partner-1')).rejects.toBeInstanceOf(BadRequestException);
    expect(mailService.sendSignedPartnerAgreementEmail).not.toHaveBeenCalled();
  });

  it('builds a readable signed PDF from the official agreement template', async () => {
    const agreement = await VenuesService.prototype.generatePartnerAgreementPdf.call(
      service, 'venue-1', { id: 'partner-1', role: 'partner' },
    );
    const pdf = await PDFDocument.load(Buffer.from(agreement.base64, 'base64'));
    expect(pdf.getPageCount()).toBe(3);
    expect(agreement.mimeType).toBe('application/pdf');
    expect(agreement.filename).toBe('activ-partner-agreement-venue-1.pdf');
  });

  it('rejects another partner before sending mail', async () => {
    await expect(service.submitForReview('venue-1', 'other')).rejects.toBeInstanceOf(ForbiddenException);
    expect(mailService.sendSignedPartnerAgreementEmail).not.toHaveBeenCalled();
  });

  it('preserves the signature date when Finish retries accepting the same terms', async () => {
    prisma.venues.findUnique.mockResolvedValue({ partner_id: 'partner-1', partner_venue_profiles: {
      electronic_signature: 'Lalit Jangid', terms_accepted_at: signedVenue.termsAcceptedAt,
    } });
    await service.acceptTerms('venue-1', 'partner-1', 'Lalit Jangid');
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
});
