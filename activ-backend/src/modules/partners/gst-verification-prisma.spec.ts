import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { PartnersService } from './partners.service';

describe('PartnersService Prisma GST writes', () => {
  const service = (prisma: any) => Object.assign(Object.create(PartnersService.prototype), {
    prisma,
    adminNotificationsService: { notify: jest.fn().mockResolvedValue(undefined) },
  }) as PartnersService;

  it('submits a GST request inside a Prisma transaction and notifies after commit', async () => {
    const create = jest.fn().mockResolvedValue({
      id: 'gst-1', partner_id: 'partner-1', gst_number: 'GST', legal_name: 'Name',
      document_url: null, status: 'PENDING', rejection_reason: null,
      created_at: new Date(), updated_at: new Date(),
    });
    const notify = jest.fn().mockResolvedValue(undefined);
    const prisma = {
      $transaction: jest.fn((callback) => callback({
        partner_gst_verification_requests: {
          findFirst: jest.fn().mockResolvedValue(null), create,
        },
      })),
    };
    const partners: any = Object.assign(service(prisma), { adminNotificationsService: { notify } });

    const result = await partners.submitGstVerification('partner-1', { gstNumber: 'GST', gstName: 'Name' });

    expect(result).toMatchObject({ id: 'gst-1', partnerId: 'partner-1', status: 'pending' });
    expect(create).toHaveBeenCalled();
    expect(notify).toHaveBeenCalled();
  });

  it('rejects duplicate pending submission before create', async () => {
    const create = jest.fn();
    const prisma = {
      $transaction: jest.fn((callback) => callback({
        partner_gst_verification_requests: {
          findFirst: jest.fn().mockResolvedValue({ id: 'existing' }), create,
        },
      })),
    };
    const partners = service(prisma);

    await expect(partners.submitGstVerification('partner-1', { gstNumber: 'GST', gstName: 'Name' }))
      .rejects.toBeInstanceOf(ConflictException);
    expect(create).not.toHaveBeenCalled();
  });

  it('rejects only a pending request atomically', async () => {
    const request = { id: 'gst-1', partner_id: 'partner-1', gst_number: 'GST', legal_name: 'Name', document_url: null, status: 'REJECTED', rejection_reason: 'bad', created_at: new Date(), updated_at: new Date() };
    const prisma = {
      partner_gst_verification_requests: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        findUnique: jest.fn().mockResolvedValue(request),
      },
    };
    const result = await service(prisma).rejectGstVerification('gst-1', { adminNotes: 'bad' });
    expect(result).toMatchObject({ id: 'gst-1', status: 'rejected', adminNotes: 'bad' });
  });

  it('preserves not-found and invalid-state errors during rejection', async () => {
    const prisma = {
      partner_gst_verification_requests: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
        findUnique: jest.fn().mockResolvedValue(null),
      },
    };
    await expect(service(prisma).rejectGstVerification('missing', {})).rejects.toBeInstanceOf(NotFoundException);

    prisma.partner_gst_verification_requests.findUnique.mockResolvedValue({ id: 'done', status: 'APPROVED' });
    await expect(service(prisma).rejectGstVerification('done', {})).rejects.toBeInstanceOf(BadRequestException);
  });

  it('approves a pending request, records reviewer, updates normalized GST fields, and retains history', async () => {
    const request = { id: 'gst-1', partner_id: 'partner-1', gst_number: 'GST', legal_name: 'Legal', document_url: '/gst.pdf', status: 'PENDING', rejection_reason: null, created_at: new Date(), updated_at: new Date() };
    const updateMany = jest.fn().mockResolvedValue({ count: 1 });
    const update = jest.fn().mockResolvedValue({ partner_id: 'partner-1', business_name: 'Club', kyc_status: 'PENDING', gst_number: 'GST', gst_document_url: '/gst.pdf' });
    const prisma = { $transaction: jest.fn((callback) => callback({
      partner_gst_verification_requests: { findUnique: jest.fn().mockResolvedValue(request), updateMany },
      partner_business_profiles: { findUnique: jest.fn().mockResolvedValue({ partner_id: 'partner-1', business_name: 'Club', kyc_status: 'PENDING' }), update },
    })) };
    const result: any = await service(prisma).approveGstVerification('gst-1', 'admin-1');
    expect(result.request.status).toBe('approved');
    expect(result.request.reviewedBy).toBe('admin-1');
    expect(result.businessProfile.gstNumber).toBe('GST');
    expect(updateMany).toHaveBeenCalled();
    expect(update).toHaveBeenCalled();
  });

  it('rejects a repeated approval without updating the profile', async () => {
    const prisma = { $transaction: jest.fn((callback) => callback({
      partner_gst_verification_requests: { findUnique: jest.fn().mockResolvedValue({ id: 'gst-1', status: 'APPROVED' }) },
      partner_business_profiles: { update: jest.fn() },
    })) };
    await expect(service(prisma).approveGstVerification('gst-1', 'admin-1')).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rolls back when the business profile update fails', async () => {
    const update = jest.fn().mockRejectedValue(new Error('profile update failed'));
    const prisma = { $transaction: jest.fn(async (callback) => callback({
      partner_gst_verification_requests: { findUnique: jest.fn().mockResolvedValue({ id: 'gst-1', partner_id: 'partner-1', status: 'PENDING', gst_number: 'GST', document_url: null }), updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      partner_business_profiles: { findUnique: jest.fn().mockResolvedValue({ partner_id: 'partner-1', business_name: 'Club', kyc_status: 'PENDING' }), update },
    })) };
    await expect(service(prisma).approveGstVerification('gst-1', 'admin-1')).rejects.toThrow('profile update failed');
  });
});
