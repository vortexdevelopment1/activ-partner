import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, Matches } from 'class-validator';

export class VerifyOtpDto {
  @ApiProperty({ example: '9876543210', description: 'Partner mobile number' })
  @IsString()
  @IsNotEmpty()
  phone: string;

  @ApiProperty({ example: '3210', description: 'OTP received via SMS' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^\d{4,6}$/, { message: 'OTP must be 4 to 6 digits' })
  otp: string;
}
