import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, ValidateBy } from 'class-validator';
import { Transform } from 'class-transformer';
import { isValidGstin } from '../../../common/utils/gstin-validation';

export class SubmitGstVerificationDto {
  @ApiProperty({ example: '27AAPFU0939F1ZV' })
  @IsString()
  @IsNotEmpty()
  @Transform(({ value }) => typeof value === 'string' ? value.trim().toUpperCase() : value)
  @ValidateBy({ name: 'isGstin', validator: { validate: isValidGstin } }, {
    message: 'Enter a valid 15-character GSTIN.',
  })
  gstNumber: string;

  @ApiProperty({ example: 'Acme Fitness Pvt Ltd' })
  @IsString()
  @IsNotEmpty()
  gstName: string;
}
