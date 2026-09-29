import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsNotEmpty, IsNumber, IsOptional, IsString } from 'class-validator';

export class AddVenueServiceDto {
  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty()
  @IsNumber()
  pricePerHour: number;

  @ApiPropertyOptional({ default: 60 })
  @IsOptional()
  @IsNumber()
  minDuration?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  maxDuration?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  capacity?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  imageUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
