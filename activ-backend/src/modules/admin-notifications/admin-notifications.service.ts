import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';

import { PrismaService } from '../../prisma/prisma.service';
import { AdminNotification, AdminNotificationType } from './entities/admin-notification.entity';

@Injectable()
export class AdminNotificationsService {
  private readonly logger = new Logger(AdminNotificationsService.name);

  constructor(private readonly prisma: PrismaService) {}

  private mapNotification(notification: {
    id: string;
    type: string;
    title: string;
    body: string;
    read_at: Date | null;
    created_at: Date;
  }): AdminNotification {
    return {
      id: notification.id,
      type: notification.type as AdminNotificationType,
      title: notification.title,
      body: notification.body,
      data: null,
      isRead: notification.read_at !== null,
      createdAt: notification.created_at,
    };
  }

  // Fire-and-forget: a failed notification must never break the flow
  // (venue update, activity change, ...) that triggered it.
  async notify(
    type: AdminNotificationType,
    title: string,
    body: string,
    data?: Record<string, any>,
  ): Promise<void> {
    try {
      const admins = await this.prisma.users.findMany({
        where: { is_admin: true, status: 'ACTIVE' },
        select: { id: true },
      });
      if (admins.length === 0) return;

      const now = new Date();
      await this.prisma.notifications.createMany({
        data: admins.map((admin) => ({
          id: randomUUID(),
          user_id: admin.id,
          type,
          title,
          body,
          status: 'SENT' as const,
          sent_at: now,
        })),
      });
    } catch (e) {
      this.logger.warn(`Failed to create admin notification (${type}): ${e}`);
    }
  }

  async findAll(adminUserId: string): Promise<AdminNotification[]> {
    const notifications = await this.prisma.notifications.findMany({
      where: { user_id: adminUserId },
      orderBy: { created_at: 'desc' },
      take: 100,
    });
    return notifications.map((notification) => this.mapNotification(notification));
  }

  async markRead(id: string, adminUserId: string): Promise<AdminNotification> {
    const notification = await this.prisma.notifications.findFirst({
      where: { id, user_id: adminUserId },
    });
    if (!notification) throw new NotFoundException('Notification not found');
    const updated = await this.prisma.notifications.update({
      where: { id },
      data: { read_at: new Date() },
    });
    return this.mapNotification(updated);
  }

  async markAllRead(adminUserId: string): Promise<void> {
    await this.prisma.notifications.updateMany({
      where: { user_id: adminUserId, read_at: null },
      data: { read_at: new Date() },
    });
  }

  async unreadCount(adminUserId: string): Promise<number> {
    return this.prisma.notifications.count({
      where: { user_id: adminUserId, read_at: null },
    });
  }
}
