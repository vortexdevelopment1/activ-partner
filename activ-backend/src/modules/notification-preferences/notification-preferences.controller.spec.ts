import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { UserRole } from '../../common/enums/user-role.enum';
import { RolesGuard } from '../../common/guards/roles.guard';
import { NotificationPreferencesController } from './notification-preferences.controller';
import { NotificationPreferencesService } from './notification-preferences.service';

describe('notification preferences access', () => {
  const guard = new RolesGuard(new Reflector());
  const contextFor = (method: keyof NotificationPreferencesController, user?: object) => ({
    getHandler: () => NotificationPreferencesController.prototype[method],
    getClass: () => NotificationPreferencesController,
    switchToHttp: () => ({ getRequest: () => ({ user }) }),
  }) as unknown as ExecutionContext;

  it.each([
    { user: { role: UserRole.PARTNER as const, id: 'owner-partner' }, partnerId: 'owner-partner' },
    { user: { role: UserRole.TEAM_MEMBER as const, id: 'staff-profile', partnerId: 'staff-partner',
      permissions: { bookingManagement: false } }, partnerId: 'staff-partner' },
  ])('lets $user.role read and save preferences for its partner account', async ({ user, partnerId }) => {
    const dto = { bookingNotifications: false };
    const preferences = { ...dto, partnerId };
    const service = {
      getPreferences: jest.fn().mockResolvedValue(preferences),
      upsertPreferences: jest.fn().mockResolvedValue(preferences),
    };
    const controller = new NotificationPreferencesController(service as unknown as NotificationPreferencesService);

    expect(guard.canActivate(contextFor('getPreferences', user))).toBe(true);
    expect(guard.canActivate(contextFor('updatePreferences', user))).toBe(true);
    await expect(controller.getPreferences(user)).resolves.toMatchObject({ data: preferences });
    await expect(controller.updatePreferences(user, dto)).resolves.toMatchObject({ data: preferences });
    expect(service.getPreferences).toHaveBeenCalledWith(partnerId);
    expect(service.upsertPreferences).toHaveBeenCalledWith(partnerId, dto);
  });

  it.each([UserRole.ADMIN, UserRole.USER, undefined])('denies unrelated role %s', (role) => {
    const user = role ? { role } : undefined;
    for (const method of ['getPreferences', 'updatePreferences'] as const) {
      expect(() => guard.canActivate(contextFor(method, user))).toThrow(ForbiddenException);
    }
  });
});
