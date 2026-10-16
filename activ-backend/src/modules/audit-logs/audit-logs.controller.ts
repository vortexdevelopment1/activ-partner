import { Controller, Get, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { AuditLogsService } from './audit-logs.service';

class AuditLogsQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1)
  page = 1;

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100)
  limit = 25;

  @IsOptional() @IsString()
  search?: string;

  @IsOptional() @IsString()
  resource?: string;

  @IsOptional() @IsIn(['success', 'failed'])
  outcome?: 'success' | 'failed';
}

@ApiTags('Audit Logs')
@ApiBearerAuth()
@Roles(UserRole.ADMIN)
@Controller('admin/logs')
export class AuditLogsController {
  constructor(private readonly service: AuditLogsService) {}

  @Get()
  @ApiOperation({ summary: 'List activity logs (Admin only)' })
  async findAll(@Query() query: AuditLogsQueryDto) {
    return { message: 'Logs fetched successfully', data: await this.service.findAll(query) };
  }
}
