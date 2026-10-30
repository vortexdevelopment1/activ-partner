import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtStrategy } from './strategies/jwt.strategy';
import { AuthController } from './auth.controller';

describe('team session authorization', () => {
  const row = () => ({ id: 'staff', permissions: { bookingManagement: true },
    partner_users: { role: 'PARTNER_USER', user_id: 'member-user', partner_id: 'owner',
      users: { status: 'ACTIVE' }, partners: { status: 'ACTIVE' } } });
  let current: ReturnType<typeof row>;
  let strategy: JwtStrategy;
  beforeEach(() => {
    current = row();
    strategy = new JwtStrategy(new ConfigService({ JWT_SECRET: 'test-only-team-secret' }), {} as any,
      { partner_staff_profiles: { findUnique: jest.fn(async () => current) } } as any);
  });
  it('reads current database permissions on each authenticated request', async () => {
    expect((await strategy.validate({ sub: 'staff', role: 'team_member', type: 'team_member' })).permissions.bookingManagement).toBe(true);
    current.permissions.bookingManagement = false;
    expect((await strategy.validate({ sub: 'staff', role: 'team_member', type: 'team_member' })).permissions.bookingManagement).toBe(false);
  });
  it.each(['PENDING', 'SUSPENDED'])('blocks team access while the partner is %s', async status => {
    current.partner_users.partners.status = status;
    await expect(strategy.validate({ sub: 'staff', role: 'team_member', type: 'team_member' })).rejects.toBeInstanceOf(UnauthorizedException);
  });
  it('revokes access immediately when the staff record is removed', async () => {
    current = null;
    await expect(strategy.validate({ sub: 'staff', role: 'team_member', type: 'team_member' })).rejects.toBeInstanceOf(UnauthorizedException);
  });
  it('changes the password for the authenticated member under its actual partner', async () => {
    const service = { changePartnerPassword: jest.fn().mockResolvedValue({}) };
    const controller = new AuthController(service as any, {} as any);
    const dto = { currentPassword: 'old-password', newPassword: 'new-password' };
    await controller.changePartnerPassword({ id: 'staff', userId: 'member-user', partnerId: 'owner', role: 'team_member' }, dto);
    expect(service.changePartnerPassword).toHaveBeenCalledWith('owner', dto, 'member-user');
  });
});
