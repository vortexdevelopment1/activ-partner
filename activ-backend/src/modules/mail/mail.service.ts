import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import { LegacyMailService } from './legacy-mail.service';
import { GoogleOAuthService } from './google-oauth.service';
import { EmailDeliveryService } from './email-delivery.service';
import { DeliveryResult, EmailJob, EmailMethod, EmailProvider } from './email-job';
import { EmailData, EmailTemplateId } from './templates/partner-email';

type Params<K extends keyof LegacyMailService> = LegacyMailService[K] extends (...args: infer A) => any ? A[0] : never;

@Injectable()
export class MailService extends LegacyMailService implements OnModuleInit {
  constructor(configService: ConfigService, googleOAuthService: GoogleOAuthService,
    private readonly deliveries?: EmailDeliveryService) {
    super(configService, googleOAuthService);
  }

  private provider(): EmailProvider {
    const provider = this.configService.get<string>('EMAIL_PROVIDER')?.trim() || 'legacy';
    if (!['legacy', 'gmail', 'smtp'].includes(provider)) throw new Error('EMAIL_PROVIDER must be legacy, gmail or smtp');
    return provider as EmailProvider;
  }

  onModuleInit() {
    const provider = this.provider();
    if (provider === 'gmail' && this.configService.get<string>('GOOGLE_SENDER_EMAIL')?.trim().toLowerCase() !== 'support@activ.live') {
      throw new Error('Gmail mode requires GOOGLE_SENDER_EMAIL=support@activ.live');
    }
    this.deliveries.configure(job => this.execute(job), this.deliveries.enabled(provider));
  }

  private job(method: EmailMethod, params: any, recipient: string, eventKey?: string): EmailJob {
    return { provider: this.provider(), method, params, recipient: recipient?.trim() || '',
      eventKey: eventKey || params.deliveryKey,
      expiresAt: method === 'reset' ? new Date(Date.now() + 600000).toISOString() : undefined };
  }

  private async dispatch(job: EmailJob): Promise<DeliveryResult> {
    if (!job.recipient) return { sent: false };
    if (this.deliveries?.enabled(job.provider)) return this.deliveries.send(job);
    if (job.provider !== 'legacy') throw Object.assign(new Error('Durable email delivery is required'), { code: 'EMAIL_CONFIG' });
    const messageId = await this.execute(job);
    return { sent: true, messageId };
  }

  private async notice(method: EmailMethod, params: any, recipient: string, eventKey?: string): Promise<boolean> {
    try { return (await this.dispatch(this.job(method, params, recipient, eventKey))).sent; }
    catch { this.logger?.warn(`Email could not be queued (${method}); business data is unchanged`); return false; }
  }

  async sendTemplateEmail(toEmail: string | null | undefined, id: EmailTemplateId, data: EmailData = {}): Promise<boolean> {
    return this.notice('template', { toEmail, id, data }, toEmail, data.deliveryKey);
  }

  async sendSignedAgreementEmailViaGmail(params: Params<'sendSignedAgreementEmailViaGmail'> & { deliveryKey?: string }): Promise<string> {
    const result = await this.dispatch(this.job('agreement', params, params.toEmail,
      params.deliveryKey || `agreement:${params.toEmail}:${new Date(params.signedAt).toISOString()}:${params.venueName}`));
    if (!result.sent) throw Object.assign(new Error('Agreement email is pending delivery; retry the email only'), { code: 'EMAIL_PENDING' });
    return result.messageId;
  }

  async sendSignedPartnerAgreementEmail(params: Params<'sendSignedPartnerAgreementEmail'>): Promise<void> {
    const result = await this.dispatch(this.job('smtpAgreement', params, params.toEmail));
    if (!result.sent) throw new Error('Agreement email is pending delivery');
  }
  async sendSuspensionEmail(params: Params<'sendSuspensionEmail'> & { deliveryKey?: string }): Promise<boolean> { return this.notice('suspension', params, params.toEmail); }
  async sendVenueChangesRequestedEmail(params: Params<'sendVenueChangesRequestedEmail'> & { partnerName?: string; deliveryKey?: string }): Promise<boolean> { return this.notice('changes', params, params.toEmail); }
  async sendPartnerApprovalEmail(params: Omit<Params<'sendPartnerApprovalEmail'>, 'password'> & { password?: string; deliveryKey?: string }): Promise<boolean> { return this.notice('approval', params, params.toEmail); }

