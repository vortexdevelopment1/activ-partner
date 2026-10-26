import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional } from 'class-validator';
import { PaginationDto } from '../../../common/dto/pagination.dto';

export type ActivityReviewStatus = 'all' | 'pending' | 'approved' | 'rejected';

export class ActivityReviewQueryDto extends PaginationDto {
  @ApiPropertyOptional({ enum: ['all', 'pending', 'approved', 'rejected'], default: 'pending' })
  @IsOptional()
  @IsIn(['all', 'pending', 'approved', 'rejected'])
  status?: ActivityReviewStatus = 'pending';
}
