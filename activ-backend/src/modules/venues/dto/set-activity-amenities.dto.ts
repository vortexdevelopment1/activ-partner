import { ApiProperty } from '@nestjs/swagger';
import { ArrayMinSize, IsArray, IsString } from 'class-validator';

export class SetActivityAmenitiesDto {
  @ApiProperty({
    type: [String],
    minItems: 1,
    example: ['Free Parking', 'WiFi', 'Air Conditioned', 'First Aid Kit'],
  })
  @IsArray()
  @ArrayMinSize(1, { message: 'Select at least one amenity' })
  @IsString({ each: true })
  amenities: string[];
}
