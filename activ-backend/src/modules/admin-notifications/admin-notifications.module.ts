import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { AdminNotification } from './entities/admin-notification.entity';
import { AdminNotificationsService } from './admin-notifications.service';
import { AdminNotificationsController } from './admin-notifications.controller';

@Module({
  imports: [TypeOrmModule.forFeature([AdminNotification])],
  controllers: [AdminNotificationsController],
  providers: [AdminNotificationsService],
  exports: [AdminNotificationsService],
})
export class AdminNotificationsModule {}
