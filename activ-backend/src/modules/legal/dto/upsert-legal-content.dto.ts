import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MinLength } from 'class-validator';

export class UpsertLegalContentDto {
  @ApiProperty({ description: 'Full HTML or plain text content' })
  @IsNotEmpty()
  @IsString()
  @MinLength(10)
  content: string;
}
