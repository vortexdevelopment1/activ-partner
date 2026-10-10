import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { VenueStatus } from '../../../common/enums/venue-status.enum';

export class VenueApprovalDto {
  @ApiProperty({ enum: [VenueStatus.APPROVED, VenueStatus.REJECTED, VenueStatus.SUSPENDED] })
  @IsNotEmpty()
  @IsEnum(VenueStatus)
  status: VenueStatus;

  @ApiPropertyOptional({ description: 'Required when rejecting or suspending a venue' })
  @IsOptional()
  @IsString()
  reason?: string;
}
