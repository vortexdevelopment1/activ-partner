import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsInt, IsOptional, IsString, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class UpdateFaqDto {
  @ApiPropertyOptional({ example: 'How do I cancel a booking?' })
  @IsOptional()
  @IsString()
  question?: string;

  @ApiPropertyOptional({ example: 'Visit My Bookings and tap Cancel.' })
  @IsOptional()
  @IsString()
  answer?: string;

  @ApiPropertyOptional({ example: 2 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  order?: number;

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
