import { ApiProperty } from '@nestjs/swagger';
import { ArrayMaxSize, ArrayMinSize, IsArray, IsNotEmpty, IsUUID } from 'class-validator';
import { CreateVenueDto } from './create-venue.dto';

export class AdminCreateVenueDto extends CreateVenueDto {
  @ApiProperty({ description: 'Exactly one activity category for initial venue creation', type: [String], minItems: 1, maxItems: 1 })
  @IsArray()
  @IsUUID('4', { each: true })
  @ArrayMinSize(1, { message: 'Select one activity category for the venue' })
  @ArrayMaxSize(1, { message: 'Only one activity category is allowed when creating a venue' })
  categoryIds: string[];

  @ApiProperty({ description: 'Partner UUID to create the venue for' })
  @IsNotEmpty()
  @IsUUID()
  partnerId: string;
}
