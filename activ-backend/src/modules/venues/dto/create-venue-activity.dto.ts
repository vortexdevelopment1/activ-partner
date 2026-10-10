import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsUUID } from 'class-validator';

export class CreateVenueActivityDto {
  @ApiProperty({ description: 'Category id selected on the "Select activity" screen', format: 'uuid' })
  @IsNotEmpty()
  @IsUUID()
  categoryId: string;
}
