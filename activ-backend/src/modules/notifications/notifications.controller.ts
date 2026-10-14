import { Controller, Get, Param, ParseUUIDPipe, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { NotificationsService } from './notifications.service';

@ApiTags('notifications')
@ApiBearerAuth()
@Controller('notifications')
@Roles(UserRole.PARTNER)
export class NotificationsController {
  constructor(private readonly service: NotificationsService) {}

  @Get()
  @ApiOperation({ summary: "List the authenticated partner's notifications (newest first)" })
  async list(@CurrentUser() partner: any) {
    const data = await this.service.findByPartner(partner.id);
    return { message: 'Notifications fetched successfully', data };
  }

  @Get('unread-count')
  @ApiOperation({ summary: 'Unread notification count for the authenticated partner' })
  async unreadCount(@CurrentUser() partner: any) {
    const count = await this.service.unreadCount(partner.id);
    return { message: 'Unread count fetched successfully', data: { count } };
  }

  // NOTE: must be declared before ':id/read' so 'read-all' isn't matched as an id
  @Patch('read-all')
  @ApiOperation({ summary: 'Mark all notifications as read' })
  async markAllRead(@CurrentUser() partner: any) {
    await this.service.markAllRead(partner.id);
    return { message: 'All notifications marked as read' };
  }

  @Patch(':id/read')
  @ApiOperation({ summary: 'Mark one notification as read' })
  async markRead(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() partner: any,
  ) {
    const data = await this.service.markRead(id, partner.id);
    return { message: 'Notification marked as read', data };
  }
}
