import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  ValidateNested,
  IsObject,
} from 'class-validator';
import { Type } from 'class-transformer';

export class VenueServiceDto {
  @ApiProperty({ example: 'Badminton Court 1' })
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ example: 500 })
  @IsNumber()
  pricePerHour: number;

  @ApiPropertyOptional({ example: 60, description: 'Minimum booking duration in minutes' })
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
}

export class VenueAnswerDto {
  @ApiProperty()
  @IsNotEmpty()
  @IsUUID()
  questionId: string;

  @ApiProperty()
  @IsNotEmpty()
  answer: any;
}

export class CreateVenueDto {
  @ApiProperty({ description: 'One or more category UUIDs', type: [String] })
  @IsArray()
  @IsUUID('4', { each: true })
  categoryIds: string[];

  @ApiProperty({ example: 'Champions Sports Arena' })
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ example: '45, Sports Complex Road' })
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional({ example: 'Bengaluru' })
  @IsOptional()
  @IsString()
  city?: string;

  @ApiPropertyOptional({ example: 'Karnataka' })
  @IsOptional()
  @IsString()
  state?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  zipCode?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  latitude?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  longitude?: number;

  @ApiPropertyOptional({ example: '06:00' })
  @IsOptional()
  @IsString()
  openingTime?: string;

  @ApiPropertyOptional({ example: '22:00' })
  @IsOptional()
  @IsString()
  closingTime?: string;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  amenities?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  rules?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiPropertyOptional({ example: '+91 9876543210', description: 'Venue contact phone number' })
  @IsOptional()
  @IsString()
  venuePhone?: string;

  @ApiPropertyOptional({ example: 'https://maps.app.goo.gl/xyz', description: 'Google Maps location URL' })
  @IsOptional()
  @IsString()
  locationUrl?: string;

  @ApiPropertyOptional({ example: '202, 2nd Floor', description: 'Flat/Building/Floor details' })
  @IsOptional()
  @IsString()
  flatBuilding?: string;

  @ApiPropertyOptional({ example: '45, Sports Complex Road, Sector 12', description: 'Full venue address' })
  @IsOptional()
  @IsString()
  venueAddress?: string;

  @ApiPropertyOptional({ type: [VenueServiceDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => VenueServiceDto)
  services?: VenueServiceDto[];

  @ApiPropertyOptional({ type: [VenueAnswerDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => VenueAnswerDto)
  answers?: VenueAnswerDto[];

  @ApiPropertyOptional({ example: 15.00, description: 'Commission percentage for this venue' })
  @IsOptional()
  @IsNumber()
  commission?: number;
}
