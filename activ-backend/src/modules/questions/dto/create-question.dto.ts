import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateIf,
} from 'class-validator';
import { Type } from 'class-transformer';
import { QuestionType } from '../../../common/enums/question-type.enum';

export class CreateQuestionDto {
  @ApiPropertyOptional({ description: 'If null, question applies to all categories' })
  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @ApiProperty({ example: 'What type of flooring does the venue have?' })
  @IsNotEmpty()
  @IsString()
  questionText: string;

  @ApiProperty({ enum: QuestionType, default: QuestionType.TEXT })
  @IsEnum(QuestionType)
  questionType: QuestionType;

  @ApiPropertyOptional({ example: ['Wooden', 'Synthetic', 'Concrete'], type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  options?: string[];

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isRequired?: boolean;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  order?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  placeholder?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  helperText?: string;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @ApiPropertyOptional({ description: 'Minimum character length (for text questions)', nullable: true })
  @IsOptional()
  @ValidateIf((o) => o.minLength !== null)
  @IsInt()
  @Min(0)
  @Type(() => Number)
  minLength?: number | null;

  @ApiPropertyOptional({ description: 'Maximum character length (for text questions)', nullable: true })
  @IsOptional()
  @ValidateIf((o) => o.maxLength !== null)
  @IsInt()
  @Min(1)
  @Type(() => Number)
  maxLength?: number | null;
}
