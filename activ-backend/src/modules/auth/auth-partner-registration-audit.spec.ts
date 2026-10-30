import { AuthService } from './auth.service';

describe('partner registration audit', () => {
  it('does not send signup alerts when account creation rolls back', async () => {
    const notify = jest.fn();
    const service = Object.assign(Object.create(AuthService.prototype), {
      prisma: {
        otp_challenges: { findFirst: jest.fn().mockResolvedValue({ id: 'challenge' }) },
        $transaction: jest.fn().mockRejectedValue(new Error('Signup failed')),
      },
      teamService: { findByPhone: jest.fn().mockResolvedValue(null) },
      otpService: { verifyOtp: jest.fn().mockResolvedValue(true) },
      adminNotificationsService: { notify },
    }) as AuthService;
    await expect(service.verifyOtp({ phone: '+919876543210', otp: '123456' })).rejects.toThrow('Signup failed');
    expect(notify).not.toHaveBeenCalled();
  });
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
      adminNotificationsService: { notify: jest.fn().mockResolvedValue(undefined) },
      otpService: { verifyOtp: jest.fn().mockResolvedValue(true) },
      buildPartnerAuthResponse: jest.fn().mockReturnValue({ jwt_token: 'token' }),
    }) as AuthService;

    await expect(service.verifyOtp({ phone: '+919876543210', otp: '123456' }))
      .resolves.toMatchObject({ isNewPartner: true });
    expect(tx.audit_events.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      actor_id: user.id, action: 'partner.registered', entity_type: 'partners',
      entity_id: expect.any(String), after_json: { outcome: 'success' },
    }) });
    expect(tx.partner_users.findFirst).toHaveBeenCalledWith(expect.objectContaining({
      where: { user_id: user.id, role: 'PARTNER_ADMIN' },
    }));
    expect((service as any).adminNotificationsService.notify).toHaveBeenCalledWith(
      'partner_registered', expect.any(String), expect.any(String), { partnerId: 'partner-id' },
    );

    // Signing into the same account must not create another registration alert.
    tx.partner_users.findFirst.mockResolvedValue(link);
    (service as any).adminNotificationsService.notify.mockClear();
    await service.verifyOtp({ phone: '+919876543210', otp: '123456' });
    expect((service as any).adminNotificationsService.notify).not.toHaveBeenCalled();
  });
});
