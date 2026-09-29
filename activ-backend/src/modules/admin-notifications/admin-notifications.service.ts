import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { AdminNotification, AdminNotificationType } from './entities/admin-notification.entity';

@Injectable()
export class AdminNotificationsService {
  private readonly logger = new Logger(AdminNotificationsService.name);

  constructor(
    @InjectRepository(AdminNotification)
    private readonly repo: Repository<AdminNotification>,
  ) {}

  // Fire-and-forget: a failed notification must never break the flow
  // (venue update, activity change, ...) that triggered it.
  async notify(
    type: AdminNotificationType,
    title: string,
    body: string,
    data?: Record<string, any>,
  ): Promise<void> {
    try {
      await this.repo.save(
        this.repo.create({
          type,
          title,
          body,
          data: data ?? null,
        }),
      );
    } catch (e) {
      this.logger.warn(`Failed to create admin notification (${type}): ${e}`);
    }
  }

  async findAll(): Promise<AdminNotification[]> {
    return this.repo.find({
      order: { createdAt: 'DESC' },
      take: 100,
    });
  }

  async markRead(id: string): Promise<AdminNotification> {
    const notification = await this.repo.findOne({ where: { id } });
    if (!notification) throw new NotFoundException('Notification not found');
    notification.isRead = true;
    return this.repo.save(notification);
  }

  async markAllRead(): Promise<void> {
    await this.repo.update({ isRead: false }, { isRead: true });
  }

  async unreadCount(): Promise<number> {
    return this.repo.count({ where: { isRead: false } });
  }
}
