import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: nodemailer.Transporter;

  constructor(private configService: ConfigService) {
    this.transporter = nodemailer.createTransport({
      host: this.configService.get<string>('MAIL_HOST', 'smtp.gmail.com'),
      port: this.configService.get<number>('MAIL_PORT', 587),
      secure: false,
      auth: {
        user: this.configService.get<string>('MAIL_USER'),
        pass: this.configService.get<string>('MAIL_PASS'),
      },
    });
  }

  async sendPartnerApprovalEmail(params: {
    toEmail: string;
    partnerName: string;
    venueName: string;
    password: string;
  }) {
    const { toEmail, partnerName, password } = params;
    const authkey = this.configService.get<string>('MSG91_AUTHKEY');
    const fromEmail = this.configService.get<string>('MSG91_FROM_EMAIL');
    const domain = this.configService.get<string>('MSG91_DOMAIN');
    const appLink = this.configService.get<string>('PARTNER_APP_URL', 'https://activ.co.in/login');

    const body = {
      recipients: [
        {
          to: [{ email: toEmail, name: partnerName }],
          variables: {
            partnerName,
            email: toEmail,
            newPassword: password,
            appLink,
          },
        },
      ],
      from: { email: fromEmail },
      domain,
      template_id: 'partnerapprovaltemplate',
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
      } else {
        this.logger.log(`Approval email sent to ${toEmail} via MSG91`);
      }
    } catch (error) {
      this.logger.error(`Failed to send approval email to ${toEmail}: ${error.message}`);
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
