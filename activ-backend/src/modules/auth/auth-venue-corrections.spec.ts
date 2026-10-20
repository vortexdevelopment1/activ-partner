import { ForbiddenException } from '@nestjs/common';
import { AuthService } from './auth.service';

describe('OTP access to venue corrections', () => {
  let service: AuthService;
  let prisma: any;
  let partner: any;
  beforeEach(() => {
    partner = { id: 'partner', status: 'PENDING' };
    prisma = {
      users: { findUnique: jest.fn(async () => ({ id: 'owner', partner_users: [{ partners: partner }] })) },
      venues: { findFirst: jest.fn().mockResolvedValue({ id: 'venue' }) },
      otp_challenges: { findFirst: jest.fn().mockResolvedValue(null), create: jest.fn() },
    };
    service = Object.assign(Object.create(AuthService.prototype), {
      prisma, otpService: { sendOtp: jest.fn() },
    });
  });
  it('allows a pending owner to request a login OTP only for an editable correction draft', async () => {
    await service.requestOtp({ phone: '+919876543210' }, 'login');
    expect(prisma.venues.findFirst).toHaveBeenCalledWith({ where: {
      partner_id: 'partner', status: 'DRAFT', submitted_at: null,
      review_status: 'pending', rejection_reason: { not: null },
    }, select: { id: true } });
    expect((service as any).otpService.sendOtp).toHaveBeenCalled();
  });
  it('continues blocking owners waiting for review', async () => {
    prisma.venues.findFirst.mockResolvedValue(null);
    await expect(service.requestOtp({ phone: '+919876543210' }, 'login')).rejects.toBeInstanceOf(ForbiddenException);
  });
  it('does not grant correction access to a suspended partner', async () => {
    partner.status = 'SUSPENDED';
    await expect(service.requestOtp({ phone: '+919876543210' }, 'login')).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.venues.findFirst).not.toHaveBeenCalled();
  });
  it('verifies the correction OTP and returns the existing account without creating another', async () => {
    const user = { id: 'owner', partner_users: [{ partners: partner }] };
    prisma.users.findUnique.mockResolvedValue(user);
    prisma.otp_challenges.findFirst.mockResolvedValue({ id: 'challenge' });
    const tx = {
      otp_challenges: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      users: { findUnique: jest.fn().mockResolvedValue(user), create: jest.fn() },
      partner_users: { findFirst: jest.fn().mockResolvedValue({ partners: partner, role: 'PARTNER_ADMIN' }), create: jest.fn() },
    };
    prisma.$transaction = jest.fn((callback) => callback(tx));
    Object.assign(service, {
      teamService: { findByPhone: jest.fn().mockResolvedValue(null) },
      otpService: { verifyOtp: jest.fn().mockResolvedValue(true) },
      buildPartnerAuthResponse: jest.fn().mockReturnValue({ jwt_token: 'correction-token' }),
    });
    await expect(service.verifyOtp({ phone: '+919876543210', otp: '1234' }, 'login')).resolves.toEqual({ jwt_token: 'correction-token' });
    expect(tx.users.create).not.toHaveBeenCalled();
    expect(tx.partner_users.create).not.toHaveBeenCalled();
  });
});
