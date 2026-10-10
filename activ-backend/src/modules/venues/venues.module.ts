import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { VenuesService } from './venues.service';
import { VenuesController } from './venues.controller';
import { Venue } from './entities/venue.entity';
import { VenueImage } from './entities/venue-image.entity';
import { VenueService } from './entities/venue-service.entity';
import { VenueAnswer } from './entities/venue-answer.entity';
import { VenueUpdateRequest } from './entities/venue-update-request.entity';
import { WalkInReservation } from './entities/walk-in-reservation.entity';
import { Partner } from '../partners/entities/partner.entity';
import { Category } from '../categories/entities/category.entity';
import { Booking } from '../bookings/entities/booking.entity';
import { QuestionsModule } from '../questions/questions.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { AdminNotificationsModule } from '../admin-notifications/admin-notifications.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Venue, VenueImage, VenueService, VenueAnswer, VenueUpdateRequest, WalkInReservation, Partner, Category, Booking]),
    QuestionsModule,
    NotificationsModule,
    AdminNotificationsModule,
  ],
  controllers: [VenuesController],
  providers: [VenuesService],
  exports: [VenuesService, TypeOrmModule],
})
export class VenuesModule {}
