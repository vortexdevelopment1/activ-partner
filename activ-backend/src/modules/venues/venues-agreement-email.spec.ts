import { BadRequestException, ForbiddenException } from '@nestjs/common';
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
        update: jest.fn().mockResolvedValue({}) },
      partner_venue_services: { updateMany: jest.fn().mockResolvedValue({}) },
      audit_events: { findFirst: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue({}) },
      $transaction: jest.fn().mockResolvedValue([]),
    };
    mailService = { sendSignedAgreementEmailViaGmail: jest.fn().mockResolvedValue('gmail-message-id') };
    service = Object.assign(Object.create(VenuesService.prototype), {
      prisma, mailService, logger: { error: jest.fn() }, findOne: jest.fn().mockResolvedValue(signedVenue),
      generatePartnerAgreementPdf: jest.fn().mockResolvedValue({ base64: 'JVBERg==', filename: 'signed.pdf', mimeType: 'application/pdf' }),
    });
  });

  afterEach(() => {
    if (originalEmailEnabled === undefined) delete process.env.SIGNED_AGREEMENT_EMAIL_ENABLED;
    else process.env.SIGNED_AGREEMENT_EMAIL_ENABLED = originalEmailEnabled;
  });

  it('sends the agreement before completing review submission', async () => {
    const result = await service.submitForReview('venue-1', 'partner-1');
    expect(result).toMatchObject({ agreementEmailSent: true });
    expect(mailService.sendSignedAgreementEmailViaGmail).toHaveBeenCalled();
    expect(service.generatePartnerAgreementPdf).toHaveBeenCalled();
    expect(prisma.audit_events.create).toHaveBeenCalled();
    expect(prisma.venues.update).toHaveBeenCalledWith(expect.objectContaining({
      data: { submitted_at: expect.any(Date) },
    }));
    expect(prisma.partner_venue_services.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      data: { status: 'PENDING', updated_at: expect.any(Date) },
    }));
    expect(prisma.$transaction).toHaveBeenCalled();
  });

  it('emails the signed agreement to the saved profile email on Finish', async () => {
    await service.submitForReview('venue-1', 'partner-1');
    expect(mailService.sendSignedAgreementEmailViaGmail).toHaveBeenCalledWith(expect.objectContaining({
      toEmail: 'registered@example.com', partnerName: 'Lalit Jangid',
      filename: 'signed.pdf', pdfBuffer: expect.any(Buffer),
    }));
    expect(prisma.audit_events.create).toHaveBeenCalled();
    expect(prisma.$transaction).toHaveBeenCalled();
  });

  it('keeps registration under review when delivery fails and exposes retry state', async () => {
    mailService.sendSignedAgreementEmailViaGmail.mockRejectedValue(new Error('Gmail unavailable'));
    const result = await service.submitForReview('venue-1', 'partner-1');
    expect(result).toMatchObject({ agreementEmailSent: false, agreementEmailError: expect.stringContaining('retry') });
    expect(prisma.$transaction).toHaveBeenCalled();
    expect(prisma.audit_events.create).not.toHaveBeenCalled();
  });

  it('does not resend a delivered agreement on submission retry', async () => {
    prisma.audit_events.findFirst.mockResolvedValue({ id: 'receipt' });
    await service.submitForReview('venue-1', 'partner-1');
    expect(mailService.sendSignedAgreementEmailViaGmail).not.toHaveBeenCalled();
    expect(prisma.$transaction).toHaveBeenCalled();
  });

  it('handles repeated Finish requests after the venue is already submitted', async () => {
    prisma.venues.findUnique
      .mockResolvedValueOnce({ id: 'venue-1', partner_id: 'partner-1', status: 'DRAFT' })
      .mockResolvedValueOnce({ id: 'venue-1', partner_id: 'partner-1', status: 'PENDING', submitted_at: new Date() });
    prisma.audit_events.findFirst.mockResolvedValue({ id: 'receipt' });
    await service.submitForReview('venue-1', 'partner-1');
    const result = await service.submitForReview('venue-1', 'partner-1');
    expect(result).toMatchObject({ agreementEmailSent: true });
    expect(mailService.sendSignedAgreementEmailViaGmail).not.toHaveBeenCalled();
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
  });

  it('logs provider diagnostics without exposing them to the partner', async () => {
    mailService.sendSignedAgreementEmailViaGmail.mockRejectedValue(
      Object.assign(new Error('sensitive provider response'), { code: 'EAUTH', responseCode: 535 }),
    );
    const result = await service.submitForReview('venue-1', 'partner-1');
    expect(result.agreementEmailError).toContain('could not be sent');
    expect((service as any).logger.error).toHaveBeenCalledWith(
      'Signed agreement email failed: code=EAUTH status=535',
    );
    expect(prisma.$transaction).toHaveBeenCalled();
  });

  it('requires the signature and saved email', async () => {
    signedVenue.electronicSignature = '';
    await expect(service.submitForReview('venue-1', 'partner-1')).rejects.toBeInstanceOf(BadRequestException);
    signedVenue.electronicSignature = 'Lalit';
    signedVenue.partner.email = '';
    const result = await service.submitForReview('venue-1', 'partner-1');
    expect(result.agreementEmailSent).toBe(false);
    expect(result.agreementEmailError).toContain('no registered email');
    expect(mailService.sendSignedAgreementEmailViaGmail).not.toHaveBeenCalled();
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
    expect(mailService.sendSignedAgreementEmailViaGmail).not.toHaveBeenCalled();
  });

  it('preserves the signature date when Finish retries accepting the same terms', async () => {
    prisma.venues.findUnique.mockResolvedValue({ partner_id: 'partner-1', partner_venue_profiles: {
      electronic_signature: 'Lalit Jangid', terms_accepted_at: signedVenue.termsAcceptedAt,
    } });
    await service.acceptTerms('venue-1', 'partner-1', 'Lalit Jangid');
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
});
