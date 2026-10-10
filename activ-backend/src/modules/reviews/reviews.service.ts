import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Review } from './entities/review.entity';
import { VenueService } from '../venues/entities/venue-service.entity';

@Injectable()
export class ReviewsService {
  constructor(
    @InjectRepository(Review)
    private readonly reviewRepository: Repository<Review>,
    @InjectRepository(VenueService)
    private readonly serviceRepository: Repository<VenueService>,
  ) {}

  async getServiceReviews(serviceId: string, currentUserId: string, isAdmin: boolean) {
    const service = await this.serviceRepository.findOne({
      where: { id: serviceId },
      relations: ['venue'],
    });
    if (!service) throw new NotFoundException('Activity not found');
    if (!isAdmin && service.venue.partnerId !== currentUserId) {
      throw new ForbiddenException('You can only view reviews for your own activities');
    }

    const totalReviews = await this.reviewRepository.count({ where: { serviceId } });

    const avgResult = await this.reviewRepository
      .createQueryBuilder('review')
      .select('AVG(review.rating)', 'avg')
      .where('review.serviceId = :serviceId', { serviceId })
      .getRawOne();
    const averageRating = avgResult?.avg ? Math.round(parseFloat(avgResult.avg) * 10) / 10 : 0;

    const distributionRaw = await this.reviewRepository
      .createQueryBuilder('review')
      .select('review.rating', 'rating')
      .addSelect('COUNT(*)', 'count')
      .where('review.serviceId = :serviceId', { serviceId })
      .groupBy('review.rating')
      .getRawMany();
    const countsByStar = new Map(distributionRaw.map((d) => [Number(d.rating), Number(d.count)]));
    const distribution = [5, 4, 3, 2, 1].map((stars) => {
      const count = countsByStar.get(stars) || 0;
      return {
        stars,
        count,
        percent: totalReviews ? Math.round((count / totalReviews) * 100) : 0,
      };
    });

    const recent = await this.reviewRepository.find({
      where: { serviceId },
      relations: ['user'],
      order: { createdAt: 'DESC' },
      take: 20,
    });

    return {
      averageRating,
      totalReviews,
      distribution,
      items: recent.map((r) => ({
        id: r.id,
        userName: (r.user?.fullName || '').trim() || r.user?.email || 'Customer',
        rating: r.rating,
        comment: r.comment,
        createdAt: r.createdAt,
      })),
    };
  }
}
