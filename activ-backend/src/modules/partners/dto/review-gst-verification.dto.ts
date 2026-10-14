import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class ReviewGstVerificationDto {
  @ApiPropertyOptional({ example: 'GST document is blurry, please resubmit.' })
  @IsOptional()
  @IsString()
  adminNotes?: string;
}
