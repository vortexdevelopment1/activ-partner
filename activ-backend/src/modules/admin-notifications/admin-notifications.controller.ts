import { Controller, Get, Param, ParseUUIDPipe, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { AdminNotificationsService } from './admin-notifications.service';

@ApiTags('admin-notifications')
@ApiBearerAuth()
@Controller('admin/notifications')
@Roles(UserRole.ADMIN)
export class AdminNotificationsController {
  constructor(private readonly service: AdminNotificationsService) {}

  @Get()
  @ApiOperation({ summary: 'List partner-account change notifications (newest first)' })
  async list(@CurrentUser() admin: any) {
    const data = await this.service.findAll(admin.id);
    return { message: 'Notifications fetched successfully', data };
  }

  @Get('unread-count')
  @ApiOperation({ summary: 'Unread notification count' })
  async unreadCount(@CurrentUser() admin: any) {
    const count = await this.service.unreadCount(admin.id);
    return { message: 'Unread count fetched successfully', data: { count } };
  }

  // NOTE: must be declared before ':id/read' so 'read-all' isn't matched as an id
  @Patch('read-all')
  @ApiOperation({ summary: 'Mark all notifications as read' })
  async markAllRead(@CurrentUser() admin: any) {
    await this.service.markAllRead(admin.id);
    return { message: 'All notifications marked as read' };
  }

  @Patch(':id/read')
  @ApiOperation({ summary: 'Mark one notification as read' })
  async markRead(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() admin: any,
  ) {
    const data = await this.service.markRead(id, admin.id);
    return { message: 'Notification marked as read', data };
  }
}
