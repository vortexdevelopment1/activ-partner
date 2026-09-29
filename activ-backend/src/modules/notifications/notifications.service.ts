import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Notification, NotificationType } from './entities/notification.entity';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectRepository(Notification)
    private readonly notificationRepository: Repository<Notification>,
  ) {}

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
      await this.notificationRepository.save(
        this.notificationRepository.create({
          partnerId,
          type,
          title,
          body,
          data: data ?? null,
        }),
      );
    } catch (e) {
      this.logger.warn(`Failed to create notification (${type}): ${e}`);
    }
  }

  async findByPartner(partnerId: string): Promise<Notification[]> {
    return this.notificationRepository.find({
      where: { partnerId },
      order: { createdAt: 'DESC' },
      take: 100,
    });
  }

  async markRead(id: string, partnerId: string): Promise<Notification> {
    const notification = await this.notificationRepository.findOne({
      where: { id, partnerId },
    });
    if (!notification) throw new NotFoundException('Notification not found');
    notification.isRead = true;
    return this.notificationRepository.save(notification);
  }

  async markAllRead(partnerId: string): Promise<void> {
    await this.notificationRepository.update(
      { partnerId, isRead: false },
      { isRead: true },
    );
  }

  async unreadCount(partnerId: string): Promise<number> {
    return this.notificationRepository.count({
      where: { partnerId, isRead: false },
    });
  }
}
