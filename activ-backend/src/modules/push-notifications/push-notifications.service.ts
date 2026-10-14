import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class PushNotificationsService {
  private readonly logger = new Logger(PushNotificationsService.name);

  constructor(private configService: ConfigService) {}

  // Fire-and-forget: a failed push must never break the flow (venue
  // approval, ...) that triggered it.
  async sendToPartner(
    partnerId: string,
    title: string,
    body: string,
    data?: Record<string, any>,
  ): Promise<boolean> {
    const appId = this.configService.get<string>('ONESIGNAL_APP_ID');
    const restApiKey = this.configService.get<string>('ONESIGNAL_REST_API_KEY');

    try {
      const response = await fetch('https://onesignal.com/api/v1/notifications', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Basic ${restApiKey}`,
        },
        body: JSON.stringify({
          app_id: appId,
          include_external_user_ids: [partnerId],
          headings: { en: title },
          contents: { en: body },
          data: data ?? {},
        }),
      });
      const result = await response.json() as any;
      if (!response.ok) {
        this.logger.warn(`OneSignal push failed for partner ${partnerId}: ${JSON.stringify(result)}`);
        return false;
      }
      this.logger.log(`Push sent to partner ${partnerId}: ${JSON.stringify(result)}`);
      return true;
    } catch (error) {
      this.logger.warn(`Failed to send push to partner ${partnerId}: ${error.message}`);
      return false;
    }
  }
}