  async findPartnerApprovalEmail(venueId: string, tx: any) {
    if (!this.deliveries) throw new Error('Durable approval email delivery is required');
    return this.deliveries.findApproval(venueId, tx);
  }

  async prepareTeamMemberInviteEmail(
    params: Params<'sendTeamMemberInviteEmail'> & { deliveryKey: string }, tx: any,
  ): Promise<string> {
    if (!this.deliveries) throw new Error('Durable invitation delivery is required');
    return (await this.deliveries.enqueue(this.job('invitation', params, params.toEmail), tx)).id;
  }

  /** Approval always requires an outbox, including migration-compatible legacy mode. */
  async preparePartnerApprovalEmail(params: Parameters<MailService['sendPartnerApprovalEmail']>[0], tx: any, alreadySent = false): Promise<string> {
    if (!this.deliveries) throw new Error('Durable approval email delivery is required');
    const row = await this.deliveries.enqueue(this.job('approval', params, params.toEmail), tx, alreadySent);
    return row.id;
  }
  async deliverPreparedEmail(id: string): Promise<boolean> {
    try { return (await this.deliveries.deliver(id)).sent; }
    catch { this.logger.warn('Prepared email is pending; use email delivery recovery'); return false; }
  }
  async sendTeamMemberInviteEmail(params: Params<'sendTeamMemberInviteEmail'>): Promise<boolean> { return this.notice('invitation', params, params.toEmail); }
  async sendPasswordResetEmail(params: Params<'sendPasswordResetEmail'> & { deliveryKey?: string; challengeKey?: string; expiresAt?: Date }): Promise<boolean> {
    try {
      const job = this.job('reset', params, params.toEmail);
      if (params.expiresAt) job.expiresAt = params.expiresAt.toISOString();
      const result = await this.dispatch(job);
      // Keep the ten-minute reset challenge valid while a known rejection is retried.
      return result.sent || result.queued === true;
    } catch { return false; }
  }
  async sendCallbackRequestEmail(params: Params<'sendCallbackRequestEmail'> & { deliveryKey?: string }): Promise<boolean> {
    return this.notice('callback', params, this.configService.get<string>('SUPPORT_EMAIL', 'support@activ.live'));
  }
  async sendSupportRequestEmail(params: Params<'sendSupportRequestEmail'> & { deliveryKey?: string }): Promise<string> {
    const result = await this.dispatch(this.job('support', params, this.configService.get<string>('SUPPORT_EMAIL', 'support@activ.live')));
    return result.sent ? result.messageId : '';
  }
  async sendPartnerRejectionEmail(params: Params<'sendPartnerRejectionEmail'> & { venueName?: string; deliveryKey?: string }): Promise<boolean> { return this.notice('rejection', params, params.toEmail); }

