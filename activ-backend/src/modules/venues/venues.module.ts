import { Module } from '@nestjs/common';
import { VenuesService } from './venues.service';
import { VenuesController } from './venues.controller';
import { QuestionsModule } from '../questions/questions.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { AdminNotificationsModule } from '../admin-notifications/admin-notifications.module';
import { CommissionModule } from '../commission/commission.module';

@Module({
  imports: [
    QuestionsModule,
    NotificationsModule,
    AdminNotificationsModule,
    CommissionModule,
  ],
  controllers: [VenuesController],
  providers: [VenuesService],
  exports: [VenuesService],
})
export class VenuesModule {}
