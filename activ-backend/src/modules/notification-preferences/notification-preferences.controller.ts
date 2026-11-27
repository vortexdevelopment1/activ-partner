import { Body, Controller, Get, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { NotificationPreferencesService } from './notification-preferences.service';
import { UpdateNotificationPreferencesDto } from './dto/update-notification-preferences.dto';

type PreferencesUser =
  | { role: UserRole.PARTNER; id: string }
  | { role: UserRole.TEAM_MEMBER; partnerId: string };

@ApiTags('notification-preferences')
@ApiBearerAuth()
@Controller('notification-preferences')
@Roles(UserRole.PARTNER, UserRole.TEAM_MEMBER)
export class NotificationPreferencesController {
  constructor(private readonly service: NotificationPreferencesService) {}

  @Get()
  @ApiOperation({ summary: 'Get notification preferences for your partner account' })
  async getPreferences(@CurrentUser() user: PreferencesUser) {
    const partnerId = user.role === UserRole.TEAM_MEMBER ? user.partnerId : user.id;
    const data = await this.service.getPreferences(partnerId);
    return { message: 'Notification preferences fetched successfully', data };
  }

  @Patch()
  @ApiOperation({ summary: 'Save notification preferences for your partner account' })
  async updatePreferences(
    @CurrentUser() user: PreferencesUser,
    @Body() dto: UpdateNotificationPreferencesDto,
  ) {
    const partnerId = user.role === UserRole.TEAM_MEMBER ? user.partnerId : user.id;
    const data = await this.service.upsertPreferences(partnerId, dto);
    return { message: 'Notification preferences saved successfully', data };
  }
}
