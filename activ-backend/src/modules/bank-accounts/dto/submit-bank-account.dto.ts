import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsNotEmpty, IsOptional, IsString, Matches } from 'class-validator';

export class SubmitBankAccountDto {
  @ApiProperty({ example: 'Rahul Sharma' })
  @IsNotEmpty()
  @IsString()
  accountHolderName: string;

  @ApiProperty({ example: 'HDFC Bank' })
  @IsNotEmpty()
  @IsString()
  bankName: string;

  @ApiProperty({ example: '1234567890' })
  @Matches(/^[0-9]{6,20}$/, { message: 'Account number must contain 6 to 20 digits' })
  @IsNotEmpty()
  @IsString()
  accountNumber: string;

  @ApiProperty({ example: 'HDFC0001234' })
  @Matches(/^[A-Z]{4}0[A-Z0-9]{6}$/, { message: 'Invalid IFSC code' })
  @IsNotEmpty()
  @IsString()
  ifscCode: string;

  @ApiProperty({ example: 'Saving Account' })
  @IsIn(['Saving Account', 'Current Account'])
  @IsNotEmpty()
  @IsString()
  accountType: string;

  @ApiPropertyOptional({ example: 'Kormangala, Bengaluru' })
  @IsOptional()
  @IsString()
  branchName?: string;
}
