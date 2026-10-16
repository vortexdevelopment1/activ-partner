import { AdminNotificationsService } from './admin-notifications.service';
import { AdminNotificationType } from './entities/admin-notification.entity';

describe('AdminNotificationsService deep links', () => {
  it('stores and returns notification metadata', async () => {
    const createMany = jest.fn().mockResolvedValue({ count: 1 });
    const prisma = {
      users: { findMany: jest.fn().mockResolvedValue([{ id: 'admin-id' }]) },
      notifications: {
        createMany,
        findMany: jest.fn().mockResolvedValue([{
          id: 'notification-id',
          type: AdminNotificationType.VENUE_UPDATED,
          title: 'Venue updated',
          body: 'A venue was updated',
          data: { venueId: 'venue-id' },
          read_at: null,
          created_at: new Date('2026-10-16T10:00:00Z'),
        }]),
      },
    };
    const service = new AdminNotificationsService(prisma as any);

    await service.notify(
      AdminNotificationType.VENUE_UPDATED,
      'Venue updated',
      'A venue was updated',
      { venueId: 'venue-id' },
    );
    const notifications = await service.findAll('admin-id');

    expect(createMany).toHaveBeenCalledWith({ data: [expect.objectContaining({
      user_id: 'admin-id', data: { venueId: 'venue-id' },
    })] });
    expect(notifications[0].data).toEqual({ venueId: 'venue-id' });
  });
});
