import { IsString, IsOptional, IsNumber, MaxLength } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';

export class SubmitVenueUpdateDto {
  @ApiPropertyOptional({ example: 'Xtreme Fitness Pro' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  name?: string;

  @ApiPropertyOptional({ example: 'Updated venue description' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ example: 'Food Plaza, Main Road' })
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional({ example: 'Kharar' })
  @IsOptional()
  @IsString()
  city?: string;

  @ApiPropertyOptional({ example: 'Punjab' })
  @IsOptional()
  @IsString()
  state?: string;

  @ApiPropertyOptional({ example: '140307' })
  @IsOptional()
  @IsString()
  zipCode?: string;

  @ApiPropertyOptional({ example: 'Shop 2, City Plaza' })
  @IsOptional()
  @IsString()
  flatBuilding?: string;

  @ApiPropertyOptional({ example: 30.7231244 })
  @IsOptional()
  @IsNumber()
  @Type(() => Number)
  latitude?: number;

  @ApiPropertyOptional({ example: 76.652704 })
  @IsOptional()
  @IsNumber()
  @Type(() => Number)
  longitude?: number;

  @ApiPropertyOptional({ example: 'https://maps.google.com/?q=place_id:ChIJ...' })
  @IsOptional()
  @IsString()
  locationUrl?: string;

  @ApiPropertyOptional({ example: '+919876543210' })
  @IsOptional()
  @IsString()
  venuePhone?: string;
}
