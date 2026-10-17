import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  constructor(private configService: ConfigService) {}

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
    const authkey = this.configService.get<string>('MSG91_AUTHKEY');
    const templateId = this.configService.get<string>('MSG91_AGREEMENT_TEMPLATE_ID');
    const domain = this.configService.get<string>('MSG91_DOMAIN', 'activ.co.in');
    if (!authkey || !templateId?.trim()) {
      throw Object.assign(new Error('Configure MSG91_AUTHKEY and MSG91_AGREEMENT_TEMPLATE_ID'), {
        code: 'MSG91_CONFIG',
      });
    }
    const response = await fetch('https://control.msg91.com/api/v5/email/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json', authkey },
      signal: AbortSignal.timeout(30000),
      body: JSON.stringify({
      from: { name: 'ACTIV Partner', email: 'no-reply@activ.co.in' },
      reply_to: [{ email: 'support@activ.live' }],
      domain,
      template_id: templateId.trim(),
      recipients: [{
        to: [{ email: params.toEmail, name: params.partnerName }],
        variables: {
          partnerName: params.partnerName,
          venueName: params.venueName,
          signedAt: `${signedAt} (IST)`,
          supportEmail: 'support@activ.live',
        },
      }],
      attachments: [{
        fileName: params.agreement.filename,
        file: `data:${params.agreement.mimeType};base64,${params.agreement.base64}`,
      }],
      }),
    });
    const result = await response.json();
    if (!response.ok || result?.status === 'fail' || result?.status === 'error' || result?.success === false) {
      // Never expose provider responses containing partner data or credentials.
      throw Object.assign(new Error('MSG91 rejected signed agreement email'), {
        code: 'MSG91_SEND', responseCode: response.status,
      });
    }
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
