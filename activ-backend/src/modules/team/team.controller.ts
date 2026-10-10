import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  ParseUUIDPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { TeamService } from './team.service';
import { CreateTeamMemberDto } from './dto/create-team-member.dto';
import { UpdateTeamMemberDto } from './dto/update-team-member.dto';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';

@ApiTags('Team')
@ApiBearerAuth()
@Roles(UserRole.PARTNER)
@Controller('team')
export class TeamController {
  constructor(private readonly teamService: TeamService) {}

  @Get()
  @ApiOperation({ summary: 'List all team members (Partner only)' })
  async findAll(@CurrentUser() user: any) {
    const data = await this.teamService.findAll(user.id);
    return { message: 'Team members fetched successfully', data };
  }

  @Post()
  @ApiOperation({ summary: 'Add a new team member — creates account and sends invite email (Partner only)' })
  async create(@CurrentUser() user: any, @Body() dto: CreateTeamMemberDto) {
    const data = await this.teamService.create(user.id, dto);
    return { message: 'Team member added and invite sent successfully', data };
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update team member details or permissions (Partner only)' })
  async update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: any,
    @Body() dto: UpdateTeamMemberDto,
  ) {
    const data = await this.teamService.update(id, user.id, dto);
    return { message: 'Team member updated successfully', data };
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Remove a team member (Partner only)' })
  async remove(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: any) {
    await this.teamService.remove(id, user.id);
    return { message: 'Team member removed successfully' };
  }
}
