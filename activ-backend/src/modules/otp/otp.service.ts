import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * Wraps MSG91's server-side Send OTP / Verify OTP REST API.
 * MSG91 generates, delivers and tracks the OTP itself — this service never
 * sees or stores the OTP value, it only forwards phone/otp to MSG91 and
 * relays the verdict.
 *
 * Docs: https://docs.msg91.com/otp
 */
@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  constructor(private configService: ConfigService) {}

  async sendOtp(phone: string): Promise<void> {
    if (!this.isMsg91Enabled()) {
      // Mock mode: OTP is deterministically the last 4 digits of the phone number.
      // Nothing to actually send — verifyOtp() below recomputes the same value.
      this.logger.warn(`MSG91 disabled — mock OTP for ${phone} is its last 4 digits.`);
      return;
    }

    const authkey = this.configService.get<string>('MSG91_AUTHKEY');
    const templateId = this.configService.get<string>('MSG91_OTP_TEMPLATE_ID');
    const mobile = this.toMsg91Format(phone);

    const params = new URLSearchParams({ template_id: templateId, mobile });

    try {
      const response = await fetch(`https://control.msg91.com/api/v5/otp?${params.toString()}`, {
        method: 'POST',
        headers: {
          authkey,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
      });
      const result = (await response.json()) as any;

      if (!response.ok || result?.type !== 'success') {
        this.logger.error(`MSG91 send OTP failed for ${mobile}: ${JSON.stringify(result)}`);
        throw new BadRequestException('Failed to send OTP. Please try again.');
      }

      this.logger.log(`OTP sent to ${mobile} via MSG91`);
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      this.logger.error(`Failed to send OTP to ${mobile}: ${error.message}`);
      throw new BadRequestException('Failed to send OTP. Please try again.');
    }
  }

  async verifyOtp(phone: string, otp: string): Promise<boolean> {
    if (!this.isMsg91Enabled()) {
      const mockOtp = phone.replace(/\D/g, '').slice(-4);
      return otp === mockOtp;
    }

    const authkey = this.configService.get<string>('MSG91_AUTHKEY');
    const mobile = this.toMsg91Format(phone);

    const params = new URLSearchParams({ mobile, otp });

    try {
      const response = await fetch(`https://control.msg91.com/api/v5/otp/verify?${params.toString()}`, {
        method: 'GET',
        headers: { authkey, Accept: 'application/json' },
      });
      const result = (await response.json()) as any;

      if (result?.type === 'success') return true;

      this.logger.warn(`MSG91 OTP verify failed for ${mobile}: ${JSON.stringify(result)}`);
      return false;
    } catch (error) {
      this.logger.error(`Failed to verify OTP for ${mobile}: ${error.message}`);
      return false;
    }
  }

  async resendOtp(phone: string, retryType: 'text' | 'voice' = 'text'): Promise<void> {
    if (!this.isMsg91Enabled()) {
      this.logger.warn(`MSG91 disabled — mock OTP for ${phone} is its last 4 digits (nothing to resend).`);
      return;
    }

    const authkey = this.configService.get<string>('MSG91_AUTHKEY');
    const mobile = this.toMsg91Format(phone);

    const params = new URLSearchParams({ mobile, retrytype: retryType });

    try {
      const response = await fetch(`https://control.msg91.com/api/v5/otp/retry?${params.toString()}`, {
        method: 'POST',
        headers: { authkey, Accept: 'application/json' },
      });
      const result = (await response.json()) as any;

      if (!response.ok || result?.type !== 'success') {
        this.logger.error(`MSG91 resend OTP failed for ${mobile}: ${JSON.stringify(result)}`);
        throw new BadRequestException('Failed to resend OTP. Please try again.');
      }
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      this.logger.error(`Failed to resend OTP to ${mobile}: ${error.message}`);
      throw new BadRequestException('Failed to resend OTP. Please try again.');
    }
  }

  /** Toggle via MSG91_OTP_ENABLED=true|false. Defaults to disabled (mock OTP) until configured. */
  private isMsg91Enabled(): boolean {
    return this.configService.get<string>('MSG91_OTP_ENABLED') === 'true';
  }

  /** MSG91 expects the number as country-code + digits, no leading '+'. Defaults to India (91). */
  private toMsg91Format(phone: string): string {
    const digits = phone.replace(/\D/g, '');
    if (digits.length === 10) return `91${digits}`;
    return digits;
  }
}
