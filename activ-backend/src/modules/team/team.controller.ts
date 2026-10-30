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
  UploadedFile,
  UseInterceptors,
  BadRequestException,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { TeamService } from './team.service';
import { CreateTeamMemberDto } from './dto/create-team-member.dto';
import { UpdateTeamMemberDto } from './dto/update-team-member.dto';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { CloudinaryService } from '../cloudinary/cloudinary.service';

@ApiTags('Team')
@ApiBearerAuth()
@Roles(UserRole.PARTNER)
@Controller('team')
export class TeamController {
  constructor(
    private readonly teamService: TeamService,
    private readonly cloudinaryService: CloudinaryService,
  ) {}

  @Patch('profile/avatar')
  @Roles(UserRole.TEAM_MEMBER)
  @UseInterceptors(FileInterceptor('avatar', { storage: memoryStorage() }))
  async updateProfileAvatar(
    @CurrentUser() user: any,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('Avatar image file is required');
    const avatarUrl = await this.cloudinaryService.uploadFile(
      file,
      'activ/avatars',
      'image',
    );
    await this.teamService.updateAvatar(user.id, avatarUrl);
    return { message: 'Profile photo updated successfully', data: { avatarUrl } };
  }

  @Delete('profile/avatar')
  @Roles(UserRole.TEAM_MEMBER)
  async removeProfileAvatar(@CurrentUser() user: any) {
    await this.teamService.removeAvatar(user.id);
    return { message: 'Profile photo removed successfully' };
  }

  @Get()
  @ApiOperation({ summary: 'List all team members (Partner only)' })
  async findAll(@CurrentUser() user: any) {
    const data = await this.teamService.findAll(user.id);
    return { message: 'Team members fetched successfully', data };
  }

  @Post()
  @ApiOperation({ summary: 'Add a team member and attempt SMS/email invitation (Partner only)' })
  async create(@CurrentUser() user: any, @Body() dto: CreateTeamMemberDto) {
    const data = await this.teamService.create(user.id, dto);
    return { message: 'Team member added; check invitation delivery status', data };
  }

  @Post(':id/invite')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Resend an invitation for an owned team member (Partner only)' })
  async resendInvitation(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: any) {
    const data = await this.teamService.resendInvitation(id, user.id);
    return { message: 'Invitation processed; check delivery status', data };
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
