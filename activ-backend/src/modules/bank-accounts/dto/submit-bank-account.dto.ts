import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

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
  @IsNotEmpty()
  @IsString()
  accountNumber: string;

  @ApiProperty({ example: 'HDFC0001234' })
  @IsNotEmpty()
  @IsString()
  ifscCode: string;

  @ApiProperty({ example: 'Saving Account' })
  @IsNotEmpty()
  @IsString()
  accountType: string;

  @ApiPropertyOptional({ example: 'Kormangala, Bengaluru' })
  @IsOptional()
  @IsString()
  branchName?: string;
}
