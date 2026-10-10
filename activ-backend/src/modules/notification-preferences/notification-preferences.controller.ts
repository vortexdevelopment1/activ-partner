import { Body, Controller, Get, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { NotificationPreferencesService } from './notification-preferences.service';
import { UpdateNotificationPreferencesDto } from './dto/update-notification-preferences.dto';

@ApiTags('notification-preferences')
@ApiBearerAuth()
@Controller('notification-preferences')
@Roles(UserRole.PARTNER)
export class NotificationPreferencesController {
  constructor(private readonly service: NotificationPreferencesService) {}

  @Get()
  @ApiOperation({ summary: 'Get notification preferences for the authenticated partner' })
  async getPreferences(@CurrentUser() partner: any) {
    const data = await this.service.getPreferences(partner.id);
    return { message: 'Notification preferences fetched successfully', data };
  }

  @Patch()
  @ApiOperation({ summary: 'Save / update notification preferences for the authenticated partner' })
  async updatePreferences(
    @CurrentUser() partner: any,
    @Body() dto: UpdateNotificationPreferencesDto,
  ) {
    const data = await this.service.upsertPreferences(partner.id, dto);
    return { message: 'Notification preferences saved successfully', data };
  }
}
