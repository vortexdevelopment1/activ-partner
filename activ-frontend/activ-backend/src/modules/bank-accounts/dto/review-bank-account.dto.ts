import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsNotEmpty, IsOptional, IsString, ValidateIf } from 'class-validator';
import { BankAccountStatus } from '../entities/bank-account.entity';

export class ReviewBankAccountDto {
  @ApiProperty({ enum: [BankAccountStatus.APPROVED, BankAccountStatus.REJECTED] })
  @IsNotEmpty()
  @IsEnum([BankAccountStatus.APPROVED, BankAccountStatus.REJECTED], {
    message: 'status must be approved or rejected',
  })
  status: BankAccountStatus.APPROVED | BankAccountStatus.REJECTED;

  @ApiPropertyOptional({ example: 'Account number does not match the cancelled cheque' })
  @ValidateIf((o) => o.status === BankAccountStatus.REJECTED)
  @IsNotEmpty({ message: 'rejectionReason is required when rejecting' })
  @IsString()
  rejectionReason?: string;
}
