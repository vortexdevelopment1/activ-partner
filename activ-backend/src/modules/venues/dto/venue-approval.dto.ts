import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { VenueStatus } from '../../../common/enums/venue-status.enum';

export class VenueApprovalDto {
  @ApiProperty({ enum: [VenueStatus.APPROVED, VenueStatus.REJECTED, VenueStatus.SUSPENDED, VenueStatus.PENDING], description: 'pending with a reason requests corrections before approval' })
  @IsNotEmpty()
  @IsIn([VenueStatus.APPROVED, VenueStatus.REJECTED, VenueStatus.SUSPENDED, VenueStatus.PENDING])
  status: VenueStatus;

  @ApiPropertyOptional({ description: 'Required when rejecting or suspending a venue' })
  @IsOptional()
  @IsString()
  reason?: string;
}
