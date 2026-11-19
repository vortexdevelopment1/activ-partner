import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsEmail, IsEnum, IsNotEmpty, IsOptional, IsString, Matches, MaxLength, ValidateNested } from 'class-validator';
import { Transform, Type } from 'class-transformer';
import { TeamMemberRole } from '../../../common/enums/team-member-role.enum';

class PermissionsDto {
  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  bookingManagement?: boolean = false;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  pricingControl?: boolean = false;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  analyticsView?: boolean = false;
}

export class CreateTeamMemberDto {
  @ApiProperty({ example: 'Abhishek Sharma' })
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsNotEmpty()
  @IsString()
  @MaxLength(100)
  fullName: string;

  @ApiPropertyOptional({ example: 'member@example.com' })
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiProperty({ example: '+919876543210', description: 'Mobile number in E.164 format' })
  @IsNotEmpty()
  @Matches(/^\+(?:91[6-9]\d{9}|(?!91)[1-9]\d{9,14})$/, { message: 'Enter a valid phone number; Indian mobiles must have 10 digits starting with 6-9 after +91' })
  phone: string;

  @ApiProperty({ enum: TeamMemberRole, example: TeamMemberRole.MANAGER })
  @IsNotEmpty()
  @IsEnum(TeamMemberRole)
  role: TeamMemberRole;

  @ApiPropertyOptional({ type: PermissionsDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => PermissionsDto)
  permissions?: PermissionsDto;
}
