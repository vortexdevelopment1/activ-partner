import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ReviewsService } from './reviews.service';
import { ReviewsController } from './reviews.controller';
import { Review } from './entities/review.entity';
import { VenueService } from '../venues/entities/venue-service.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Review, VenueService])],
  controllers: [ReviewsController],
  providers: [ReviewsService],
  exports: [TypeOrmModule],
})
export class ReviewsModule {}
