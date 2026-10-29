import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import { MailService } from './mail.service';

jest.mock('nodemailer', () => ({ createTransport: jest.fn() }));

describe('explicit Gmail-only email routing', () => {
  let service: MailService;
  let gmail: any;
  let delivery: any;
  let execute: any;
  beforeEach(() => {
    gmail = { sendEmail: jest.fn().mockResolvedValue('gmail-1') };
    delivery = { enabled: jest.fn().mockReturnValue(true), configure: jest.fn(callback => { execute = callback; }),
      send: jest.fn(async job => ({ sent: true, messageId: await execute(job) })) };
    service = new MailService(new ConfigService({ EMAIL_PROVIDER: 'gmail', GOOGLE_SENDER_EMAIL: 'support@activ.live',
      MAIL_USER: 'legacy@example.com', MAIL_PASS: 'legacy-password', MSG91_AUTHKEY: 'legacy-key' }), gmail, delivery);
    service.onModuleInit();
    (nodemailer.createTransport as jest.Mock).mockClear();
  });

  it('uses Gmail for all active email categories despite configured SMTP/MSG91', async () => {
    const base = { toEmail: 'owner@example.com', partnerName: 'Owner', venueName: 'Arena' };
    await service.sendTemplateEmail(base.toEmail, 'bank_approved', { partnerName: 'Owner', bankName: 'Bank', accountLast4: '1234' });
    await service.sendPartnerApprovalEmail({ ...base, password: 'temporary' });
    await service.sendPartnerRejectionEmail({ toEmail: base.toEmail, firstName: 'Owner', venueId: 'venue', venueName: 'Arena', rejectionReason: 'Address' });
    await service.sendVenueChangesRequestedEmail({ ...base, reason: 'Update photos' });
    await service.sendSuspensionEmail({ ...base, reason: 'Verification' });
    await service.sendPasswordResetEmail({ toEmail: base.toEmail, firstName: 'Owner', code: '1234' });
    await service.sendSupportRequestEmail({ partnerName: 'Owner', subject: 'Help', message: 'Message' });
    await service.sendCallbackRequestEmail({ partnerName: 'Owner', partnerEmail: base.toEmail, venueName: 'Arena', phone: '123', city: 'Delhi', callbackDate: '2026-10-29', callbackTime: '10:00', query: 'Help' });
    await service.sendSignedAgreementEmailViaGmail({ ...base, signedAt: new Date(), pdfBuffer: Buffer.from('pdf'), filename: 'signed.pdf' });
    expect(gmail.sendEmail).toHaveBeenCalledTimes(9);
    expect(nodemailer.createTransport).not.toHaveBeenCalled();
    expect(global.fetch).not.toHaveBeenCalled();
    expect(gmail.sendEmail.mock.calls[8][0]).toMatchObject({ pdfBuffer: Buffer.from('pdf'), filename: 'signed.pdf',
      inlineImages: [expect.objectContaining({ cid: 'activ-partner-logo' })] });
    expect(gmail.sendEmail.mock.calls[1][0].html).toContain('Arena');
  });

  it('never falls back to SMTP/MSG91 on Gmail rejection', async () => {
    gmail.sendEmail.mockRejectedValue(new Error('provider unavailable'));
    expect(await service.sendVenueChangesRequestedEmail({ toEmail: 'owner@example.com', venueName: 'Arena', reason: 'Fix' })).toBe(false);
    expect(nodemailer.createTransport).not.toHaveBeenCalled();
    expect(global.fetch).not.toHaveBeenCalled();
  });

  it('rejects unknown providers and the wrong Gmail sender at startup', () => {
    expect(() => new MailService(new ConfigService({ EMAIL_PROVIDER: 'typo' }), gmail, delivery).onModuleInit()).toThrow('EMAIL_PROVIDER');
    expect(() => new MailService(new ConfigService({ EMAIL_PROVIDER: 'gmail', GOOGLE_SENDER_EMAIL: 'someone@example.com' }), gmail, delivery).onModuleInit()).toThrow('support@activ.live');
  });

  it('does not send an old-provider queued email after a migration switch', async () => {
    await expect(execute({ provider: 'legacy', method: 'callback', params: {}, recipient: 'owner@example.com' })).rejects.toMatchObject({ status: 400 });
    expect(gmail.sendEmail).not.toHaveBeenCalled();
  });

  it('supports explicit SMTP mode without calling Gmail or MSG91', async () => {
    const sendMail = jest.fn().mockResolvedValue({ messageId: 'smtp-1' });
    const close = jest.fn();
    (nodemailer.createTransport as jest.Mock).mockReturnValue({ sendMail, close });
    service = new MailService(new ConfigService({ EMAIL_PROVIDER: 'smtp', MAIL_USER: 'sender@example.com', MAIL_PASS: 'test' }), gmail, delivery);
    service.onModuleInit();
    expect(await service.sendSupportRequestEmail({ partnerName: 'Owner', subject: 'Help', message: 'Details' })).toBe('smtp-1');
    expect(sendMail).toHaveBeenCalledWith(expect.objectContaining({ subject: '[Partner Support] Help', text: expect.stringContaining('Details') }));
    expect(close).toHaveBeenCalled();
    expect(gmail.sendEmail).not.toHaveBeenCalled();
    expect(global.fetch).not.toHaveBeenCalled();
  });
});
