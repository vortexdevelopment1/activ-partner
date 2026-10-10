import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { NotificationPreferences } from './entities/notification-preferences.entity';
import { UpdateNotificationPreferencesDto } from './dto/update-notification-preferences.dto';

@Injectable()
export class NotificationPreferencesService {
  constructor(
    @InjectRepository(NotificationPreferences)
    private readonly repo: Repository<NotificationPreferences>,
  ) {}

  async getPreferences(partnerId: string): Promise<NotificationPreferences> {
    const existing = await this.repo.findOne({ where: { partnerId } });
    if (existing) return existing;

    // Return default preferences without persisting until the partner saves explicitly
    const defaults = this.repo.create({ partnerId });
    return defaults;
  }

  async upsertPreferences(
    partnerId: string,
    dto: UpdateNotificationPreferencesDto,
  ): Promise<NotificationPreferences> {
    let record = await this.repo.findOne({ where: { partnerId } });

    if (record) {
      Object.assign(record, dto);
    } else {
      record = this.repo.create({ partnerId, ...dto });
    }

    return this.repo.save(record);
  }
}
