import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsNotEmpty, IsNumber, IsString, Max, Min } from 'class-validator';

export class CreateCityCommissionDto {
  @ApiProperty({ example: 'Mumbai', description: 'City name' })
  @IsNotEmpty()
  @IsString()
  city: string;

  @ApiProperty({ example: 15.5, description: 'Commission percentage (0-100)', minimum: 0, maximum: 100 })
  @IsNotEmpty()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(100)
  commissionPercentage: number;
}
