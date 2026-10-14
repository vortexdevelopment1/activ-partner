import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsEmail, IsNotEmpty, Matches, IsDateString } from 'class-validator';

export class CreateCallbackRequestDto {
  @ApiProperty({ example: 'Sanjay Kapoor' })
  @IsString()
  @IsNotEmpty()
  partnerName: string;

  @ApiProperty({ example: 'sanjayKapoor78@yopmail.com' })
  @IsEmail()
  @IsNotEmpty()
  email: string;

  @ApiProperty({ example: '6546546546' })
  @IsString()
  @IsNotEmpty()
  phone: string;

  @ApiProperty({ example: 'Gold Gym' })
  @IsString()
  @IsNotEmpty()
  venueName: string;

  @ApiProperty({ example: 'India' })
  @IsString()
  @IsNotEmpty()
  city: string;

  @ApiProperty({ example: '2026-06-18' })
  @IsDateString()
  @IsNotEmpty()
  callbackDate: string;

  @ApiProperty({ example: '10:00 AM' })
  @IsString()
  @IsNotEmpty()
  callbackTime: string;

  @ApiProperty({ example: 'Hello' })
  @IsString()
  @IsNotEmpty()
  query: string;
}
