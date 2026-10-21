import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import { GoogleOAuthService } from './google-oauth.service';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  constructor(
    private configService: ConfigService,
    private readonly googleOAuthService: GoogleOAuthService,
  ) {}

  async sendSignedAgreementEmailViaGmail(params: {
    toEmail: string;
    partnerName: string;
    venueName: string;
    signedAt: Date;
    pdfBuffer: Buffer;
    filename: string;
  }): Promise<string> {
    const signedAt = params.signedAt.toLocaleString('en-IN', {
      timeZone: 'Asia/Kolkata', dateStyle: 'long', timeStyle: 'short',
    });
    return this.googleOAuthService.sendEmail({
      recipientEmail: params.toEmail,
      recipientName: params.partnerName,
      subject: 'Your Signed Partnership Agreement – ACTIV Partner',
      text: `Dear ${params.partnerName},\n\nThank you for completing your registration with ACTIV Partner.\n\nYour Partnership Agreement has been successfully signed.\n\nPlease find a copy of your signed Partnership Agreement attached for your records.\n\nOur team will review your venue registration and notify you of the next steps.\n\nBest regards,\nACTIV Partner Support Team`,
      pdfBuffer: params.pdfBuffer,
      filename: params.filename,
    });
  }

  async sendSignedPartnerAgreementEmail(params: {
    toEmail: string;
    partnerName: string;
    venueName: string;
    signedAt: Date;
    agreement: { base64: string; filename: string; mimeType: string };
  }): Promise<void> {
    const signedAt = params.signedAt.toLocaleString('en-IN', {
      timeZone: 'Asia/Kolkata', dateStyle: 'long', timeStyle: 'short',
    });
    const host = this.configService.get<string>('MAIL_HOST', 'smtp.gmail.com');
    const port = Number(this.configService.get<string>('MAIL_PORT', '587'));
    const user = this.configService.get<string>('MAIL_USER')?.trim();
    const pass = this.configService.get<string>('MAIL_PASS');
    const fromEmail = this.configService.get<string>('MAIL_FROM_EMAIL', 'support@activ.live');
    if (!user || !pass || !fromEmail) {
      throw Object.assign(new Error('SMTP agreement email is not configured'), { code: 'SMTP_CONFIG' });
    }
    const transport = nodemailer.createTransport({
      host, port, secure: port === 465,
      auth: { user, pass },
      connectionTimeout: 30000, greetingTimeout: 30000, socketTimeout: 30000,
    });
    try {
      await transport.sendMail({
        from: { name: 'ACTIV Partner Support', address: fromEmail },
        to: { name: params.partnerName, address: params.toEmail },
        replyTo: 'support@activ.live',
        subject: 'Your Signed Partnership Agreement – ACTIV Partner',
        text: `Hello ${params.partnerName},\n\nPlease find your signed partnership agreement attached.\n\nVenue: ${params.venueName}\nAccepted: ${signedAt} (IST)\n\nACTIV Partner Support`,
        attachments: [{
          filename: params.agreement.filename,
          content: Buffer.from(params.agreement.base64, 'base64'),
          contentType: params.agreement.mimeType,
        }],
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
          });
        } finally {
          transport.close();
        }
      } else {
        await this.googleOAuthService.sendEmail({ recipientEmail: params.toEmail.trim(), subject, text });
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
    const authkey = this.configService.get<string>('MSG91_AUTHKEY');
    const fromEmail = this.configService.get<string>('MSG91_FROM_EMAIL');
    const domain = this.configService.get<string>('MSG91_DOMAIN');
    const appLink = this.configService.get<string>('PARTNER_APP_URL', 'https://activ.co.in/login');
    const templateId = this.configService.get<string>(
      'MSG91_APPROVAL_TEMPLATE_ID',
      'partnerapprovaltemplate',
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
      const response = await fetch('https://control.msg91.com/api/v5/email/send', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          authkey,
        },
        body: JSON.stringify(body),
      });
      const result = await response.json() as any;
      if (!response.ok) {
        this.logger.error(`MSG91 approval email failed for ${toEmail}: ${JSON.stringify(result)}`);
        return false;
      } else {
        this.logger.log(`Approval email sent to ${toEmail} via MSG91`);
        return true;
      }
    } catch (error) {
      this.logger.error(`Failed to send approval email to ${toEmail}: ${error.message}`);
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
    const authkey = this.configService.get<string>('MSG91_AUTHKEY');
    const fromEmail = this.configService.get<string>('MSG91_FROM_EMAIL');
    const domain = this.configService.get<string>('MSG91_DOMAIN');
    const appLink = this.configService.get<string>('PARTNER_APP_URL', 'https://activ.co.in/login');

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
      template_id: 'teammemberinvite_2',
    };

    try {
      const response = await fetch('https://control.msg91.com/api/v5/email/send', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          authkey,
        },
        body: JSON.stringify(body),
      });
      const result = await response.json() as any;
      if (!response.ok) {
        this.logger.error(`MSG91 team invite email failed for ${toEmail}: ${JSON.stringify(result)}`);
      } else {
        this.logger.log(`Team invite email sent to ${toEmail} via MSG91`);
      }
    } catch (error) {
      this.logger.error(`Failed to send team invite email to ${toEmail}: ${error.message}`);
    }
  }

  async sendPasswordResetEmail(params: {
    toEmail: string;
    firstName: string;
    code: string;
  }) {
    const { toEmail, firstName, code } = params;
    const authkey = this.configService.get<string>('MSG91_AUTHKEY');
    const fromEmail = this.configService.get<string>('MSG91_FROM_EMAIL');
    const domain = this.configService.get<string>('MSG91_DOMAIN');

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
      template_id: 'passwordresetcode',
    };

    try {
      const response = await fetch('https://control.msg91.com/api/v5/email/send', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          authkey,
        },
        body: JSON.stringify(body),
      });
      const result = await response.json() as any;
      if (!response.ok) {
        this.logger.error(`MSG91 password reset email failed for ${toEmail}: ${JSON.stringify(result)}`);
        return false;
      }
      this.logger.log(`Password reset email sent to ${toEmail} via MSG91`);
      return true;
    } catch (error) {
      this.logger.error(`Failed to send password reset email to ${toEmail}: ${error.message}`);
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
    const { partnerName, partnerEmail, phone, venueName, city, callbackDate, callbackTime, query } = params;
    const authkey = this.configService.get<string>('MSG91_AUTHKEY');
    const fromEmail = this.configService.get<string>('MSG91_FROM_EMAIL');
    const domain = this.configService.get<string>('MSG91_DOMAIN');
    const supportEmail = this.configService.get<string>('SUPPORT_EMAIL', 'support@activ.live');

    const body = {
      recipients: [
        {
          to: [{ email: supportEmail, name: 'ACTIV Support' }],
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
      template_id: 'partnercallbackrequest',
    };

    try {
      const response = await fetch('https://control.msg91.com/api/v5/email/send', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          authkey,
        },
        body: JSON.stringify(body),
      });
      const result = await response.json() as any;
      if (!response.ok) {
        this.logger.error(`MSG91 callback request email failed for ${partnerEmail}: ${JSON.stringify(result)}`);
        return false;
      }
      this.logger.log(`Callback request email sent to ${supportEmail} for partner ${partnerEmail}`);
      return true;
    } catch (error) {
      this.logger.error(`Failed to send callback request email for ${partnerEmail}: ${error.message}`);
      return false;
    }
  }

  async sendPartnerRejectionEmail(params: {
    toEmail: string;
    firstName: string;
    venueId: string;
    rejectionReason: string;
  }) {
    const { toEmail, firstName, venueId, rejectionReason } = params;
    const authkey = this.configService.get<string>('MSG91_AUTHKEY');
    const fromEmail = this.configService.get<string>('MSG91_FROM_EMAIL');
    const domain = this.configService.get<string>('MSG91_DOMAIN');

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
      template_id: 'venuerejection',
    };

    try {
      const response = await fetch('https://control.msg91.com/api/v5/email/send', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          authkey,
        },
        body: JSON.stringify(body),
      });
      const result = await response.json() as any;
      if (!response.ok) {
        this.logger.error(`MSG91 rejection email failed for ${toEmail}: ${JSON.stringify(result)}`);
      } else {
        this.logger.log(`Rejection email sent to ${toEmail} via MSG91`);
      }
    } catch (error) {
      this.logger.error(`Failed to send rejection email to ${toEmail}: ${error.message}`);
    }
  }
}
