import { Module, Global } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PushNotificationsService } from './push-notifications.service';

@Global()
@Module({
  imports: [ConfigModule],
  providers: [PushNotificationsService],
  exports: [PushNotificationsService],
})
export class PushNotificationsModule {}
