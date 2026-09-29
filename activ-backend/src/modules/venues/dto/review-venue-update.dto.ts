import { IsOptional, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class ReviewVenueUpdateDto {
  @ApiPropertyOptional({ example: 'Address details do not match records' })
  @IsOptional()
  @IsString()
  adminNotes?: string;
}
