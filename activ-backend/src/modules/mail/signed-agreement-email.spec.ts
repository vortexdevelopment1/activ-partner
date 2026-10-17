import { MailService } from './mail.service';

describe('signed agreement email via MSG91', () => {
  const originalFetch = global.fetch;
  const params = { toEmail: 'registered@example.com', partnerName: 'Lalit Jangid',
    venueName: 'Spartna Club', signedAt: new Date('2026-10-16T10:00:00Z'),
    agreement: { base64: 'JVBERg==', filename: 'signed.pdf', mimeType: 'application/pdf' } };
  let config: Record<string, string>;
  let service: MailService;
  beforeEach(() => {
    config = { MSG91_AUTHKEY: 'test-key', MSG91_AGREEMENT_TEMPLATE_ID: 'signedagreement', MSG91_DOMAIN: 'mail.activ.co.in' };
    service = Object.assign(Object.create(MailService.prototype), {
      configService: { get: (key: string, fallback?: string) => config[key] ?? fallback },
    });
    global.fetch = jest.fn().mockResolvedValue({ ok: true, status: 200, json: async () => ({ status: 'success' }) });
  });
  afterEach(() => { global.fetch = originalFetch; });
  it('uses MSG91, the saved partner email and a base64 PDF attachment', async () => {
    await service.sendSignedPartnerAgreementEmail(params);
    const [url, options] = (global.fetch as jest.Mock).mock.calls[0];
    expect(url).toBe('https://control.msg91.com/api/v5/email/send');
    expect(options.headers.authkey).toBe('test-key');
    expect(JSON.parse(options.body)).toMatchObject({
      from: { name: 'ACTIV Partner', email: 'no-reply@activ.co.in' },
      domain: 'mail.activ.co.in', template_id: 'signedagreement',
      reply_to: [{ email: 'support@activ.live' }],
      recipients: [{ to: [{ email: params.toEmail, name: params.partnerName }],
        variables: { partnerName: 'Lalit Jangid', venueName: 'Spartna Club', signedAt: expect.stringContaining('(IST)') } }],
      attachments: [{ fileName: 'signed.pdf', file: 'data:application/pdf;base64,JVBERg==' }],
    });
  });
  it('requires the actual template ID', async () => {
    delete config.MSG91_AGREEMENT_TEMPLATE_ID;
    await expect(service.sendSignedPartnerAgreementEmail(params)).rejects.toMatchObject({ code: 'MSG91_CONFIG' });
    expect(global.fetch).not.toHaveBeenCalled();
  });
  it.each([
    { ok: false, status: 401, body: { message: 'private error' } },
    { ok: true, status: 200, body: { status: 'fail' } },
    { ok: true, status: 200, body: { success: false } },
  ])('rejects unsuccessful provider responses', async ({ ok, status, body }) => {
    (global.fetch as jest.Mock).mockResolvedValue({ ok, status, json: async () => body });
    await expect(service.sendSignedPartnerAgreementEmail(params)).rejects.toMatchObject({ code: 'MSG91_SEND', responseCode: status });
  });
});
