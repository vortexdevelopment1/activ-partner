import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class ReviewsService {
  constructor(private readonly prisma: PrismaService) {}

  async getServiceReviews(
    serviceId: string,
    currentUserId: string,
    isAdmin: boolean,
  ) {
    const service = await this.prisma.partner_venue_services.findUnique({
      where: { id: serviceId },
      include: { venues: true },
    });
    if (!service) throw new NotFoundException('Activity not found');
    if (!isAdmin && service.venues.partner_id !== currentUserId) {
      throw new ForbiddenException(
        'You can only view reviews for your own activities',
      );
    }

    const reviews = service.facility_id
      ? await this.prisma.reviews.findMany({
          where: {
            bookings: {
              slots: { facility_id: service.facility_id },
            },
          },
          include: { users: true },
          orderBy: { created_at: 'desc' },
          take: 20,
        })
      : [];

    const totalReviews = reviews.length;
    const averageRating = totalReviews
      ? Math.round(
          (reviews.reduce((sum, review) => sum + review.rating, 0) /
            totalReviews) *
            10,
        ) / 10
      : 0;

    const distribution = [5, 4, 3, 2, 1].map((stars) => {
      const count = reviews.filter((review) => review.rating === stars).length;
      return {
        stars,
        count,
        percent: totalReviews ? Math.round((count / totalReviews) * 100) : 0,
      };
    });

    return {
      averageRating,
      totalReviews,
      distribution,
      items: reviews.map((review) => ({
        id: review.id,
        userName:
          (review.users.name || '').trim() ||
          review.users.email ||
          'Customer',
        rating: review.rating,
        comment: review.body,
        createdAt: review.created_at,
      })),
    };
  }
}
