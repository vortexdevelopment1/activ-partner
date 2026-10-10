import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsEnum, IsNotEmpty, IsOptional, Matches, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
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
  @IsNotEmpty()
  fullName: string;

  @ApiProperty({ example: '+919876543210', description: 'Mobile number in E.164 format' })
  @IsNotEmpty()
  @Matches(/^\+[1-9]\d{9,14}$/, { message: 'Phone must be in E.164 format, e.g. +919876543210' })
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
