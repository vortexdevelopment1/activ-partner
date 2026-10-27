import * as nodemailer from 'nodemailer';
import { MailService } from './mail.service';

jest.mock('nodemailer', () => ({ createTransport: jest.fn() }));

describe('signed agreement email via Google Workspace SMTP', () => {
  const params = {
    toEmail: 'registered@example.com', partnerName: 'Lalit Jangid',
    venueName: 'Spartna Club', signedAt: new Date('2026-10-16T10:00:00Z'),
    agreement: { base64: 'JVBERg==', filename: 'signed.pdf', mimeType: 'application/pdf' },
  };
  let config: Record<string, string>;
  let service: MailService;
  let sendMail: jest.Mock;
  let close: jest.Mock;

  beforeEach(() => {
    (nodemailer.createTransport as jest.Mock).mockClear();
    config = {
      MAIL_HOST: 'smtp.gmail.com', MAIL_PORT: '587', MAIL_USER: 'support@activ.live',
      MAIL_PASS: 'app-password', MAIL_FROM_EMAIL: 'support@activ.live',
    };
    sendMail = jest.fn().mockResolvedValue({ messageId: 'mail-1' });
    close = jest.fn();
    (nodemailer.createTransport as jest.Mock).mockReturnValue({ sendMail, close });
    service = Object.assign(Object.create(MailService.prototype), {
      configService: { get: (key: string, fallback?: string) => config[key] ?? fallback },
      googleOAuthService: { sendEmail: jest.fn().mockResolvedValue('gmail-1') },
    });
  });

  it('sends the required message and PDF through the Gmail API service', async () => {
    const pdfBuffer = Buffer.from('pdf');
    const messageId = await service.sendSignedAgreementEmailViaGmail({
      toEmail: params.toEmail,
      partnerName: params.partnerName,
      venueName: params.venueName,
      signedAt: params.signedAt,
      pdfBuffer,
      filename: params.agreement.filename,
    });
    expect(messageId).toBe('gmail-1');
    expect((service as any).googleOAuthService.sendEmail).toHaveBeenCalledWith(expect.objectContaining({
      recipientEmail: params.toEmail,
      recipientName: params.partnerName,
      subject: 'Your Signed Partnership Agreement – ACTIV Partner',
      text: expect.stringContaining('Your Partnership Agreement has been successfully signed.'),
      pdfBuffer,
      filename: 'signed.pdf',
      html: expect.stringContaining('Has Been Signed'),
      inlineImages: [expect.objectContaining({ cid: 'activ-partner-logo' })],
    }));
  });

  it('sends the signed PDF through the authorized support mailbox', async () => {
    await service.sendSignedPartnerAgreementEmail(params);
    expect(nodemailer.createTransport).toHaveBeenCalledWith(expect.objectContaining({
      host: 'smtp.gmail.com', port: 587, secure: false,
      auth: { user: 'support@activ.live', pass: 'app-password' },
    }));
    expect(sendMail).toHaveBeenCalledWith(expect.objectContaining({
      from: { name: 'ACTIV Partner Support', address: 'support@activ.live' },
      to: { name: 'Lalit Jangid', address: 'registered@example.com' },
      subject: 'Your Signed Partnership Agreement – ACTIV Partner',
      attachments: expect.arrayContaining([
        { filename: 'signed.pdf', content: Buffer.from('JVBERg==', 'base64'), contentType: 'application/pdf' },
        expect.objectContaining({ cid: 'activ-partner-logo' }),
      ]),
      html: expect.stringContaining('Has Been Signed'),
    }));
    expect(close).toHaveBeenCalled();
  });

  it('requires SMTP credentials', async () => {
    delete config.MAIL_PASS;
    await expect(service.sendSignedPartnerAgreementEmail(params)).rejects.toMatchObject({ code: 'SMTP_CONFIG' });
    expect(nodemailer.createTransport).not.toHaveBeenCalled();
  });

  it('does not hide provider failures', async () => {
    sendMail.mockRejectedValue(Object.assign(new Error('provider rejected'), { code: 'EAUTH', responseCode: 535 }));
    await expect(service.sendSignedPartnerAgreementEmail(params)).rejects.toMatchObject({ code: 'EAUTH', responseCode: 535 });
    expect(close).toHaveBeenCalled();
  });
});
