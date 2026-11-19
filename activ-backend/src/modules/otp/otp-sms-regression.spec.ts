import { OtpService } from './otp.service';
import { MailService } from '../mail/mail.service';

describe('MSG91 SMS remains independent of Gmail token storage', () => {
  beforeEach(() => (global.fetch as jest.Mock).mockClear());
  it('uses mocked MSG91 send, verify and resend endpoints with database Gmail mode configured', async () => {
    const settings = { GOOGLE_TOKEN_SOURCE: 'database', EMAIL_PROVIDER: 'gmail', MSG91_OTP_ENABLED: 'true', MSG91_AUTHKEY: 'synthetic-msg91-key', MSG91_OTP_TEMPLATE_ID: 'aaaaaaaaaaaaaaaaaaaaaaaa' };
    const service = new OtpService({ get: key => settings[key] } as any);
    const fetchMock = global.fetch as jest.Mock;
    fetchMock.mockResolvedValue({ ok: true, json: async () => ({ type: 'success', request_id: 'mock-otp-request' }) });
    await service.sendOtp('+919999000001');
    expect(await service.verifyOtp('+919999000001', '1234')).toBe(true);
    await service.resendOtp('+919999000001');
    const calls = fetchMock.mock.calls;
    expect(calls.map(([url]) => new URL(url).hostname)).toEqual(['control.msg91.com', 'control.msg91.com', 'control.msg91.com']);
    expect(calls.map(([url]) => new URL(url).pathname)).toEqual(['/api/v5/otp', '/api/v5/otp/verify', '/api/v5/otp/retry']);
    expect(calls[0][1].headers.authkey).toBe('synthetic-msg91-key');
    expect(new URL(calls[0][0]).searchParams.get('otp_length')).toBe('4');
    expect(new URL(calls[0][0]).searchParams.get('otp_expiry')).toBe('10');
    expect(calls[2][1].method).toBe('GET');
  });
  it('keeps team invitation SMS on MSG91 while Gmail email mode is selected', async () => {
    const settings = { EMAIL_PROVIDER: 'gmail', GOOGLE_TOKEN_SOURCE: 'database', MSG91_AUTHKEY: 'synthetic-msg91-key', MSG91_TEAM_INVITE_TEMPLATE_ID: '6afdeef436aedc84d2040fc4' };
    const google = { sendEmail: jest.fn() };
    const service = new MailService({ get: (key, fallback) => settings[key] ?? fallback } as any, google as any);
    const log = jest.spyOn((service as any).logger, 'log');
    (global.fetch as jest.Mock).mockResolvedValue({ ok: true, json: async () => ({ type: 'success', message: 'aaaaaaaaaaaaaaaaaaaaaaaa' }) });
    expect(await service.sendTeamMemberInviteSms({ phone: '+919999000001', fullName: 'Test Member', role: 'manager', password: 'synthetic-invite-password' })).toBe(true);
    expect(global.fetch).toHaveBeenCalledWith('https://control.msg91.com/api/v5/flow', expect.objectContaining({ method: 'POST' }));
    expect(google.sendEmail).not.toHaveBeenCalled();
    expect(log).toHaveBeenCalledWith('Team invite SMS accepted by MSG91 (request ID: aaaaaaaaaaaaaaaaaaaaaaaa); delivery is not yet confirmed');
    log.mockRestore();
    expect(JSON.parse((global.fetch as jest.Mock).mock.calls[0][1].body)).toEqual({
      template_id: settings.MSG91_TEAM_INVITE_TEMPLATE_ID, short_url: '0',
      recipients: [{ mobiles: '919999000001', var1: '9999000001', var2: 'synthetic-invite-password' }],
    });
  });
});
