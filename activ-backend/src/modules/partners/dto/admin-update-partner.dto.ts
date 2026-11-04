import { ApiPropertyOptional, OmitType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsArray, IsBoolean, IsEmail, ValidateIf, IsEnum, IsNotEmpty, Matches, IsOptional, IsString, IsUUID, ValidateNested } from 'class-validator';
import { PartnerStatus, PartnerKycStatus, PartnerBankAccountStatus } from '../../../generated/prisma/client';
import { UpdatePartnerDto } from './update-partner.dto';

export class AdminPartnerBankAccountDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  id?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsNotEmpty()
  @Matches(/^[\p{L}\p{M}\s.'-]+$/u, { message: 'Account holder name must contain only letters' })
  accountHolderName: string;

  @ApiPropertyOptional()
  @IsString()
  @IsNotEmpty()
  bankName: string;

  @ApiPropertyOptional()
  @IsString()
  @IsNotEmpty()
  @Matches(/^[0-9]{6,20}$/, { message: 'Account number must contain 6 to 20 digits' })
  accountNumber: string;

  @ApiPropertyOptional()
  @IsString()
  @IsNotEmpty()
  @Matches(/^[A-Z]{4}0[A-Z0-9]{6}$/i, { message: 'Invalid IFSC code' })
  ifscCode: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  accountType?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  branchName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  cancelledChequeUrl?: string;

  @ApiPropertyOptional()
  @ValidateIf((_o, v) => v !== undefined && v !== null && v !== '')
  @Matches(/^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$/, { message: 'Invalid UPI ID format' })
  upiId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  rejectionReason?: string;

  @IsEnum(PartnerBankAccountStatus)
  status: PartnerBankAccountStatus;
  @IsBoolean()
  isPrimary: boolean;
}

export class AdminUpdatePartnerDto extends OmitType(UpdatePartnerDto, ['email'] as const) {
  @ApiPropertyOptional()
  @ValidateIf((_object, value) => value !== undefined && value !== '')
  @IsEmail()
  email?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  legalName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  ownerName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  contactPhone?: string;

  @ApiPropertyOptional()
  @ValidateIf((_object, value) => value !== undefined && value !== '')
  @IsEmail()
  businessEmail?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  addressLine2?: string;

  @ApiPropertyOptional()
  @ValidateIf((_object, value) => value !== undefined && value !== null && value !== '')
  @Matches(/^[A-Z]{5}[0-9]{4}[A-Z]{1}$/, { message: 'Invalid PAN number format (e.g. ABCDE1234F)' })
  panNumber?: string;

  @ApiPropertyOptional()
  @ValidateIf((_object, value) => value !== undefined && value !== null && value !== '')
  @Matches(/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/, {
    message: 'Invalid GST number format (e.g. 27AAPFU0939F1ZV)',
  })
  gstNumber?: string;

  @ApiPropertyOptional()
  @ValidateIf((_object, value) => value !== undefined && value !== null && value !== '')
  @Matches(/^(\d{12}|\d{4}[-\s]\d{4}[-\s]\d{4})$/, {
    message: 'Invalid Aadhaar number format (must be 12 digits)',
  })
  aadhaarNumber?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  aadhaarCardUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  gstinDocUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  panCardUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  avatarUrl?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  rejectionReason?: string;

  @ApiPropertyOptional({ enum: PartnerStatus })
  @ValidateIf((_object, value) => value !== undefined)
  @IsEnum(PartnerStatus)
  status?: PartnerStatus;

  @ApiPropertyOptional({ enum: PartnerKycStatus })
  @IsOptional()
  @IsEnum(PartnerKycStatus)
  kycStatus?: PartnerKycStatus;

  @ApiPropertyOptional({ type: [AdminPartnerBankAccountDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => AdminPartnerBankAccountDto)
  bankAccounts?: AdminPartnerBankAccountDto[];
}
