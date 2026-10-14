import { Controller, Get, Param, UseGuards, ParseUUIDPipe } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { ReviewsService } from './reviews.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { User } from '../users/entities/user.entity';

@ApiTags('Reviews')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('reviews')
export class ReviewsController {
  constructor(private readonly reviewsService: ReviewsService) {}

  @Get('service/:serviceId')
  @Roles(UserRole.PARTNER, UserRole.ADMIN)
  @ApiOperation({ summary: 'Get reviews and rating summary for an activity (Partner/Admin)' })
  async getServiceReviews(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: User,
  ) {
    const data = await this.reviewsService.getServiceReviews(
      serviceId,
      user.id,
      user.role === UserRole.ADMIN,
    );
    return { message: 'Reviews fetched successfully', data };
  }
}
