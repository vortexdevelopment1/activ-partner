import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';

import { PrismaService } from '../../prisma/prisma.service';
import { NotificationRecord as Notification, NotificationType } from '../../common/domain-types';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(private readonly prisma: PrismaService) {}

  private mapNotification(notification: {
    id: string;
    user_id: string;
    type: string;
    title: string;
    body: string;
    data: unknown;
    read_at: Date | null;
    created_at: Date;
  }, partnerId: string): Notification {
    return {
      id: notification.id,
      partnerId,
      type: notification.type as NotificationType,
      title: notification.title,
      body: notification.body,
      data: notification.data && typeof notification.data === 'object'
          ? notification.data as Record<string, any>
          : null,
      isRead: notification.read_at !== null,
      createdAt: notification.created_at,
    };
  }

  private async getPartnerUserId(partnerId: string): Promise<string | null> {
    const links = await this.prisma.partner_users.findMany({
      where: { partner_id: partnerId, users: { status: 'ACTIVE' } },
      select: { user_id: true, role: true },
    });
    return links.find((link) => link.role === 'PARTNER_ADMIN')?.user_id
      ?? links[0]?.user_id
      ?? null;
  }

  // Fire-and-forget: a failed notification must never break the flow
  // (booking confirmation, activity approval, ...) that triggered it.
  async notify(
    partnerId: string,
    type: NotificationType,
    title: string,
    body: string,
    data?: Record<string, any>,
  ): Promise<void> {
    try {
      const userId = await this.getPartnerUserId(partnerId);
      if (!userId) return;
      const now = new Date();
      await this.prisma.notifications.create({
        data: {
          id: randomUUID(),
          user_id: userId,
          type,
          title,
          body,
          data: data ?? undefined,
          status: 'SENT',
          sent_at: now,
        },
      });
    } catch (e) {
      this.logger.warn(`Failed to create notification (${type}): ${e}`);
    }
  }

  async findByPartner(partnerId: string, currentUserId?: string): Promise<Notification[]> {
    const defaultUserId = await this.getPartnerUserId(partnerId);
    const userIds = Array.from(new Set([defaultUserId, currentUserId].filter(Boolean))) as string[];
    if (userIds.length === 0) return [];
    const notifications = await this.prisma.notifications.findMany({
      where: { user_id: { in: userIds } },
      orderBy: { created_at: 'desc' },
      take: 100,
    });
    return notifications.map((notification) => this.mapNotification(notification, partnerId));
  }

  async markRead(id: string, partnerId: string, currentUserId?: string): Promise<Notification> {
    const defaultUserId = await this.getPartnerUserId(partnerId);
    const userIds = Array.from(new Set([defaultUserId, currentUserId].filter(Boolean))) as string[];
    const notification = userIds.length > 0 && await this.prisma.notifications.findFirst({
      where: { id, user_id: { in: userIds } },
    });
    if (!notification) throw new NotFoundException('Notification not found');
    const updated = await this.prisma.notifications.update({
      where: { id },
      data: { read_at: new Date() },
    });
    return this.mapNotification(updated, partnerId);
  }

  async markAllRead(partnerId: string, currentUserId?: string): Promise<void> {
    const defaultUserId = await this.getPartnerUserId(partnerId);
    const userIds = Array.from(new Set([defaultUserId, currentUserId].filter(Boolean))) as string[];
    if (userIds.length === 0) return;
    await this.prisma.notifications.updateMany({
      where: { user_id: { in: userIds }, read_at: null },
      data: { read_at: new Date() },
    });
  }

  async unreadCount(partnerId: string, currentUserId?: string): Promise<number> {
    const defaultUserId = await this.getPartnerUserId(partnerId);
    const userIds = Array.from(new Set([defaultUserId, currentUserId].filter(Boolean))) as string[];
    if (userIds.length === 0) return 0;
    return this.prisma.notifications.count({
      where: { user_id: { in: userIds }, read_at: null },
    });
  }
}
