import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PartnersService } from './partners.service';
import { PartnersController } from './partners.controller';
import { Partner } from './entities/partner.entity';
import { GstVerificationRequest } from './entities/gst-verification-request.entity';
import { Venue } from '../venues/entities/venue.entity';
import { VenueImage } from '../venues/entities/venue-image.entity';
import { VenueService } from '../venues/entities/venue-service.entity';
import { VenueAnswer } from '../venues/entities/venue-answer.entity';
import { Booking } from '../bookings/entities/booking.entity';
import { Payment } from '../payments/entities/payment.entity';
import { AdminNotificationsModule } from '../admin-notifications/admin-notifications.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Partner, GstVerificationRequest, Venue, VenueImage, VenueService, VenueAnswer, Booking, Payment]),
    AdminNotificationsModule,
  ],
  controllers: [PartnersController],
  providers: [PartnersService],
  exports: [PartnersService, TypeOrmModule],
})
export class PartnersModule {}
