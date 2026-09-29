import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BookingsService } from './bookings.service';
import { BookingsController } from './bookings.controller';
import { Booking } from './entities/booking.entity';
import { VenueService } from '../venues/entities/venue-service.entity';
import { Venue } from '../venues/entities/venue.entity';
import { Payment } from '../payments/entities/payment.entity';
import { BankAccount } from '../bank-accounts/entities/bank-account.entity';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Booking, VenueService, Venue, Payment, BankAccount]),
    NotificationsModule,
  ],
  controllers: [BookingsController],
  providers: [BookingsService],
  exports: [BookingsService, TypeOrmModule],
})
export class BookingsModule {}
