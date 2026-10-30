import { Module } from '@nestjs/common';
import { BookingsService } from './bookings.service';
import { BookingExpiryService } from './booking-expiry.service';
import { BookingsController } from './bookings.controller';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [BookingsController],
  providers: [BookingsService, BookingExpiryService],
  exports: [BookingsService],
})
export class BookingsModule {}
