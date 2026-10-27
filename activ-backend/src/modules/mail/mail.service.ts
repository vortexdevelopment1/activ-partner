import { Injectable, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import * as nodemailer from "nodemailer";
import { GoogleOAuthService } from "./google-oauth.service";
import * as path from 'path';
import * as fs from 'fs';
import { EmailData, EmailTemplateId, renderPartnerEmail } from './templates/partner-email';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  constructor(
    private configService: ConfigService,
    private readonly googleOAuthService: GoogleOAuthService,
  ) {}

  private brandedEmail(id: EmailTemplateId, data: EmailData) {
    const get = (key: string) => this.configService.get<string>(key);
    return renderPartnerEmail(id, data, {
      projectUrl: get('PARTNER_APP_URL'), websiteUrl: get('EMAIL_WEBSITE_URL'),
      supportEmail: get('SUPPORT_EMAIL'), appStoreUrl: get('EMAIL_APP_STORE_URL'),
      playStoreUrl: get('EMAIL_PLAY_STORE_URL'), instagramUrl: get('EMAIL_INSTAGRAM_URL'),
      linkedinUrl: get('EMAIL_LINKEDIN_URL'), youtubeUrl: get('EMAIL_YOUTUBE_URL'), xUrl: get('EMAIL_X_URL'),
    });
  }

  private logoAttachment() {
    return { filename: 'activ-partner-logo.png', content: fs.readFileSync(path.join(__dirname, 'templates/assets/activ-partner-logo.png')), contentType: 'image/png', cid: 'activ-partner-logo' };
  }

  private hasBrandedTransport(): boolean {
    return Boolean((this.configService.get('MAIL_USER') && this.configService.get('MAIL_PASS')) || this.googleOAuthService.hasRefreshToken?.());
  }

  /** Transactional notices are best effort; a mail outage must not undo a saved request. */
  async sendTemplateEmail(toEmail: string | null | undefined, id: EmailTemplateId, data: EmailData = {}): Promise<boolean> {
    if (!toEmail?.trim()) return false;
    try {
      const email = this.brandedEmail(id, data);
      const logo = this.logoAttachment();
      const user = this.configService.get<string>('MAIL_USER');
      const pass = this.configService.get<string>('MAIL_PASS');
      if (user && pass) {
        const port = Number(this.configService.get('MAIL_PORT') || 587);
        const transport = nodemailer.createTransport({
          host: this.configService.get('MAIL_HOST') || 'smtp.gmail.com', port,
          secure: port === 465, auth: { user, pass },
          connectionTimeout: 15000, greetingTimeout: 15000, socketTimeout: 15000,
        });
        try {
          await transport.sendMail({ from: { name: 'ACTIV Partner', address: this.configService.get('MAIL_FROM_EMAIL') || user },
            to: toEmail.trim(), replyTo: this.configService.get('SUPPORT_EMAIL') || 'support@activ.live',
            ...email, attachments: [logo] });
        } finally { transport.close(); }
      } else {
        await this.googleOAuthService.sendEmail({ recipientEmail: toEmail.trim(), recipientName: data.partnerName,
          ...email, inlineImages: [logo] });
      }
      return true;
    } catch {
      this.logger?.warn(`Partner email delivery failed (${id}); the saved application/request is unchanged`);
      return false;
    }
  }

  async sendSignedAgreementEmailViaGmail(params: {
    toEmail: string;
    partnerName: string;
    venueName: string;
    signedAt: Date;
    pdfBuffer: Buffer;
    filename: string;
  }): Promise<string> {
    const signedAt = params.signedAt.toLocaleString("en-IN", {
      timeZone: "Asia/Kolkata",
      dateStyle: "long",
      timeStyle: "short",
    });
    return this.googleOAuthService.sendEmail({
      ...this.brandedEmail('agreement_signed', { partnerName: params.partnerName, venueName: params.venueName, signedAt }),
      recipientEmail: params.toEmail,
      recipientName: params.partnerName,
      subject: "Your Signed Partnership Agreement – ACTIV Partner",
      text: `Dear ${params.partnerName},\n\nThank you for completing your registration with ACTIV Partner.\n\nYour Partnership Agreement has been successfully signed.\n\nPlease find a copy of your signed Partnership Agreement attached for your records.\n\nOur team will review your venue registration and notify you of the next steps.\n\nBest regards,\nACTIV Partner Support Team`,
      pdfBuffer: params.pdfBuffer,
      filename: params.filename,
      html: this.brandedEmail('agreement_signed', { partnerName: params.partnerName, venueName: params.venueName, signedAt }).html,
      inlineImages: [this.logoAttachment()],
    });
  }

  async sendSignedPartnerAgreementEmail(params: {
    toEmail: string;
    partnerName: string;
    venueName: string;
    signedAt: Date;
    agreement: { base64: string; filename: string; mimeType: string };
  }): Promise<void> {
    const signedAt = params.signedAt.toLocaleString("en-IN", {
      timeZone: "Asia/Kolkata",
      dateStyle: "long",
      timeStyle: "short",
    });
    const host = this.configService.get<string>("MAIL_HOST", "smtp.gmail.com");
    const port = Number(this.configService.get<string>("MAIL_PORT", "587"));
    const user = this.configService.get<string>("MAIL_USER")?.trim();
    const pass = this.configService.get<string>("MAIL_PASS");
    const fromEmail = this.configService.get<string>(
      "MAIL_FROM_EMAIL",
      "support@activ.live",
    );
    if (!user || !pass || !fromEmail) {
      throw Object.assign(new Error("SMTP agreement email is not configured"), {
        code: "SMTP_CONFIG",
      });
    }
    const transport = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
      connectionTimeout: 30000,
      greetingTimeout: 30000,
      socketTimeout: 30000,
    });
    try {
      await transport.sendMail({
        from: { name: "ACTIV Partner Support", address: fromEmail },
        to: { name: params.partnerName, address: params.toEmail },
        replyTo: "support@activ.live",
        subject: "Your Signed Partnership Agreement – ACTIV Partner",
        text: `Hello ${params.partnerName},\n\nPlease find your signed partnership agreement attached.\n\nVenue: ${params.venueName}\nAccepted: ${signedAt} (IST)\n\nACTIV Partner Support`,
        attachments: [
          this.logoAttachment(),
          {
            filename: params.agreement.filename,
            content: Buffer.from(params.agreement.base64, "base64"),
            contentType: params.agreement.mimeType,
          },
        ],
        html: this.brandedEmail('agreement_signed', { partnerName: params.partnerName, venueName: params.venueName, signedAt }).html,
      });
    } finally {
      transport.close();
    }
  }

  async sendSuspensionEmail(params: {
    toEmail?: string | null;
    partnerName: string;
    venueName?: string;
    reason?: string;
  }): Promise<boolean> {
    if (!params.toEmail?.trim()) {
      this.logger.warn('Suspension email not sent: partner has no registered email');
      return false;
    }
    const subject = params.venueName ? 'Your ACTIV venue has been suspended' : 'Your ACTIV partner account has been suspended';
    const branded = this.brandedEmail(params.venueName ? 'venue_suspended' : 'partner_suspended', params);
    const notice = params.venueName
      ? `Your venue "${params.venueName}" has been suspended and is no longer available for new bookings on ACTIV.`
      : 'Your ACTIV partner account has been suspended. Access to your partner account has been disabled.';
    const text = `Hello ${params.partnerName || 'Partner'},\n\n${notice}\n\n${params.reason ? `Reason: ${params.reason}\n\n` : ''}Please contact support@activ.live for clarification and assistance with reactivation.\n\nTeam ACTIV`;
    try {
      const user = this.configService.get<string>('MAIL_USER')?.trim();
      const pass = this.configService.get<string>('MAIL_PASS');
      if (user && pass) {
        const port = Number(this.configService.get<string>('MAIL_PORT', '587'));
        const transport = nodemailer.createTransport({
          host: this.configService.get<string>('MAIL_HOST', 'smtp.gmail.com'),
          port, secure: port === 465, auth: { user, pass },
          connectionTimeout: 15000, greetingTimeout: 15000, socketTimeout: 15000,
        });
        try {
          await transport.sendMail({
            from: { name: 'ACTIV Partner Support', address: this.configService.get<string>('MAIL_FROM_EMAIL', user) },
            to: params.toEmail.trim(), replyTo: 'support@activ.live', subject, text,
            html: branded.html, attachments: [this.logoAttachment()],
          });
        } finally {
          transport.close();
        }
      } else {
        await this.googleOAuthService.sendEmail({ recipientEmail: params.toEmail.trim(), subject, text, html: branded.html, inlineImages: [this.logoAttachment()] });
      }
      return true;
    } catch {
      this.logger.warn('Suspension email delivery failed; check SMTP/Gmail configuration and email delivery logs');
      return false;
    }
  }

  async sendVenueChangesRequestedEmail(params: {
    toEmail: string; venueName: string; reason: string;
  }): Promise<boolean> {
    if (this.hasBrandedTransport()) return this.sendTemplateEmail(params.toEmail, 'venue_changes_requested', params);
    const authkey = this.configService.get<string>('MSG91_AUTHKEY');
    const templateId = this.configService.get<string>('MSG91_VENUE_CHANGES_TEMPLATE_ID');
    if (!authkey || !templateId?.trim()) {
      this.logger.warn('Venue changes email not sent: configure MSG91_AUTHKEY and MSG91_VENUE_CHANGES_TEMPLATE_ID');
      return false;
    }
    try {
      const response = await fetch('https://control.msg91.com/api/v5/email/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json', authkey },
        signal: AbortSignal.timeout(15000),
        body: JSON.stringify({
          from: { email: this.configService.get<string>('MSG91_FROM_EMAIL') },
          domain: this.configService.get<string>('MSG91_DOMAIN'),
          template_id: templateId.trim(),
          recipients: [{ to: [{ email: params.toEmail }], variables: {
            venueName: params.venueName, reason: params.reason,
            instructions: 'Sign in with your phone OTP, update your venue details and submit again for review.',
          } }],
        }),
      });
      const result = await response.json();
      if (!response.ok || result?.status === 'fail' || result?.status === 'error' || result?.success === false) {
        this.logger.warn('Venue changes email was rejected by the provider');
        return false;
      }
      return true;
    } catch {
      this.logger.warn('Venue changes email delivery failed');
      return false;
    }
  }

  async sendPartnerApprovalEmail(params: {
    toEmail: string;
    partnerName: string;
    venueName: string;
    password: string;
  }): Promise<boolean> {
    const { toEmail, partnerName, venueName, password } = params;
    if (this.hasBrandedTransport()) return this.sendTemplateEmail(toEmail, 'venue_approved', { partnerName, venueName, password, email: toEmail });
    const authkey = this.configService.get<string>("MSG91_AUTHKEY");
    const fromEmail = this.configService.get<string>("MSG91_FROM_EMAIL");
    const domain = this.configService.get<string>("MSG91_DOMAIN");
    const appLink = this.configService.get<string>(
      "PARTNER_APP_URL",
      "https://activ.co.in/login",
    );
    const templateId = this.configService.get<string>(
      "MSG91_APPROVAL_TEMPLATE_ID",
      "partnerapprovaltemplate",
    );

    const body = {
      recipients: [
        {
          to: [{ email: toEmail, name: partnerName }],
          variables: {
            partnerName,
            email: toEmail,
            newPassword: password,
            appLink,
            venueName,
          },
        },
      ],
      from: { email: fromEmail },
      domain,
      template_id: templateId,
    };

    try {
      const response = await fetch(
        "https://control.msg91.com/api/v5/email/send",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            authkey,
          },
          body: JSON.stringify(body),
        },
      );
      const result = (await response.json()) as any;
      if (!response.ok) {
        this.logger.error(
          `MSG91 approval email failed for ${toEmail}: ${JSON.stringify(result)}`,
        );
        return false;
      } else {
        this.logger.log(`Approval email sent to ${toEmail} via MSG91`);
        return true;
      }
    } catch (error) {
      this.logger.error(
        `Failed to send approval email to ${toEmail}: ${error.message}`,
      );
      return false;
    }
  }

  async sendTeamMemberInviteEmail(params: {
    toEmail: string;
    fullName: string;
    password: string;
    role: string;
  }) {
    const { toEmail, fullName, password, role } = params;
    if (this.hasBrandedTransport()) return this.sendTemplateEmail(toEmail, 'team_invitation', { partnerName: fullName, password, role, email: toEmail });
    const authkey = this.configService.get<string>("MSG91_AUTHKEY");
    const fromEmail = this.configService.get<string>("MSG91_FROM_EMAIL");
    const domain = this.configService.get<string>("MSG91_DOMAIN");
    const appLink = this.configService.get<string>(
      "PARTNER_APP_URL",
      "https://activ.co.in/login",
    );

    const body = {
      recipients: [
        {
          to: [{ email: toEmail, name: fullName }],
          variables: {
            fullName,
            email: toEmail,
            password,
            role,
            appLink,
          },
        },
      ],
      from: { email: fromEmail },
      domain,
      template_id: "teammemberinvite_2",
    };

    try {
      const response = await fetch(
        "https://control.msg91.com/api/v5/email/send",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            authkey,
          },
          body: JSON.stringify(body),
        },
      );
      const result = (await response.json()) as any;
      if (!response.ok) {
        this.logger.error(
          `MSG91 team invite email failed for ${toEmail}: ${JSON.stringify(result)}`,
        );
      } else {
        this.logger.log(`Team invite email sent to ${toEmail} via MSG91`);
      }
    } catch (error) {
      this.logger.error(
        `Failed to send team invite email to ${toEmail}: ${error.message}`,
      );
    }
  }

  async sendTeamMemberInviteSms(params: {
    phone: string;
    fullName: string;
    role: string;
    password: string;
  }): Promise<boolean> {
    const authkey = this.configService.get<string>("MSG91_AUTHKEY")?.trim();
    const templateId = this.configService
      .get<string>("MSG91_TEAM_INVITE_TEMPLATE_ID")
      ?.trim();
    const appLink = this.configService.get<string>(
      "PARTNER_APP_URL",
      "https://activ.co.in/login",
    );

    if (!authkey || !templateId) {
      this.logger.error(
        "Team invite SMS was not sent: MSG91_AUTHKEY or MSG91_TEAM_INVITE_TEMPLATE_ID is missing.",
      );
      return false;
    }

    const digits = params.phone.replace(/\D/g, "");
    const mobile = digits.length === 10 ? `91${digits}` : digits;
    if (mobile.length < 10) {
      this.logger.error(
        `Team invite SMS was not sent: invalid phone ${params.phone}`,
      );
      return false;
    }

    const body = {
      template_id: templateId,
      short_url: "0",
      recipients: [
        {
          mobiles: mobile,
          VAR1: params.fullName,
          VAR2: params.role,
          VAR3: appLink,
          VAR4: params.password,
        },
      ],
    };

    try {
      const response = await fetch("https://control.msg91.com/api/v5/flow", {
        method: "POST",
        headers: {
          authkey,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify(body),
      });
      const result = (await response.json()) as any;
      const accepted = response.ok && result?.type !== "error";
      if (!accepted) {
        this.logger.error(
          `MSG91 team invite SMS failed for ${mobile}: ${JSON.stringify(result)}`,
        );
        return false;
      }

      this.logger.log(`Team invite SMS accepted by MSG91 for ${mobile}`);
      return true;
    } catch (error) {
      this.logger.error(
        `Failed to send team invite SMS to ${mobile}: ${error.message}`,
      );
      return false;
    }
  }

  async sendPasswordResetEmail(params: {
    toEmail: string;
    firstName: string;
    code: string;
  }) {
    const { toEmail, firstName, code } = params;
    if (this.hasBrandedTransport()) return this.sendTemplateEmail(toEmail, 'password_reset', { partnerName: firstName, code });
    const authkey = this.configService.get<string>("MSG91_AUTHKEY");
    const fromEmail = this.configService.get<string>("MSG91_FROM_EMAIL");
    const domain = this.configService.get<string>("MSG91_DOMAIN");

    const body = {
      recipients: [
        {
          to: [{ email: toEmail, name: firstName }],
          variables: {
            firstName,
            code,
          },
        },
      ],
      from: { email: fromEmail },
      domain,
      template_id: "passwordresetcode",
    };

    try {
      const response = await fetch(
        "https://control.msg91.com/api/v5/email/send",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            authkey,
          },
          body: JSON.stringify(body),
        },
      );
      const result = (await response.json()) as any;
      if (!response.ok) {
        this.logger.error(
          `MSG91 password reset email failed for ${toEmail}: ${JSON.stringify(result)}`,
        );
        return false;
      }
      this.logger.log(`Password reset email sent to ${toEmail} via MSG91`);
      return true;
    } catch (error) {
      this.logger.error(
        `Failed to send password reset email to ${toEmail}: ${error.message}`,
      );
      return false;
    }
  }

  async sendCallbackRequestEmail(params: {
    partnerName: string;
    partnerEmail: string;
    phone: string;
    venueName: string;
    city: string;
    callbackDate: string;
    callbackTime: string;
    query: string;
  }) {
    const {
      partnerName,
      partnerEmail,
      phone,
      venueName,
      city,
      callbackDate,
      callbackTime,
      query,
    } = params;
    const authkey = this.configService.get<string>("MSG91_AUTHKEY");
    const fromEmail = this.configService.get<string>("MSG91_FROM_EMAIL");
    const domain = this.configService.get<string>("MSG91_DOMAIN");
    const supportEmail = this.configService.get<string>(
      "SUPPORT_EMAIL",
      "support@activ.live",
    );

    const body = {
      recipients: [
        {
          to: [{ email: supportEmail, name: "ACTIV Support" }],
          variables: {
            partnerName,
            partnerEmail,
            phone,
            venueName,
            city,
            callbackDate,
            callbackTime,
            query,
          },
        },
      ],
      from: { email: fromEmail },
      domain,
      template_id: "partnercallbackrequest",
    };

    try {
      const response = await fetch(
        "https://control.msg91.com/api/v5/email/send",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            authkey,
          },
          body: JSON.stringify(body),
        },
      );
      const result = (await response.json()) as any;
      if (!response.ok) {
        this.logger.error(
          `MSG91 callback request email failed for ${partnerEmail}: ${JSON.stringify(result)}`,
        );
        return false;
      }
      this.logger.log(
        `Callback request email sent to ${supportEmail} for partner ${partnerEmail}`,
      );
      return true;
    } catch (error) {
      this.logger.error(
        `Failed to send callback request email for ${partnerEmail}: ${error.message}`,
      );
      return false;
    }
  }

  async sendSupportRequestEmail(params: {
    partnerName: string;
    partnerEmail?: string;
    subject: string;
    message: string;
  }) {
    const supportEmail = this.configService.get<string>(
      'SUPPORT_EMAIL',
      'support@activ.live',
    );
    return this.googleOAuthService.sendEmail({
      recipientEmail: supportEmail,
      recipientName: 'ACTIV Support',
      subject: `[Partner Support] ${params.subject}`,
      text: [
        `Partner: ${params.partnerName}`,
        `Email: ${params.partnerEmail || 'Not provided'}`,
        '',
        params.message,
      ].join('\n'),
    });
  }

  async sendPartnerRejectionEmail(params: {
    toEmail: string;
    firstName: string;
    venueId: string;
    rejectionReason: string;
  }) {
    const { toEmail, firstName, venueId, rejectionReason } = params;
    if (this.hasBrandedTransport()) return this.sendTemplateEmail(toEmail, 'venue_rejected', { partnerName: firstName, reference: venueId, reason: rejectionReason });
    const authkey = this.configService.get<string>("MSG91_AUTHKEY");
    const fromEmail = this.configService.get<string>("MSG91_FROM_EMAIL");
    const domain = this.configService.get<string>("MSG91_DOMAIN");

    const body = {
      recipients: [
        {
          to: [{ email: toEmail, name: firstName }],
          variables: {
            firstName,
            venueId,
            rejectionReason,
          },
        },
      ],
      from: { email: fromEmail },
      domain,
      template_id: "venuerejection",
    };

    try {
      const response = await fetch(
        "https://control.msg91.com/api/v5/email/send",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            authkey,
          },
          body: JSON.stringify(body),
        },
      );
      const result = (await response.json()) as any;
      if (!response.ok) {
        this.logger.error(
          `MSG91 rejection email failed for ${toEmail}: ${JSON.stringify(result)}`,
        );
      } else {
        this.logger.log(`Rejection email sent to ${toEmail} via MSG91`);
      }
    } catch (error) {
      this.logger.error(
        `Failed to send rejection email to ${toEmail}: ${error.message}`,
      );
    }
  }
}
