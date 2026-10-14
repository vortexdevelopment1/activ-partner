import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class CreateSupportEmailDto {
  @ApiProperty({ example: 'Issue with booking' })
  @IsString()
  @IsNotEmpty()
  subject: string;

  @ApiProperty({ example: 'I am facing an issue with my recent booking.' })
  @IsString()
  @IsNotEmpty()
  message: string;
}
