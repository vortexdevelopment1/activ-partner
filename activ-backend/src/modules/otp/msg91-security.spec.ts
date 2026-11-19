import { OtpService } from './otp.service';
import { MailService } from '../mail/mail.service';
import { Logger } from '@nestjs/common';
import { MSG91_TIMEOUT_MS } from '../../config/msg91';

describe('MSG91 provider boundaries', () => {
  let settings: Record<string, string>;
  let otp: OtpService;
  let mail: MailService;
  const invite = { phone: '+919876543210', fullName: 'Test Member', role: 'manager', password: 'synthetic-password' };
  const response = (body: unknown, ok = true) => ({ ok, status: ok ? 200 : 401, json: async () => body });
  beforeEach(() => {
    (global.fetch as jest.Mock).mockReset();
    settings = { NODE_ENV: 'production', MSG91_OTP_ENABLED: 'true', MSG91_AUTHKEY: 'synthetic-key',
      MSG91_OTP_TEMPLATE_ID: 'aaaaaaaaaaaaaaaaaaaaaaaa', MSG91_TEAM_INVITE_TEMPLATE_ID: '6afdeef436aedc84d2040fc4' };
    const config = { get: (key, fallback) => settings[key] ?? fallback };
    otp = new OtpService(config as any);
    mail = new MailService(config as any, {} as any);
  });

  it.each(['NODE_ENV', 'APP_ENV'])('rejects mock OTP in production via %s', async env => {
    settings.NODE_ENV = 'test'; settings[env] = 'production'; settings.MSG91_OTP_ENABLED = 'false';
    expect(() => otp.onModuleInit()).toThrow('MSG91_OTP_ENABLED=true');
    await expect(otp.verifyOtp(invite.phone, '3210')).rejects.toThrow();
    await expect(otp.sendOtp(invite.phone)).rejects.toThrow();
    await expect(otp.resendOtp(invite.phone)).rejects.toThrow();
    expect(fetch).not.toHaveBeenCalled();
  });
  it.each(['MSG91_AUTHKEY', 'MSG91_OTP_TEMPLATE_ID', 'MSG91_TEAM_INVITE_TEMPLATE_ID'])('rejects missing production %s at startup', key => {
    delete settings[key];
    expect(() => otp.onModuleInit()).toThrow();
  });
  it('keeps explicit non-production mock mode offline', async () => {
    settings.NODE_ENV = 'development'; settings.MSG91_OTP_ENABLED = 'false';
    otp.onModuleInit();
    await otp.sendOtp(invite.phone);
    await otp.resendOtp(invite.phone);
    expect(await otp.verifyOtp(invite.phone, '3210')).toBe(true);
    expect(await otp.verifyOtp(invite.phone, '0000')).toBe(false);
    expect(fetch).not.toHaveBeenCalled();
  });
  it.each([
    response({ type: 'error', message: 'Mobile already verified' }),
    response({ type: 'success' }, false), response({}), response(null),
    { ok: true, json: async () => { throw new Error('not json'); } },
  ])('rejects ambiguous, HTTP failure and malformed OTP verdicts %#', async res => {
    (fetch as jest.Mock).mockResolvedValue(res);
    expect(await otp.verifyOtp(invite.phone, '1234')).toBe(false);
  });
  it('rejects non-four-digit OTP without contacting MSG91', async () => {
    expect(await otp.verifyOtp(invite.phone, '123456')).toBe(false);
    expect(fetch).not.toHaveBeenCalled();
  });
  it('requires the send request ID', async () => {
    (fetch as jest.Mock).mockResolvedValue(response({ type: 'success' }));
    await expect(otp.sendOtp(invite.phone)).rejects.toThrow('Failed to send OTP');
  });
  it.each(['9876543210', '919876543210', '+91 98765-43210'])('formats invitation mobile %s', async phone => {
    (fetch as jest.Mock).mockResolvedValue(response({ type: 'success', message: 'bbbbbbbbbbbbbbbbbbbbbbbb' }));
    expect(await mail.sendTeamMemberInviteSms({ ...invite, phone })).toBe(true);
    const body = JSON.parse((fetch as jest.Mock).mock.calls[0][1].body);
    expect(body.recipients).toEqual([{ mobiles: '919876543210', var1: '9876543210', var2: invite.password }]);
  });
  it.each(['+14155552671', '1234567890', 'abc9876543210', ''])('does not send to invalid/non-Indian mobile %s', async phone => {
    expect(await mail.sendTeamMemberInviteSms({ ...invite, phone })).toBe(false);
    expect(fetch).not.toHaveBeenCalled();
  });
  it('does not send the password template without a generated password', async () => {
    expect(await mail.sendTeamMemberInviteSms({ ...invite, password: undefined })).toBe(false);
    expect(fetch).not.toHaveBeenCalled();
  });
  it.each(['MSG91_AUTHKEY', 'MSG91_TEAM_INVITE_TEMPLATE_ID'])('does not send with missing %s', async key => {
    delete settings[key];
    expect(await mail.sendTeamMemberInviteSms(invite)).toBe(false);
    expect(fetch).not.toHaveBeenCalled();
  });
  it('rejects a malformed template ID before fetching', async () => {
    settings.MSG91_TEAM_INVITE_TEMPLATE_ID = 'bad-id';
    expect(await mail.sendTeamMemberInviteSms(invite)).toBe(false);
    expect(fetch).not.toHaveBeenCalled();
  });
  it.each([
    response({ type: 'success', message: 'bbbbbbbbbbbbbbbbbbbbbbbb' }, false),
    response({ type: 'error' }), response({}), response(null),
    response({ type: 'success' }), response({ type: 'success', message: 'not-a-request-id' }),
    { ok: true, json: async () => { throw new Error('malformed'); } },
  ])('rejects invalid invitation acceptance %#', async res => {
    (fetch as jest.Mock).mockResolvedValue(res);
    expect(await mail.sendTeamMemberInviteSms(invite)).toBe(false);
  });
  it('handles provider network errors without leaking credentials or phone numbers', async () => {
    const warn = jest.spyOn(Logger.prototype, 'warn').mockImplementation();
    const error = jest.spyOn(Logger.prototype, 'error').mockImplementation();
    (fetch as jest.Mock).mockRejectedValue(new Error(`offline ${invite.phone} ${invite.password} synthetic-key`));
    try {
      expect(await otp.verifyOtp(invite.phone, '1234')).toBe(false);
      expect(await mail.sendTeamMemberInviteSms(invite)).toBe(false);
      expect(JSON.stringify([...warn.mock.calls, ...error.mock.calls])).not.toMatch(/9876543210|synthetic-password|synthetic-key/);
    } finally { warn.mockRestore(); error.mockRestore(); }
  });
  it('aborts both SMS and OTP requests at the configured timeout', async () => {
    jest.useFakeTimers();
    // Fake timers do not drive Node native AbortSignal.timeout; supply its timer here.
    const timeout = jest.spyOn(AbortSignal, 'timeout').mockImplementation(ms => {
      const controller = new AbortController();
      setTimeout(() => controller.abort(), ms);
      return controller.signal;
    });
    (fetch as jest.Mock).mockImplementation((_, options) => new Promise((_, reject) => {
      options.signal.addEventListener('abort', () => reject(new Error('timeout')), { once: true });
    }));
    try {
      const results = Promise.all([mail.sendTeamMemberInviteSms(invite), otp.verifyOtp(invite.phone, '1234')]);
      await jest.advanceTimersByTimeAsync(MSG91_TIMEOUT_MS);
      expect(await results).toEqual([false, false]);
      expect(timeout).toHaveBeenCalledWith(MSG91_TIMEOUT_MS);
    } finally { timeout.mockRestore(); jest.useRealTimers(); }
  });
});
