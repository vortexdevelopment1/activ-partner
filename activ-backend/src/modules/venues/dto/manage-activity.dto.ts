import {
  IsArray,
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
} from "class-validator";

export class ManageActivityDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  description?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  amenities?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(50)
  numberOfCourt?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  courtType?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  playingEnvironment?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  coachingAvailable?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  recommendedFor?: string[];

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}
