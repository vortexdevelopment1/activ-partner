import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsUUID } from 'class-validator';
import { CreateVenueDto } from './create-venue.dto';

export class AdminCreateVenueDto extends CreateVenueDto {
  @ApiProperty({ description: 'Partner UUID to create the venue for' })
  @IsNotEmpty()
  @IsUUID()
  partnerId: string;
}
