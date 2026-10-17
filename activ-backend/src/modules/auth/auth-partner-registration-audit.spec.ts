import { AuthService } from './auth.service';

describe('partner registration audit', () => {
  it('records a new OTP partner account in the signup transaction', async () => {
    const user = { id: 'owner-id', phone_e164: '+919876543210' };
    const link = { role: 'PARTNER_ADMIN', partners: { id: 'partner-id' } };
    const tx: any = {
      otp_challenges: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      users: { findUnique: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue(user) },
      partner_users: { findFirst: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue(link) },
      partners: { create: jest.fn().mockResolvedValue({}) },
      audit_events: { create: jest.fn().mockResolvedValue({}) },
    };
    const prisma = {
      otp_challenges: { findFirst: jest.fn().mockResolvedValue({ id: 'challenge', expires_at: new Date(Date.now() + 60000) }) },
      $transaction: jest.fn((callback) => callback(tx)),
    };
    const service = Object.assign(Object.create(AuthService.prototype), {
      prisma, teamService: { findByPhone: jest.fn().mockResolvedValue(null) },
      otpService: { verifyOtp: jest.fn().mockResolvedValue(true) },
      buildPartnerAuthResponse: jest.fn().mockReturnValue({ jwt_token: 'token' }),
    }) as AuthService;

    await service.verifyOtp({ phone: '+919876543210', otp: '123456' });
    expect(tx.audit_events.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      actor_id: user.id, action: 'partner.registered', entity_type: 'partners',
      entity_id: expect.any(String), after_json: { outcome: 'success' },
    }) });
  });
});
