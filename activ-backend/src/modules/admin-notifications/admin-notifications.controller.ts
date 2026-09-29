import { Controller, Get, Param, ParseUUIDPipe, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { Roles } from '../../common/decorators/roles.decorator';
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
  async list() {
    const data = await this.service.findAll();
    return { message: 'Notifications fetched successfully', data };
  }

  @Get('unread-count')
  @ApiOperation({ summary: 'Unread notification count' })
  async unreadCount() {
    const count = await this.service.unreadCount();
    return { message: 'Unread count fetched successfully', data: { count } };
  }

  // NOTE: must be declared before ':id/read' so 'read-all' isn't matched as an id
  @Patch('read-all')
  @ApiOperation({ summary: 'Mark all notifications as read' })
  async markAllRead() {
    await this.service.markAllRead();
    return { message: 'All notifications marked as read' };
  }

  @Patch(':id/read')
  @ApiOperation({ summary: 'Mark one notification as read' })
  async markRead(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.service.markRead(id);
    return { message: 'Notification marked as read', data };
  }
}
