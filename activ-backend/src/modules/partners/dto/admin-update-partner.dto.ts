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
  @IsOptional()
  @IsString()
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
