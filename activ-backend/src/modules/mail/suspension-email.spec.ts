import { MailService } from './mail.service';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

jest.mock('nodemailer', () => ({ createTransport: jest.fn() }));

describe('suspension emails', () => {
  const sender = { sendEmail: jest.fn() };
  let service: MailService;
  beforeEach(() => {
    sender.sendEmail.mockReset().mockResolvedValue('message-id');
    service = new MailService(new ConfigService({}), sender as any);
  });
  it('emails the venue name and exact reason with branded HTML and inline logo', async () => {
    await expect(service.sendSuspensionEmail({ toEmail: 'owner@example.com', partnerName: 'Owner', venueName: 'Arena', reason: 'Invalid business details' })).resolves.toBe(true);
    expect(sender.sendEmail).toHaveBeenCalledWith(expect.objectContaining({
      recipientEmail: 'owner@example.com', subject: 'Your ACTIV venue has been suspended',
      text: expect.stringContaining('Reason: Invalid business details'),
      html: expect.stringContaining('Has Been Suspended'),
      inlineImages: [expect.objectContaining({ cid: 'activ-partner-logo' })],
    }));
    expect(sender.sendEmail.mock.calls[0][0].text).toContain('Arena');
    expect(sender.sendEmail.mock.calls[0][0].text).toContain('support@activ.live');
  });
  it('uses account wording when the entire partner account is deactivated', async () => {
    await service.sendSuspensionEmail({ toEmail: 'owner@example.com', partnerName: 'Owner' });
    expect(sender.sendEmail.mock.calls[0][0].subject).toBe('Your ACTIV partner account has been suspended');
    expect(sender.sendEmail.mock.calls[0][0].text).toContain('Access to your partner account has been disabled');
  });
  it('reports missing recipients without attempting delivery', async () => {
    await expect(service.sendSuspensionEmail({ partnerName: 'Owner' })).resolves.toBe(false);
    expect(sender.sendEmail).not.toHaveBeenCalled();
  });
  it('handles provider failure without undoing suspension', async () => {
    sender.sendEmail.mockRejectedValue(new Error('Provider unavailable'));
    await expect(service.sendSuspensionEmail({ toEmail: 'owner@example.com', partnerName: 'Owner' })).resolves.toBe(false);
  });
  it('uses existing SMTP credentials and closes the transport after sending', async () => {
    const sendMail = jest.fn().mockResolvedValue({ messageId: 'message' });
    const close = jest.fn();
    (nodemailer.createTransport as jest.Mock).mockReturnValue({ sendMail, close });
    service = new MailService(new ConfigService({ MAIL_USER: 'sender@example.com', MAIL_PASS: 'test-password' }), sender as any);
    await expect(service.sendSuspensionEmail({ toEmail: 'owner@example.com', partnerName: 'Owner', venueName: 'Arena', reason: 'Fix details' })).resolves.toBe(true);
    expect(sendMail).toHaveBeenCalledWith(expect.objectContaining({ to: 'owner@example.com', subject: 'Your ACTIV venue has been suspended', text: expect.stringContaining('Fix details') }));
    expect(close).toHaveBeenCalled();
    expect(sender.sendEmail).not.toHaveBeenCalled();
  });
});
