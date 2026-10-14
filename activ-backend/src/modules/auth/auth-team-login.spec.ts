import { UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';

describe('current-schema staff OTP login', () => {
  let service: AuthService;
  let teamService: any;
  let prisma: any;
  let jwtService: any;
  beforeEach(() => {
    teamService = { findByPhone: jest.fn().mockResolvedValue({ id: 'staff-1', partnerId: 'partner-1',
      isActive: true, role: 'staff', permissions: { bookingManagement: true, pricingControl: false } }), markActive: jest.fn() };
    prisma = { otp_challenges: { findFirst: jest.fn().mockResolvedValue({ id: 'otp' }), update: jest.fn() },
      users: { findUnique: jest.fn().mockResolvedValue({ id: 'user-1' }) },
      partner_users: { findFirst: jest.fn().mockResolvedValue({ role: 'PARTNER_USER', partners: { id: 'partner-1' } }) },
      venues: { findFirst: jest.fn().mockResolvedValue({ id: 'venue-1', name: 'Arena' }) } };
    prisma.$transaction = jest.fn((callback) => callback(prisma));
    jwtService = { sign: jest.fn().mockReturnValue('staff-token') };
    service = Object.assign(Object.create(AuthService.prototype), { prisma, teamService, jwtService,
      otpService: { verifyOtp: jest.fn().mockResolvedValue(true) }, configService: { get: jest.fn() } });
  });
  it('returns staff permissions, never a partner token, for an invited team member', async () => {
    const result = await service.verifyOtp({ phone: '+919876543210', otp: '123456' });
    expect(result).toMatchObject({ userType: 'team_member', jwt_token: 'staff-token' });
    expect(jwtService.sign.mock.calls[0][0]).toMatchObject({ sub: 'staff-1', type: 'team_member', role: 'team_member', partnerId: 'partner-1' });
    expect(teamService.markActive).toHaveBeenCalledWith('staff-1');
  });
  it('does not issue a token for deactivated staff', async () => {
    teamService.findByPhone.mockResolvedValue({ isActive: false });
    await expect(service.verifyOtp({ phone: '+919876543210', otp: '123456' })).rejects.toBeInstanceOf(UnauthorizedException);
    expect(jwtService.sign).not.toHaveBeenCalled();
  });
});
