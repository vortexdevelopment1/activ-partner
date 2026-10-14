import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsEnum, IsOptional, IsString, Matches, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { TeamMemberRole } from '../../../common/enums/team-member-role.enum';

class UpdatePermissionsDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  bookingManagement?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  pricingControl?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  analyticsView?: boolean;
}

export class UpdateTeamMemberDto {
  @ApiPropertyOptional({ example: 'Abhishek Sharma' })
  @IsOptional()
  @IsString()
  fullName?: string;

  @ApiPropertyOptional({ example: '+919876543210', description: 'Mobile number in E.164 format' })
  @IsOptional()
  @Matches(/^\+[1-9]\d{9,14}$/, { message: 'Phone must be in E.164 format, e.g. +919876543210' })
  phone?: string;

  @ApiPropertyOptional({ enum: TeamMemberRole })
  @IsOptional()
  @IsEnum(TeamMemberRole)
  role?: TeamMemberRole;

  @ApiPropertyOptional({ type: UpdatePermissionsDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => UpdatePermissionsDto)
  permissions?: UpdatePermissionsDto;
}
