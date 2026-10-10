import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsNotEmpty, IsOptional, IsString, IsUUID, Matches } from 'class-validator';

export class CreateBookingDto {
  @ApiProperty()
  @IsNotEmpty()
  @IsUUID()
  venueId: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsUUID()
  serviceId: string;

  @ApiPropertyOptional({ description: 'Category (activity) UUID — used to resolve per-slot pricing from venue availability' })
  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @ApiProperty({ example: '2024-12-25', description: 'Booking date in YYYY-MM-DD format' })
  @IsNotEmpty()
  @IsDateString()
  bookingDate: string;

  @ApiProperty({ example: '10:00', description: 'Start time in HH:mm format' })
  @IsNotEmpty()
  @IsString()
  @Matches(/^([0-1][0-9]|2[0-3]):[0-5][0-9]$/, { message: 'Start time must be in HH:mm format' })
  startTime: string;

  @ApiProperty({ example: '11:00', description: 'End time in HH:mm format' })
  @IsNotEmpty()
  @IsString()
  @Matches(/^([0-1][0-9]|2[0-3]):[0-5][0-9]$/, { message: 'End time must be in HH:mm format' })
  endTime: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;
}
