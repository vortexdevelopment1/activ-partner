import { AuthService } from './auth.service';
import { PHONE_OTP_MAX_ATTEMPTS } from '../../config/msg91';

describe('phone OTP challenge lifecycle', () => {
  const phone = '+919876543210';
  let service: AuthService;
  let prisma: any;
  let provider: any;
  let challenge: any;
  beforeEach(() => {
    challenge = { id: 'challenge', phone_e164: phone, attempts: 0, consumed_at: null,
      created_at: new Date(Date.now() - 61_000), expires_at: new Date(Date.now() + 120_000) };
    prisma = { otp_challenges: {
      findFirst: jest.fn().mockImplementation(async () => ({ ...challenge })),
      create: jest.fn(),
      updateMany: jest.fn().mockImplementation(async ({ where, data }) => {
        if (challenge.consumed_at || challenge.expires_at <= new Date() ||
          (where.attempts && challenge.attempts >= where.attempts.lt)) return { count: 0 };
        if (data.attempts) challenge.attempts++;
        if (data.consumed_at) challenge.consumed_at = data.consumed_at;
        if (data.created_at) challenge.created_at = data.created_at;
        return { count: 1 };
      }),
    }, users: { findUnique: jest.fn().mockResolvedValue(null) }, $executeRaw: jest.fn() };
    prisma.$transaction = jest.fn(callback => callback(prisma));
    provider = { sendOtp: jest.fn(), resendOtp: jest.fn(), verifyOtp: jest.fn().mockResolvedValue(true) };
    service = Object.assign(Object.create(AuthService.prototype), { prisma, otpService: provider,
      teamService: { findByPhone: jest.fn().mockResolvedValue({ id: 'staff', isActive: true }) },
      completeTeamMemberLogin: jest.fn().mockResolvedValue({ userType: 'team_member' }) });
  });
  it('consumes the previous challenge before saving a newly issued OTP', async () => {
    await service.requestOtp({ phone });
    expect(provider.sendOtp).toHaveBeenCalledWith(phone);
    expect(prisma.$executeRaw).toHaveBeenCalled();
    expect(prisma.otp_challenges.updateMany).toHaveBeenCalledWith({
      where: { phone_e164: phone, consumed_at: null }, data: { consumed_at: expect.any(Date) },
    });
    expect(prisma.otp_challenges.create.mock.calls[0][0].data.expires_at.getTime() -
      prisma.otp_challenges.updateMany.mock.calls[0][0].data.consumed_at.getTime()).toBe(600_000);
  });
  it('preserves a valid challenge when send fails', async () => {
    provider.sendOtp.mockRejectedValue(new Error('provider offline'));
    await expect(service.requestOtp({ phone })).rejects.toThrow('provider offline');
    expect(prisma.otp_challenges.updateMany).not.toHaveBeenCalled();
    expect(prisma.otp_challenges.create).not.toHaveBeenCalled();
  });
  it.each(['request', 'resend'])('enforces the 60-second %s cooldown', async operation => {
    challenge.created_at = new Date();
    await expect(operation === 'request' ? service.requestOtp({ phone }) : service.resendOtp({ phone })).rejects.toThrow('60 seconds');
    expect(provider.sendOtp).not.toHaveBeenCalled();
    expect(provider.resendOtp).not.toHaveBeenCalled();
  });
  it('resends the same challenge without extending expiry or resetting attempts', async () => {
    const expiry = challenge.expires_at;
    challenge.attempts = 3;
    await service.resendOtp({ phone });
    expect(provider.resendOtp).toHaveBeenCalledWith(phone);
    expect(prisma.otp_challenges.create).not.toHaveBeenCalled();
    expect(challenge).toMatchObject({ id: 'challenge', attempts: 3, expires_at: expiry });
    expect(prisma.otp_challenges.updateMany.mock.calls[0][0].data).toEqual({ created_at: expect.any(Date) });
  });
  it.each(['consumed', 'expired', 'exhausted'])('rejects %s challenges for retry and verification', async state => {
    if (state === 'consumed') challenge.consumed_at = new Date();
    if (state === 'expired') challenge.expires_at = new Date(Date.now() - 1);
    if (state === 'exhausted') challenge.attempts = PHONE_OTP_MAX_ATTEMPTS;
    await expect(service.resendOtp({ phone })).rejects.toThrow('Invalid or expired');
    await expect(service.verifyOtp({ phone, otp: '1234' })).rejects.toThrow('Invalid or expired');
    expect(provider.verifyOtp).not.toHaveBeenCalled();
    expect(provider.resendOtp).not.toHaveBeenCalled();
  });
  it('charges wrong guesses and blocks verification after five attempts', async () => {
    provider.verifyOtp.mockResolvedValue(false);
    for (let i = 0; i < PHONE_OTP_MAX_ATTEMPTS + 1; i++) {
      await expect(service.verifyOtp({ phone, otp: '0000' })).rejects.toThrow('Invalid or expired');
    }
    expect(provider.verifyOtp).toHaveBeenCalledTimes(PHONE_OTP_MAX_ATTEMPTS);
    expect(challenge.attempts).toBe(PHONE_OTP_MAX_ATTEMPTS);
  });
  it('atomically reserves only the remaining attempt for concurrent guesses', async () => {
    challenge.attempts = PHONE_OTP_MAX_ATTEMPTS - 1;
    provider.verifyOtp.mockResolvedValue(false);
    await Promise.allSettled([service.verifyOtp({ phone, otp: '0000' }), service.verifyOtp({ phone, otp: '0000' })]);
    expect(provider.verifyOtp).toHaveBeenCalledTimes(1);
  });
  it('consumes a verified challenge exactly once', async () => {
    await expect(service.verifyOtp({ phone, otp: '1234' })).resolves.toEqual({ userType: 'team_member' });
    await expect(service.verifyOtp({ phone, otp: '1234' })).rejects.toThrow('Invalid or expired');
    expect((service as any).completeTeamMemberLogin).toHaveBeenCalledTimes(1);
  });
  it('does not complete login if a new send invalidates the challenge during provider verification', async () => {
    provider.verifyOtp.mockImplementation(async () => { challenge.consumed_at = new Date(); return true; });
    await expect(service.verifyOtp({ phone, otp: '1234' })).rejects.toThrow('Invalid or expired');
    expect((service as any).completeTeamMemberLogin).not.toHaveBeenCalled();
  });
});
