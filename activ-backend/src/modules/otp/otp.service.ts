import { Injectable, Logger, BadRequestException, OnModuleInit, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { isProductionEnvironment } from '../../config/environment';
import { isMsg91TemplateId, MSG91_TIMEOUT_MS, PHONE_OTP_LENGTH, PHONE_OTP_EXPIRY_MS } from '../../config/msg91';

/** MSG91 owns OTP generation and verification; local challenges gate app login. */
@Injectable()
export class OtpService implements OnModuleInit {
  private readonly logger = new Logger(OtpService.name);

  constructor(private configService: ConfigService) {}

  onModuleInit(): void {
    this.isMsg91Enabled();
    if (this.isProduction() && !isMsg91TemplateId(this.configService.get<string>('MSG91_TEAM_INVITE_TEMPLATE_ID')?.trim())) {
      throw new ServiceUnavailableException('Production requires a valid MSG91_TEAM_INVITE_TEMPLATE_ID');
    }
  }

  async sendOtp(phone: string): Promise<void> {
    if (!this.isMsg91Enabled()) return;
    const params = new URLSearchParams({
      template_id: this.configService.get<string>('MSG91_OTP_TEMPLATE_ID').trim(),
      mobile: this.toMsg91Format(phone),
      otp_length: String(PHONE_OTP_LENGTH),
      otp_expiry: String(PHONE_OTP_EXPIRY_MS / 60_000),
    });
    if (!await this.request('otp', params, 'POST', 'request_id')) {
      throw new BadRequestException('Failed to send OTP. Please try again.');
    }
  }

  async verifyOtp(phone: string, otp: string): Promise<boolean> {
    const enabled = this.isMsg91Enabled();
    if (!new RegExp(`^\\d{${PHONE_OTP_LENGTH}}$`).test(otp)) return false;
    if (!enabled) return otp === phone.replace(/\D/g, '').slice(-PHONE_OTP_LENGTH);
    return this.request('otp/verify', new URLSearchParams({ mobile: this.toMsg91Format(phone), otp }), 'GET');
  }

  async resendOtp(phone: string, retryType: 'text' | 'voice' = 'text'): Promise<void> {
    if (!this.isMsg91Enabled()) return;
    if (!await this.request('otp/retry', new URLSearchParams({ mobile: this.toMsg91Format(phone), retrytype: retryType }), 'GET')) {
      throw new BadRequestException('Failed to resend OTP. Please try again.');
    }
  }

  private async request(endpoint: string, params: URLSearchParams, method: 'POST' | 'GET', idField?: string): Promise<boolean> {
    try {
      const response = await fetch(`https://control.msg91.com/api/v5/${endpoint}?${params}`, {
        method,
        signal: AbortSignal.timeout(MSG91_TIMEOUT_MS),
        headers: {
          authkey: this.configService.get<string>('MSG91_AUTHKEY').trim(),
          'Content-Type': 'application/json', Accept: 'application/json',
        },
      });
      const result = await response.json();
      const accepted = response.ok && result?.type === 'success' &&
        (!idField || (typeof result[idField] === 'string' && result[idField].trim().length > 0));
      if (!accepted) this.logger.warn(`MSG91 ${endpoint} rejected (HTTP ${response.status})`);
      return accepted;
    } catch {
      // Provider errors/URLs can contain OTPs and phone numbers; never log them.
      this.logger.warn(`MSG91 ${endpoint} failed or timed out`);
      return false;
    }
  }

  private isProduction(): boolean {
    return isProductionEnvironment({
      NODE_ENV: this.configService.get<string>('NODE_ENV'),
      APP_ENV: this.configService.get<string>('APP_ENV'),
    });
  }

  private isMsg91Enabled(): boolean {
    const enabled = this.configService.get<string>('MSG91_OTP_ENABLED') === 'true';
    if (!enabled && this.isProduction()) {
      throw new ServiceUnavailableException('Production requires MSG91_OTP_ENABLED=true');
    }
    if (enabled && (!this.configService.get<string>('MSG91_AUTHKEY')?.trim() ||
      !isMsg91TemplateId(this.configService.get<string>('MSG91_OTP_TEMPLATE_ID')?.trim()))) {
      throw new ServiceUnavailableException('MSG91 OTP configuration is incomplete');
    }
    return enabled;
  }

  private toMsg91Format(phone: string): string {
    const digits = phone.replace(/\D/g, '');
    return digits.length === 10 ? `91${digits}` : digits;
  }
}
