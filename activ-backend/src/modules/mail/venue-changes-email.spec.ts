import { ConfigService } from '@nestjs/config';
import { MailService } from './mail.service';

describe('venue corrections email', () => {
  const originalFetch = global.fetch;
  afterEach(() => { global.fetch = originalFetch; });
  const params = { toEmail: 'owner@example.com', venueName: 'Arena', reason: 'Fix photos' };
  it('uses the changes template and supplies the saved reason and resubmission instructions', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ status: 'success' }) });
    const service = new MailService(new ConfigService({ MSG91_AUTHKEY: 'test-key', MSG91_VENUE_CHANGES_TEMPLATE_ID: 'changes-template' }));
    await expect(service.sendVenueChangesRequestedEmail(params)).resolves.toBe(true);
    const body = JSON.parse((global.fetch as jest.Mock).mock.calls[0][1].body);
    expect(body).toMatchObject({ template_id: 'changes-template', recipients: [{ variables: {
      venueName: 'Arena', reason: 'Fix photos', instructions: expect.stringContaining('submit again'),
    } }] });
  });
  it('does not send a misleading rejection email when the changes template is missing', async () => {
    global.fetch = jest.fn();
    const service = new MailService(new ConfigService({}));
    await expect(service.sendVenueChangesRequestedEmail(params)).resolves.toBe(false);
    expect(global.fetch).not.toHaveBeenCalled();
  });
  it('keeps the editing flow available when the email provider fails', async () => {
    global.fetch = jest.fn().mockRejectedValue(new Error('Provider unavailable'));
    const service = new MailService(new ConfigService({ MSG91_AUTHKEY: 'test-key', MSG91_VENUE_CHANGES_TEMPLATE_ID: 'changes-template' }));
    await expect(service.sendVenueChangesRequestedEmail(params)).resolves.toBe(false);
  });
});
