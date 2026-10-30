import { AdminNotificationsService } from './admin-notifications.service';
import { AdminNotificationType } from '../../common/domain-types';

describe('AdminNotificationsService deep links', () => {
  it('fans out to active admins and preserves routing IDs for every notification type', async () => {
    const prisma = {
      users: { findMany: jest.fn().mockResolvedValue([{ id: 'admin-1' }, { id: 'admin-2' }]) },
      notifications: { createMany: jest.fn().mockResolvedValue({ count: 2 }) },
    };
    const service = new AdminNotificationsService(prisma as any);
    for (const type of Object.values(AdminNotificationType)) {
      await service.notify(type, 'Event', 'Body', { venueId: 'venue', supportRequestId: 'request' });
      expect(prisma.notifications.createMany).toHaveBeenLastCalledWith({ data: [
        expect.objectContaining({ user_id: 'admin-1', type, data: { venueId: 'venue', supportRequestId: 'request' } }),
        expect.objectContaining({ user_id: 'admin-2', type, data: { venueId: 'venue', supportRequestId: 'request' } }),
      ] });
    }
    expect(prisma.users.findMany).toHaveBeenCalledWith({ where: { is_admin: true, status: 'ACTIVE' }, select: { id: true } });
  });

  it('keeps notification failures from breaking the original action', async () => {
    const service = new AdminNotificationsService({ users: { findMany: jest.fn().mockRejectedValue(new Error('Offline')) } } as any);
    (service as any).logger = { warn: jest.fn() };
    await expect(service.notify(AdminNotificationType.VENUE_SUBMITTED, 'Event', 'Body')).resolves.toBeUndefined();
    expect((service as any).logger.warn).toHaveBeenCalled();
  });
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
