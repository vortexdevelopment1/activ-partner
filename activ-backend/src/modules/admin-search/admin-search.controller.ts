import { Controller, Get, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsString, Length } from 'class-validator';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { AdminSearchService } from './admin-search.service';

class AdminSearchQueryDto {
  @IsString()
  @Length(2, 100)
  q: string;
}

@ApiTags('Admin Search')
@ApiBearerAuth()
@Roles(UserRole.ADMIN)
@Controller('admin/search')
export class AdminSearchController {
  constructor(private readonly searchService: AdminSearchService) {}

  @Get()
  @ApiOperation({ summary: 'Search admin resources' })
  async search(@Query() query: AdminSearchQueryDto) {
    return { message: 'Search results fetched successfully', data: await this.searchService.search(query.q) };
  }
}
