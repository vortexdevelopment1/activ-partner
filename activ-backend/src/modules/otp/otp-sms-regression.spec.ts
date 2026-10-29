import { OtpService } from './otp.service';
import { MailService } from '../mail/mail.service';

describe('MSG91 SMS remains independent of Gmail token storage', () => {
  beforeEach(() => (global.fetch as jest.Mock).mockClear());
  it('uses mocked MSG91 send, verify and resend endpoints with database Gmail mode configured', async () => {
    const settings = { GOOGLE_TOKEN_SOURCE: 'database', EMAIL_PROVIDER: 'gmail', MSG91_OTP_ENABLED: 'true', MSG91_AUTHKEY: 'synthetic-msg91-key', MSG91_OTP_TEMPLATE_ID: 'mock-sms-template' };
    const service = new OtpService({ get: key => settings[key] } as any);
    const fetchMock = global.fetch as jest.Mock;
    fetchMock.mockResolvedValue({ ok: true, json: async () => ({ type: 'success' }) });
    await service.sendOtp('+919999000001');
    expect(await service.verifyOtp('+919999000001', '1234')).toBe(true);
    await service.resendOtp('+919999000001');
    const calls = fetchMock.mock.calls;
    expect(calls.map(([url]) => new URL(url).hostname)).toEqual(['control.msg91.com', 'control.msg91.com', 'control.msg91.com']);
    expect(calls.map(([url]) => new URL(url).pathname)).toEqual(['/api/v5/otp', '/api/v5/otp/verify', '/api/v5/otp/retry']);
    expect(calls[0][1].headers.authkey).toBe('synthetic-msg91-key');
  });
  it('keeps team invitation SMS on MSG91 while Gmail email mode is selected', async () => {
    const settings = { EMAIL_PROVIDER: 'gmail', GOOGLE_TOKEN_SOURCE: 'database', MSG91_AUTHKEY: 'synthetic-msg91-key', MSG91_TEAM_INVITE_TEMPLATE_ID: 'mock-team-template' };
    const google = { sendEmail: jest.fn() };
    const service = new MailService({ get: (key, fallback) => settings[key] ?? fallback } as any, google as any);
    (global.fetch as jest.Mock).mockResolvedValue({ ok: true, json: async () => ({ type: 'success' }) });
    expect(await service.sendTeamMemberInviteSms({ phone: '+919999000001', fullName: 'Test Member', role: 'manager', password: 'synthetic-invite-password' })).toBe(true);
    expect(global.fetch).toHaveBeenCalledWith('https://control.msg91.com/api/v5/flow', expect.objectContaining({ method: 'POST' }));
    expect(google.sendEmail).not.toHaveBeenCalled();
  });
});
