import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsEnum, IsInt, IsNotEmpty, IsOptional, IsString, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { CategoryType } from '../../../common/enums/category-type.enum';

export class CreateCategoryDto {
  @ApiProperty({ example: 'Gym' })
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiPropertyOptional({ example: 'Fitness centers and gyms' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ enum: CategoryType, example: CategoryType.SINGLE_BOOKING })
  @IsNotEmpty()
  @IsEnum(CategoryType)
  type: CategoryType;

  @ApiPropertyOptional({ example: 'dumbbell' })
  @IsOptional()
  @IsString()
  icon?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  imageUrl?: string;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  order?: number;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