  private async execute(job: EmailJob): Promise<string> {
    if (job.provider !== this.provider()) throw Object.assign(new Error('Delivery provider differs from current configuration; review migration queue'), { status: 400 });
    const p = job.params;
    if (p.signedAt) p.signedAt = new Date(p.signedAt);
    if (job.provider === 'legacy') {
      let result: any;
      switch (job.method) {
        case 'template': result = await super.sendLegacyTemplateEmail(p.toEmail, p.id, p.data); break;
        case 'agreement': result = await super.sendSignedAgreementEmailViaGmail(p); break;
        case 'smtpAgreement': await super.sendSignedPartnerAgreementEmail(p); result = true; break;
        case 'suspension': result = await super.sendSuspensionEmail(p); break;
        case 'changes': result = await super.sendVenueChangesRequestedEmail(p); break;
        case 'approval': result = await super.sendPartnerApprovalEmail(p); break;
        case 'invitation': result = await super.sendTeamMemberInviteEmail(p); break;
        case 'reset': result = await super.sendPasswordResetEmail(p); break;
        case 'callback': result = await super.sendCallbackRequestEmail(p); break;
        case 'support': result = await super.sendSupportRequestEmail(p); break;
        case 'rejection': result = await super.sendPartnerRejectionEmail(p); break;
      }
      if (!result) throw Object.assign(new Error('Legacy delivery was not confirmed'), { code: 'LEGACY_UNCONFIRMED' });
      return typeof result === 'string' ? result : 'legacy-accepted';
    }
    const message = this.buildMessage(job);
    if (job.provider === 'gmail') return this.googleOAuthService.sendEmail(message);
    const user = this.configService.get<string>('MAIL_USER');
    const pass = this.configService.get<string>('MAIL_PASS');
    if (!user || !pass) throw Object.assign(new Error('SMTP is not configured'), { code: 'EMAIL_CONFIG' });
    const port = Number(this.configService.get('MAIL_PORT') || 587);
    const transport = nodemailer.createTransport({ host: this.configService.get('MAIL_HOST') || 'smtp.gmail.com',
      port, secure: port === 465, auth: { user, pass }, connectionTimeout: 15000, greetingTimeout: 15000, socketTimeout: 15000 });
    try {
      const sent = await transport.sendMail({ from: { name: 'ACTIV Partner Support', address: this.configService.get('MAIL_FROM_EMAIL') || user },
        to: message.recipientEmail, replyTo: this.configService.get('SUPPORT_EMAIL') || 'support@activ.live',
        subject: message.subject, html: message.html, text: message.text,
        attachments: [...(message.inlineImages || []), ...(message.pdfBuffer ? [{ filename: message.filename, content: message.pdfBuffer, contentType: 'application/pdf' }] : [])] });
      return sent.messageId || 'smtp-accepted';
    } finally { transport.close(); }
  }

  private buildMessage(job: EmailJob): Parameters<GoogleOAuthService['sendEmail']>[0] {
    const p = job.params;
    let id: EmailTemplateId;
    let data: EmailData = { ...p };
    switch (job.method) {
      case 'template': id = p.id; data = p.data; break;
      case 'agreement': case 'smtpAgreement': id = 'agreement_signed'; data.signedAt = new Date(p.signedAt).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', dateStyle: 'long', timeStyle: 'short' }); break;
      case 'suspension': id = p.venueName ? 'venue_suspended' : 'partner_suspended'; break;
      case 'changes': id = 'venue_changes_requested'; break;
      case 'approval': id = 'venue_approved'; data.email = p.toEmail;
        if (!p.password) data.message = 'Sign in with your phone OTP or existing password. Use Forgot Password if you need to set a password.';
        break;
      case 'invitation': id = 'team_invitation'; data.partnerName = p.fullName; data.email = p.toEmail;
        data.message = 'Sign in using your invited phone number and phone OTP, or your existing password.';
        break;
      case 'reset': id = 'password_reset'; data.partnerName = p.firstName; break;
      case 'rejection': id = 'venue_rejected'; data.partnerName = p.firstName; data.reference = p.venueId; data.reason = p.rejectionReason; break;
      case 'support': return { recipientEmail: job.recipient, recipientName: 'ACTIV Support',
        subject: `[Partner Support] ${p.subject}`, text: `Partner: ${p.partnerName}\nEmail: ${p.partnerEmail || 'Not provided'}\n\n${p.message}` };
      case 'callback': id = 'callback_request'; data.email = p.partnerEmail; data.message = p.query; break;
    }
    return { ...this.brandedEmail(id, data), recipientEmail: job.recipient,
      recipientName: job.method === 'callback' ? 'ACTIV Support' : data.partnerName,
      inlineImages: [this.logoAttachment()],
      ...(job.method === 'agreement' ? { pdfBuffer: p.pdfBuffer, filename: p.filename } : {}),
      ...(job.method === 'smtpAgreement' ? { pdfBuffer: Buffer.from(p.agreement.base64, 'base64'), filename: p.agreement.filename } : {}) };
  }
}
