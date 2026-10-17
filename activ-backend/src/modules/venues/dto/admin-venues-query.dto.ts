import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsIn, IsOptional, IsString, IsUUID } from 'class-validator';
import { PaginationDto } from '../../../common/dto/pagination.dto';
import { VenueStatus } from '../../../common/enums/venue-status.enum';

export class AdminVenuesQueryDto extends PaginationDto {
  @ApiPropertyOptional({ enum: ['newest', 'oldest', 'updated'], default: 'newest' })
  @IsOptional()
  @IsIn(['newest', 'oldest', 'updated'])
  sort?: 'newest' | 'oldest' | 'updated';

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  city?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  state?: string;

  @ApiPropertyOptional({ enum: VenueStatus })
  @IsOptional()
  @IsEnum(VenueStatus)
  status?: VenueStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  partnerId?: string;
}
