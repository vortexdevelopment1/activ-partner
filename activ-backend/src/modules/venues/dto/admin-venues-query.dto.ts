import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional, IsUUID } from 'class-validator';
import { PaginationDto } from '../../../common/dto/pagination.dto';
import { VenueStatus } from '../../../common/enums/venue-status.enum';

export class AdminVenuesQueryDto extends PaginationDto {
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
