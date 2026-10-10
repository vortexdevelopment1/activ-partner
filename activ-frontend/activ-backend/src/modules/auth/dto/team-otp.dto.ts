import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, Matches } from 'class-validator';

export class RequestTeamOtpDto {
  @ApiProperty({ example: '+919876543210', description: 'Team member phone in E.164 format' })
  @IsNotEmpty()
  @Matches(/^\+[1-9]\d{9,14}$/, { message: 'Phone must be in E.164 format, e.g. +919876543210' })
  phone: string;
}

export class VerifyTeamOtpDto {
  @ApiProperty({ example: '+919876543210' })
  @IsNotEmpty()
  @Matches(/^\+[1-9]\d{9,14}$/, { message: 'Phone must be in E.164 format, e.g. +919876543210' })
  phone: string;

  @ApiProperty({ example: '3210', description: 'OTP received via SMS' })
  @IsNotEmpty()
  otp: string;
}
