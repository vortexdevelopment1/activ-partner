import * as bcrypt from 'bcryptjs';
import { AuthService } from './auth.service';

describe('partner password recovery on the current Prisma schema', () => {
  let user: any;
  let challenge: any;
  let prisma: any;
  let mail: any;
  let legacy: any;
  let service: AuthService;

  beforeEach(async () => {
    user = { id: 'user-1', email: 'partner@example.com', name: 'Test Partner', password_hash: 'old-hash' };
    challenge = { id: 'challenge-1', phone_e164: 'password-reset:user-1',
      code_hash: await bcrypt.hash('1234', 4), attempts: 0, consumed_at: null,
      created_at: new Date(), expires_at: new Date(Date.now() + 600000) };
    prisma = {
      users: { findFirst: jest.fn().mockResolvedValue(user), update: jest.fn().mockResolvedValue(user) },
      otp_challenges: {
        findFirst: jest.fn().mockImplementation(async () => challenge),
        create: jest.fn().mockImplementation(async ({ data }) => {
          challenge = { ...data, created_at: new Date(), consumed_at: null, attempts: 0 };
          return challenge;
        }),
        updateMany: jest.fn().mockImplementation(async ({ data }) => {
          if (data.attempts) { challenge.attempts++; return { count: 1 }; }
          if (challenge.consumed_at) return { count: 0 };
          challenge.consumed_at = data.consumed_at;
          return { count: 1 };
        }),
        delete: jest.fn().mockResolvedValue({}),
      },
    };
    prisma.$transaction = jest.fn().mockImplementation((callback) => callback(prisma));
    mail = { sendPasswordResetEmail: jest.fn().mockResolvedValue(true) };
    legacy = { findOne: jest.fn(), save: jest.fn() };
    service = Object.assign(Object.create(AuthService.prototype), {
      prisma, partnerRepository: legacy, mailService: mail,
    });
  });

  afterEach(() => {
    expect(legacy.findOne).not.toHaveBeenCalled();
    expect(legacy.save).not.toHaveBeenCalled();
  });

  it('sends a hashed challenge for the user account with a case-insensitive email lookup', async () => {
    challenge = null;
    await service.forgotPassword({ email: ' Partner@Example.com ' });
    expect(prisma.users.findFirst).toHaveBeenCalledWith({
      where: { email: { equals: 'Partner@Example.com', mode: 'insensitive' }, partner_users: { some: {} } },
    });
    const code = mail.sendPasswordResetEmail.mock.calls[0][0].code;
    expect(code).toMatch(/^\d{4}$/);
    expect(challenge.phone_e164).toBe('password-reset:user-1');
    expect(await bcrypt.compare(code, challenge.code_hash)).toBe(true);
    expect(challenge.code_hash).not.toBe(code);
  });

  it('returns generic success without email delivery for an unknown account', async () => {
    prisma.users.findFirst.mockResolvedValue(null);
    await expect(service.forgotPassword({ email: 'unknown@example.com' })).resolves.toHaveProperty('message');
    expect(mail.sendPasswordResetEmail).not.toHaveBeenCalled();
    expect(prisma.otp_challenges.create).not.toHaveBeenCalled();
  });

  it('verifies a code without consuming it or changing the password', async () => {
    await expect(service.verifyPasswordResetCode({ email: user.email, code: '1234' }))
      .resolves.toEqual({ message: 'Reset code verified successfully' });
    expect(challenge.consumed_at).toBeNull();
    expect(prisma.users.update).not.toHaveBeenCalled();
  });

  it.each(['incorrect', 'expired', 'missing', 'consumed', 'locked'])('rejects %s codes', async (kind) => {
    if (kind === 'expired') challenge.expires_at = new Date(Date.now() - 1);
    if (kind === 'missing') prisma.users.findFirst.mockResolvedValue(null);
    if (kind === 'consumed') challenge.consumed_at = new Date();
    if (kind === 'locked') challenge.attempts = 5;
    await expect(service.verifyPasswordResetCode({ email: user.email, code: kind === 'incorrect' ? '9999' : '1234' }))
      .rejects.toThrow('Invalid or expired reset code.');
    expect(prisma.users.update).not.toHaveBeenCalled();
    if (kind === 'incorrect') expect(challenge.attempts).toBe(1);
  });

  it('rechecks expiry when the password is submitted', async () => {
    await service.verifyPasswordResetCode({ email: user.email, code: '1234' });
    challenge.expires_at = new Date(Date.now() - 1);
    await expect(service.resetPassword({ email: user.email, code: '1234', newPassword: 'new-password' }))
      .rejects.toThrow('Invalid or expired reset code.');
  });

  it('updates the login password hash and consumes the code atomically', async () => {
    await service.resetPassword({ email: user.email, code: '1234', newPassword: 'new-password' });
    const update = prisma.users.update.mock.calls[0][0];
    expect(update.where).toEqual({ id: user.id });
    expect(await bcrypt.compare('new-password', update.data.password_hash)).toBe(true);
    expect(prisma.$transaction).toHaveBeenCalled();
    expect(challenge.consumed_at).toBeInstanceOf(Date);
    await expect(service.resetPassword({ email: user.email, code: '1234', newPassword: 'another-password' }))
      .rejects.toThrow('Invalid or expired reset code.');
  });

  it('does not change the password if another request consumed the code', async () => {
    prisma.otp_challenges.updateMany.mockResolvedValue({ count: 0 });
    await expect(service.resetPassword({ email: user.email, code: '1234', newPassword: 'new-password' }))
      .rejects.toThrow('Invalid or expired reset code.');
    expect(prisma.users.update).not.toHaveBeenCalled();
  });

  it('blocks immediate resends and allows resending after sixty seconds', async () => {
    await expect(service.forgotPassword({ email: user.email })).rejects.toThrow('Please wait');
    challenge.created_at = new Date(Date.now() - 61000);
    await service.forgotPassword({ email: user.email });
    expect(mail.sendPasswordResetEmail).toHaveBeenCalledWith(expect.objectContaining({ toEmail: user.email }));
  });

  it('removes the challenge after delivery fails so a retry is possible', async () => {
    challenge = null;
    mail.sendPasswordResetEmail.mockRejectedValue(new Error('Email delivery failed'));
    await expect(service.forgotPassword({ email: user.email })).rejects.toThrow('Email delivery failed');
    expect(prisma.otp_challenges.delete).toHaveBeenCalledWith({ where: { id: challenge.id } });
  });

  it('reports a provider rejection instead of falsely reporting email success', async () => {
    challenge = null;
    mail.sendPasswordResetEmail.mockResolvedValue(false);
    await expect(service.forgotPassword({ email: user.email })).rejects.toThrow('Unable to send the reset email.');
    expect(prisma.otp_challenges.delete).toHaveBeenCalledWith({ where: { id: challenge.id } });
  });
});
