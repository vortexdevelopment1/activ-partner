import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { VenueServiceStatus } from '../../../common/enums/venue-service-status.enum';

export class ActivityApprovalDto {
  @ApiProperty({ enum: [VenueServiceStatus.APPROVED, VenueServiceStatus.REJECTED] })
  @IsNotEmpty()
  @IsEnum(VenueServiceStatus)
  status: VenueServiceStatus.APPROVED | VenueServiceStatus.REJECTED;

  @ApiPropertyOptional({ description: 'Required when rejecting an activity' })
  @IsOptional()
  @IsString()
  reason?: string;
}
