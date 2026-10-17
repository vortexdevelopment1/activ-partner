import { ApiProperty, ApiPropertyOptional } from "@nestjs/swagger";
import { Type } from "class-transformer";
import {
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
} from "class-validator";

export class CreateCityCommissionDto {
  @ApiPropertyOptional({
    example: "Mumbai",
    description: "City name; omit for a state-wide rule",
  })
  @IsOptional()
  @IsString()
  city?: string;

  @ApiPropertyOptional({
    example: "Maharashtra",
    description: "State name; omit for a city-only rule",
  })
  @IsOptional()
  @IsString()
  state?: string | null;

  @ApiProperty({
    example: 15.5,
    description: "Commission percentage (0-100)",
    minimum: 0,
    maximum: 100,
  })
  @IsNotEmpty()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(100)
  commissionPercentage: number;
}
