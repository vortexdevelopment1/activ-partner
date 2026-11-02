import { BadRequestException, ConflictException } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { PartnersService } from './partners.service';
import { AdminUpdatePartnerDto } from './dto/admin-update-partner.dto';

describe('admin partner editing', () => {
  let tx: any;
  let service: PartnersService;
  const bank = { id: 'bank', accountHolderName: 'Owner', bankName: 'Bank', accountNumber: '12345678', ifscCode: 'ABCD0123456', status: 'APPROVED' as any, isPrimary: true };
  beforeEach(() => {
    const current = { id: 'partner', legal_name: 'Business', status: 'ACTIVE', partner_users: [{ user_id: 'owner', users: { name: 'Old Owner', email: 'old@example.com', phone_e164: '+919876543210' } }] };
    tx = {
      partners: { findUnique: jest.fn().mockResolvedValue(current), update: jest.fn().mockImplementation(async ({ data }) => ({ ...current, ...data })) },
      users: { findFirst: jest.fn().mockResolvedValue(null), findUnique: jest.fn().mockResolvedValue(null), update: jest.fn().mockImplementation(async ({ data }) => ({ id: 'owner', ...data })) },
      partner_business_profiles: { upsert: jest.fn().mockResolvedValue({}) },
      partner_bank_accounts: { findFirst: jest.fn().mockResolvedValue({ id: 'bank', status: 'UNDER_REVIEW' }), update: jest.fn(), updateMany: jest.fn(), create: jest.fn() },
    };
    service = Object.assign(Object.create(PartnersService.prototype), {
      prisma: { $transaction: (callback: any) => callback(tx) },
      mailService: { sendSuspensionEmail: jest.fn() },
    });
    jest.spyOn(service, 'findOne').mockResolvedValue({ id: 'partner', status: 'active' } as any);
  });

  it('saves profile, documents, verification, status and bank details together', async () => {
    await service.update('partner', { firstName: 'New', lastName: 'Owner', isActive: true, businessName: 'New Business', gstNumber: 'GST', panNumber: 'PAN', gstinDocUrl: 'https://example.com/gst.pdf', panCardUrl: '', kycStatus: 'APPROVED' as any, bankAccounts: [bank] }, 'admin');
    expect(tx.users.update).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ name: 'New Owner' }) }));
    expect(tx.partner_business_profiles.upsert).toHaveBeenCalledWith(expect.objectContaining({ update: expect.objectContaining({ business_name: 'New Business', gst_number: 'GST', pan_number: 'PAN', gst_document_url: 'https://example.com/gst.pdf', pan_document_url: null, kyc_status: 'APPROVED', reviewed_by: 'admin' }) }));
    expect(tx.partners.update).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ status: 'ACTIVE' }) }));
    expect(tx.partner_bank_accounts.update).toHaveBeenCalledWith({ where: { id: 'bank' }, data: expect.objectContaining({ account_number: '12345678', status: 'APPROVED', reviewed_by: 'admin' }) });
  });

  it('rejects bank accounts owned by another partner', async () => {
    tx.partner_bank_accounts.findFirst.mockResolvedValue(null);
    await expect(service.update('partner', { bankAccounts: [bank] }, 'admin')).rejects.toThrow(BadRequestException);
    expect(tx.partner_bank_accounts.update).not.toHaveBeenCalled();
  });

  it('rejects duplicate contact details', async () => {
    tx.users.findFirst.mockResolvedValue({ id: 'someone-else' });
    await expect(service.update('partner', { email: 'used@example.com' })).rejects.toThrow(ConflictException);
    expect(tx.users.update).not.toHaveBeenCalled();
  });

  it.each([{ isVerified: true }, { isActive: true }, { status: 'ACTIVE' }, { bankAccounts: [] }])('prevents self-service privilege changes: %j', async payload => {
    await expect(service.updateOwnProfile('partner', payload as any)).rejects.toThrow(BadRequestException);
    expect(tx.users.update).not.toHaveBeenCalled();
  });

  it('allows clearing optional email and document values', async () => {
    await service.update('partner', { email: '', panCardUrl: '' });
    expect(tx.users.update).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ email: null }) }));
    expect(await validate(plainToInstance(AdminUpdatePartnerDto, { email: '', panCardUrl: '' }))).toHaveLength(0);
  });

  it('validates nested bank details and rejects invalid status values', async () => {
    const errors = await validate(plainToInstance(AdminUpdatePartnerDto, { status: 'invalid', bankAccounts: [{ accountNumber: 42, status: 'invalid' }] }));
    expect(errors.map(error => error.property)).toEqual(expect.arrayContaining(['status', 'bankAccounts']));
  });
});
