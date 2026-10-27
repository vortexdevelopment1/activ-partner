import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import { EMAIL_TEMPLATES, EmailTemplateId, renderPartnerEmail } from './templates/partner-email';
import { MailService } from './mail.service';
import { PartnerEmailService } from './partner-email.service';

jest.mock('nodemailer', () => ({ createTransport: jest.fn() }));

describe('branded partner email catalogue', () => {
  it.each(Object.keys(EMAIL_TEMPLATES) as EmailTemplateId[])('%s includes HTML and plain text with escaped dynamic content', id => {
    const mail = renderPartnerEmail(id, { partnerName: '<script>bad</script>', venueName: 'Arena & Club', reason: '<img src=x onerror=bad()>', reference: 'REF-1' });
    expect(mail.html).toContain('cid:activ-partner-logo');
    expect(mail.html).toContain('Team ACTIV');
    expect(mail.html).toContain('Arena &amp; Club');
    expect(mail.html).not.toContain('<script>bad');
    expect(mail.html).not.toContain('<img src=x');
    expect(mail.text).toContain('REF-1');
    expect(mail.subject).toBeTruthy();
  });
  it('masks bank details and replaces unsafe footer URLs', () => {
    const mail = renderPartnerEmail('bank_approved', { accountLast4: '123456789012' }, { projectUrl: 'javascript:alert(1)', instagramUrl: 'javascript:alert(2)' });
    expect(mail.html).toContain('Ending in 9012');
    expect(mail.html).not.toContain('123456789012');
    expect(mail.html).not.toContain('javascript:');
    expect(mail.html).toContain('https://activ-partner.vercel.app/');
  });
  it('uses SMTP HTML, text and embedded logo without a second provider send', async () => {
    const sendMail = jest.fn().mockResolvedValue({}); const close = jest.fn();
    (nodemailer.createTransport as jest.Mock).mockReturnValue({ sendMail, close });
    const gmail = { sendEmail: jest.fn() };
    const service = new MailService(new ConfigService({ MAIL_USER: 'sender@example.com', MAIL_PASS: 'test' }), gmail as any);
    expect(await service.sendTemplateEmail('partner@example.com', 'venue_under_review', { venueName: 'Arena' })).toBe(true);
    expect(sendMail).toHaveBeenCalledWith(expect.objectContaining({ html: expect.stringContaining('Is Under Review'), text: expect.stringContaining('Arena'), attachments: [expect.objectContaining({ cid: 'activ-partner-logo' })] }));
    expect(close).toHaveBeenCalled(); expect(gmail.sendEmail).not.toHaveBeenCalled();
  });
  it('isolates provider failures and skips missing recipients', async () => {
    const gmail = { sendEmail: jest.fn().mockRejectedValue(new Error('offline')) };
    const service = new MailService(new ConfigService({}), gmail as any);
    expect(await service.sendTemplateEmail(undefined, 'support_received')).toBe(false);
    expect(gmail.sendEmail).not.toHaveBeenCalled();
    expect(await service.sendTemplateEmail('partner@example.com', 'support_received')).toBe(false);
  });
  it('resolves the owning partner and uses the registered profile as fallback', async () => {
    const prisma = { partner_users: { findFirst: jest.fn().mockResolvedValue(null) }, partner_business_profiles: { findUnique: jest.fn().mockResolvedValue({ email: 'owner@example.com', owner_name: 'Owner' }) } };
    const mail = { sendTemplateEmail: jest.fn().mockResolvedValue(true) };
    const service = new PartnerEmailService(prisma as any, mail as any);
    await service.send('partner-id', 'bank_approved', { accountLast4: '4321' });
    expect(prisma.partner_users.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { partner_id: 'partner-id', role: 'PARTNER_ADMIN' } }));
    expect(mail.sendTemplateEmail).toHaveBeenCalledWith('owner@example.com', 'bank_approved', { partnerName: 'Owner', accountLast4: '4321' });
  });
});
