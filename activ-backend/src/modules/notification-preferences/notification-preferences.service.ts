import { Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';

import { PrismaService } from '../../prisma/prisma.service';
import { UpdateNotificationPreferencesDto } from './dto/update-notification-preferences.dto';

type NotificationPreferenceResponse = Required<UpdateNotificationPreferencesDto> & {
  id?: string;
  partnerId: string;
  createdAt?: Date;
  updatedAt?: Date;
};

@Injectable()
export class NotificationPreferencesService {
  constructor(private readonly prisma: PrismaService) {}

  async getPreferences(partnerId: string): Promise<NotificationPreferenceResponse> {
    const existing = await this.prisma.partner_notification_preferences.findUnique({
      where: { partner_id: partnerId },
    });

    if (!existing) {
      return this.mapRecord(partnerId);
    }

    return this.mapRecord(partnerId, existing);
  }

  async upsertPreferences(
    partnerId: string,
    dto: UpdateNotificationPreferencesDto,
  ): Promise<NotificationPreferenceResponse> {
    const current = await this.getPreferences(partnerId);
    const next = {
      enableAllNotifications:
        dto.enableAllNotifications ?? current.enableAllNotifications,
      bookingNotifications:
        dto.bookingNotifications ?? current.bookingNotifications,
      paymentUpdates: dto.paymentUpdates ?? current.paymentUpdates,
      approvalUpdates: dto.approvalUpdates ?? current.approvalUpdates,
      promotionalMessages:
        dto.promotionalMessages ?? current.promotionalMessages,
    };

    const saved = await this.prisma.partner_notification_preferences.upsert({
      where: { partner_id: partnerId },
      create: {
        id: randomUUID(),
        partner_id: partnerId,
        booking_updates: next.enableAllNotifications && next.bookingNotifications,
        payment_updates: next.enableAllNotifications && next.paymentUpdates,
        support_updates: next.enableAllNotifications && next.approvalUpdates,
        marketing_updates:
          next.enableAllNotifications && next.promotionalMessages,
        channel_preferences: next,
        updated_at: new Date(),
      },
      update: {
        booking_updates: next.enableAllNotifications && next.bookingNotifications,
        payment_updates: next.enableAllNotifications && next.paymentUpdates,
        support_updates: next.enableAllNotifications && next.approvalUpdates,
        marketing_updates:
          next.enableAllNotifications && next.promotionalMessages,
        channel_preferences: next,
        updated_at: new Date(),
      },
    });

    return this.mapRecord(partnerId, saved);
  }

  private mapRecord(partnerId: string, record?: any): NotificationPreferenceResponse {
    if (!record) {
      return {
        partnerId,
        enableAllNotifications: true,
        bookingNotifications: true,
        paymentUpdates: true,
        approvalUpdates: true,
        promotionalMessages: false,
      };
    }

    const channel = record?.channel_preferences || {};
    const enableAllNotifications =
      channel.enableAllNotifications ??
      Boolean(
        record.booking_updates ||
          record.payment_updates ||
          record.support_updates ||
          record.marketing_updates,
      );

    return {
      id: record?.id,
      partnerId,
      enableAllNotifications,
      bookingNotifications:
        channel.bookingNotifications ?? record?.booking_updates ?? true,
      paymentUpdates: channel.paymentUpdates ?? record?.payment_updates ?? true,
      approvalUpdates:
        channel.approvalUpdates ?? record?.support_updates ?? true,
      promotionalMessages:
        channel.promotionalMessages ?? record?.marketing_updates ?? false,
      createdAt: record?.created_at,
      updatedAt: record?.updated_at,
    };
  }
}
