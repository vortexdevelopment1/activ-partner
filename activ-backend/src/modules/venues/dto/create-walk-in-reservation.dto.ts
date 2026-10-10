import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsOptional,
  IsArray,
  ValidateNested,
  IsNotEmpty,
  Matches,
} from 'class-validator';
import { Type } from 'class-transformer';

class SlotDto {
  @ApiProperty({ example: '09:00', description: 'Start time HH:mm (24h)' })
  @IsString()
  @Matches(/^\d{2}:\d{2}$/, { message: 'startTime must be HH:mm' })
  startTime: string;

  @ApiProperty({ example: '10:00', description: 'End time HH:mm (24h)' })
  @IsString()
  @Matches(/^\d{2}:\d{2}$/, { message: 'endTime must be HH:mm' })
  endTime: string;
}

export class CreateWalkInReservationDto {
  @ApiProperty({ example: '2026-07-10', description: 'Date YYYY-MM-DD' })
  @IsString()
  @IsNotEmpty()
  date: string;

  @ApiPropertyOptional({ example: 'Court 01', description: 'Court name (only for activities with courts)' })
  @IsOptional()
  @IsString()
  court?: string;

  @ApiProperty({ type: [SlotDto], description: 'One or more time slots to reserve' })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SlotDto)
  slots: SlotDto[];

  @ApiProperty({ example: 'Virat Kohli' })
  @IsString()
  @IsNotEmpty()
  participantName: string;

  @ApiProperty({ example: '+91 98000 00000' })
  @IsString()
  @IsNotEmpty()
  participantPhone: string;

  @ApiPropertyOptional({ example: 'virat@example.com' })
  @IsOptional()
  @IsString()
  participantEmail?: string;
}
