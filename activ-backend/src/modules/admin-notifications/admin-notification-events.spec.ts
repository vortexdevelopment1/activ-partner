import { PartnersService } from '../partners/partners.service';
import { VenuesService } from '../venues/venues.service';
import { SupportService } from '../support/support.service';
import { AuthService } from '../auth/auth.service';
import { BadRequestException } from '@nestjs/common';

describe('admin notification event producers', () => {
  let notify: jest.Mock;
  beforeEach(() => { notify = jest.fn().mockResolvedValue(undefined); });
  const service = <T extends object>(prototype: T, dependencies: object) => Object.assign(Object.create(prototype), dependencies);

  it('links saved GST submissions to their review record without including documents in the alert', async () => {
    const create = jest.fn().mockResolvedValue({ id: 'gst-id', partner_id: 'partner', gst_number: 'test-gst', legal_name: 'Test', status: 'PENDING', document_url: null, rejection_reason: null, created_at: new Date(), updated_at: new Date() });
    const transaction = jest.fn((callback) => callback({
      partner_gst_verification_requests: {
        findFirst: jest.fn().mockResolvedValue(null),
        create,
      },
    }));
    const partners = service(PartnersService.prototype, { prisma: { $transaction: transaction }, adminNotificationsService: { notify } });
    await partners.submitGstVerification('partner', { gstNumber: 'test-gst', gstName: 'Test' });
    expect(notify).toHaveBeenCalledWith('gst_verification_submitted', expect.any(String), expect.any(String),
      { partnerId: 'partner', gstVerificationId: 'gst-id' });
    expect(create.mock.invocationCallOrder[0]).toBeLessThan(notify.mock.invocationCallOrder[0]);
    notify.mockClear();
    transaction.mockRejectedValue(new Error('Database failed'));
    await expect(partners.submitGstVerification('partner', { gstNumber: 'test-gst', gstName: 'Test' })).rejects.toThrow('Database failed');
    expect(notify).not.toHaveBeenCalled();
  });

  it('notifies admins when a valid activity enters review, with its venue and service IDs', async () => {
    const update = jest.fn().mockResolvedValue({});
    const activity = { id: 'activity', venueId: 'venue', name: 'Badminton', status: 'draft', imageUrls: ['1', '2', '3', '4'], amenities: ['Parking'] };
    const venues = service(VenuesService.prototype, {
      findOwnedActivity: jest.fn().mockResolvedValue(activity),
      prisma: { partner_venue_services: { update } }, adminNotificationsService: { notify },
      notificationsService: { notify: jest.fn().mockResolvedValue(undefined) },
    });
    await venues.submitActivityForReview('activity', 'partner');
    expect(notify).toHaveBeenCalledWith('activity_submitted', expect.any(String), expect.any(String),
      { partnerId: 'partner', venueId: 'venue', serviceId: 'activity' });
    expect(update.mock.invocationCallOrder[0]).toBeLessThan(notify.mock.invocationCallOrder[0]);
    notify.mockClear();
    activity.imageUrls = [];
    await expect(venues.submitActivityForReview('activity', 'partner')).rejects.toBeInstanceOf(BadRequestException);
    expect(notify).not.toHaveBeenCalled();
  });

  it('links callbacks even if the separate support email delivery fails after saving', async () => {
    const create = jest.fn().mockResolvedValue({ id: 'callback' });
    const support = service(SupportService.prototype, {
      prisma: { partner_callback_requests: { create } }, adminNotificationsService: { notify },
      mailService: { sendCallbackRequestEmail: jest.fn().mockRejectedValue(new Error('Mail unavailable')) },
    });
    await expect(support.createCallback({ partnerName: 'Test', callbackDate: '2026-10-20', callbackTime: '10:00', query: 'Private message' } as any))
      .rejects.toThrow('Mail unavailable');
    expect(notify).toHaveBeenCalledWith('callback_requested', expect.any(String), 'Test requested a callback.', { callbackId: 'callback' });
    expect(create.mock.invocationCallOrder[0]).toBeLessThan(notify.mock.invocationCallOrder[0]);
  });

  it('links support messages to their request without copying the private message or attachments', async () => {
    const record = { id: 'support', subject: 'Question', message: 'Private message' };
    const create = jest.fn().mockResolvedValue(record);
    const support = service(SupportService.prototype, {
      prisma: { partner_users: { findFirst: jest.fn().mockResolvedValue({ id: 'link' }) }, partner_support_requests: { create } },
      adminNotificationsService: { notify },
    });
    expect(await support.createEmail({ subject: 'Question', message: 'Private message' }, 'partner')).toBe(record);
    expect(notify).toHaveBeenCalledWith('support_requested', expect.any(String), 'A partner submitted a support message.',
      { partnerId: 'partner', supportRequestId: 'support' });
    expect(create.mock.invocationCallOrder[0]).toBeLessThan(notify.mock.invocationCallOrder[0]);
    notify.mockClear();
    create.mockRejectedValue(new Error('Database failed'));
    await expect(support.createEmail({ subject: 'Question', message: 'Private message' }, 'partner')).rejects.toThrow('Database failed');
    expect(notify).not.toHaveBeenCalled();
  });

  it('also covers the email/password partner registration route', async () => {
    const tx = {
      users: {
        findFirst: jest.fn().mockResolvedValue(null),
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'user', email: 'test@example.com', phone_e164: '+911234567890' }),
      },
      partners: {
        create: jest.fn().mockResolvedValue({ id: 'partner', legal_name: 'Club', status: 'PENDING', created_at: new Date(), updated_at: new Date() }),
      },
      partner_users: { create: jest.fn() },
      partner_business_profiles: { create: jest.fn() },
    };
    const auth = service(AuthService.prototype, {
      prisma: { $transaction: jest.fn((callback) => callback(tx)) },
      generatePartnerTokens: jest.fn().mockResolvedValue({}), adminNotificationsService: { notify },
    });
    await auth.registerPartner({
      firstName: 'Test', lastName: 'Partner', email: 'test@example.com',
      password: 'Password@123', phone: '+911234567890', businessName: 'Club',
      businessAddress: '1 Main Street', city: 'Jaipur', state: 'Rajasthan',
    } as any);
    expect(notify).toHaveBeenCalledWith('partner_registered', expect.any(String), expect.any(String), { partnerId: 'partner' });
  });
});
