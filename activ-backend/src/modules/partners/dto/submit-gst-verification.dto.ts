import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, Matches } from 'class-validator';

export class SubmitGstVerificationDto {
  @ApiProperty({ example: '27AAPFU0939F1ZV' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/, {
    message: 'Invalid GST number format',
  })
  gstNumber: string;

  @ApiProperty({ example: 'Acme Fitness Pvt Ltd' })
  @IsString()
  @IsNotEmpty()
  gstName: string;
}
