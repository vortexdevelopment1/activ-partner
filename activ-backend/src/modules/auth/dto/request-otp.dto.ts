import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty } from 'class-validator';

export class RequestOtpDto {
  @ApiProperty({ example: '9876543210', description: 'Partner mobile number' })
  @IsString()
  @IsNotEmpty()
  phone: string;
}
