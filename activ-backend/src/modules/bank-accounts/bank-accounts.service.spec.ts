import { BankAccountsService } from './bank-accounts.service';
import { BankAccountStatus } from '../../common/domain-types';
import { SUPPORTED_BANK_ACCOUNT_TYPES } from './dto/submit-bank-account.dto';

describe('bank account persistence', () => {
  const dto = {
    accountHolderName: 'Test Partner',
    bankName: 'HDFC Bank',
    accountNumber: '1234567890',
    ifscCode: 'HDFC0001234',
    accountType: 'Savings Account',
    branchName: 'Test Branch',
  };
  const record = {
    id: 'account',
    partner_id: 'partner',
    account_holder_name: dto.accountHolderName,
    bank_name: dto.bankName,
    account_number: dto.accountNumber,
    ifsc_code: dto.ifscCode,
    account_type: dto.accountType,
    branch_name: dto.branchName,
    cancelled_cheque_url: '/uploads/cheque.pdf',
    status: 'UNDER_REVIEW',
  };
  let prisma: any, service: BankAccountsService;
  beforeEach(() => {
    global.fetch = jest.fn().mockResolvedValue({
      status: 200,
      ok: true,
      json: jest.fn().mockResolvedValue({ BANK: 'HDFC Bank', BRANCH: 'Test Branch' }),
    }) as any;
    prisma = {
      users: { findUnique: jest.fn().mockResolvedValue({ name: ' Super Admin ' }) },
      partner_bank_accounts: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue(record),
        findMany: jest.fn().mockResolvedValue([record]),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      bookings: { aggregate: jest.fn().mockResolvedValue({ _sum: { total_paise: 12000n } }) },
      partner_payouts: { aggregate: jest.fn().mockResolvedValue({ _sum: { amount_paise: 8000n } }) },
    };
    service = new BankAccountsService(
      prisma,
      { notify: jest.fn().mockResolvedValue(undefined) } as any,
      { send: jest.fn().mockResolvedValue(true) } as any,
    );
  });

  it('writes submitted details to the normalized database table with authenticated partner ownership', async () => {
    const saved = await service.submit('partner', dto, '/uploads/cheque.pdf');
    expect(prisma.partner_bank_accounts.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        partner_id: 'partner',
        account_holder_name: dto.accountHolderName,
        bank_name: dto.bankName,
        account_number: dto.accountNumber,
        ifsc_code: dto.ifscCode,
        account_type: 'Savings Account',
        branch_name: dto.branchName,
        cancelled_cheque_url: '/uploads/cheque.pdf',
        status: 'UNDER_REVIEW',
      }),
    });
    expect(saved.status).toBe('under_review');
    expect((service as any).partnerEmailService.send).toHaveBeenCalledWith('partner', 'bank_submitted', {
      bankName: 'HDFC Bank',
      accountLast4: '7890',
      reference: 'account',
    });
    expect((service as any).adminNotificationsService.notify).toHaveBeenCalledWith(
      'bank_account_submitted',
      expect.any(String),
      expect.any(String),
      { partnerId: 'partner', bankAccountId: 'account' },
    );
    expect(saved.accountType).toBe(dto.accountType);
    const loaded = await service.findByPartner('partner');
    expect(loaded[0]).toMatchObject(saved);
    expect(prisma.partner_bank_accounts.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { partner_id: 'partner' } }),
    );
  });

  it('supports all 4 settlement-eligible account types and normalizes legacy Saving Account', async () => {
    for (const type of SUPPORTED_BANK_ACCOUNT_TYPES) {
      prisma.partner_bank_accounts.create.mockClear();
      await service.submit('partner', { ...dto, accountType: type }, '/uploads/cheque.pdf');
      expect(prisma.partner_bank_accounts.create).toHaveBeenCalledWith({
        data: expect.objectContaining({ account_type: type }),
      });
    }

    // Legacy 'Saving Account' normalized to 'Savings Account'
    prisma.partner_bank_accounts.create.mockClear();
    await service.submit('partner', { ...dto, accountType: 'Saving Account' }, '/uploads/cheque.pdf');
    expect(prisma.partner_bank_accounts.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ account_type: 'Savings Account' }),
    });
  });

  it('rejects disallowed account types for Razorpay settlement eligibility', async () => {
    const disallowedTypes = [
      'Jan Dhan',
      'NRE Account',
      'NRO Account',
      'FCNR Account',
      'Fixed Deposit',
      'Recurring Deposit',
      'Cash Credit',
      'Overdraft Account',
    ];

    for (const badType of disallowedTypes) {
      await expect(
        service.submit('partner', { ...dto, accountType: badType }, '/uploads/cheque.pdf'),
      ).rejects.toThrow(/not eligible for Razorpay settlements/i);
    }
  });

  it('rejects all-zero account numbers and branches without electronic settlement capability', async () => {
    // All-zero account number
    await expect(
      service.submit('partner', { ...dto, accountNumber: '0000000000' }, '/uploads/cheque.pdf'),
    ).rejects.toThrow(/cannot consist of only zeros/i);

    // Branch without electronic settlement capability
    global.fetch = jest.fn().mockResolvedValue({
      status: 200,
      ok: true,
      json: jest.fn().mockResolvedValue({
        BANK: 'Old Bank',
        BRANCH: 'Inactive Branch',
        NEFT: false,
        RTGS: false,
        IMPS: false,
      }),
    }) as any;

    await expect(
      service.submit('partner', dto, '/uploads/cheque.pdf'),
    ).rejects.toThrow(/does not support electronic settlements/i);
  });

  it('blocks duplicate pending submissions and missing cheque uploads', async () => {
    prisma.partner_bank_accounts.findFirst.mockResolvedValue(record);
    await expect(service.submit('partner', dto, '/cheque.pdf')).rejects.toThrow('under review');
    prisma.partner_bank_accounts.findFirst.mockResolvedValue(null);
    await expect(service.submit('partner', dto)).rejects.toThrow('cancelled cheque');
    expect(prisma.partner_bank_accounts.create).not.toHaveBeenCalled();
    expect((service as any).adminNotificationsService.notify).not.toHaveBeenCalled();
  });

  it('scopes individual account reads to the requesting partner', async () => {
    await expect(service.findOne('account', 'other-partner')).rejects.toThrow('not found');
    expect(prisma.partner_bank_accounts.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: 'account', partner_id: 'other-partner' } }),
    );
  });

  it('shows the reviewing admin name while preserving the review ID', async () => {
    prisma.partner_bank_accounts.findFirst.mockResolvedValue({ ...record, reviewed_by: 'admin' });
    expect(await service.findOne('account')).toMatchObject({ reviewedBy: 'admin', reviewedByName: 'Super Admin' });
    expect(prisma.users.findUnique).toHaveBeenCalledWith({ where: { id: 'admin' }, select: { name: true } });
  });

  it('handles missing reviewers and avoids resolving names in partner-scoped responses', async () => {
    prisma.partner_bank_accounts.findFirst.mockResolvedValue({ ...record, reviewed_by: 'admin' });
    prisma.users.findUnique.mockResolvedValue(null);
    expect((await service.findOne('account')).reviewedByName).toBeNull();
    prisma.users.findUnique.mockClear();
    expect((await service.findOne('account', 'partner')).reviewedByName).toBeNull();
    expect(prisma.users.findUnique).not.toHaveBeenCalled();
  });

  it('persists admin review in the same table and rejects concurrent reviews', async () => {
    prisma.partner_bank_accounts.findFirst.mockResolvedValue(record);
    await service.review('account', { status: BankAccountStatus.APPROVED }, 'admin');
    expect((service as any).partnerEmailService.send).toHaveBeenCalledWith(
      'partner',
      'bank_approved',
      expect.objectContaining({ accountLast4: '7890' }),
    );
    (service as any).partnerEmailService.send.mockClear();
    expect(prisma.partner_bank_accounts.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'account', status: 'UNDER_REVIEW' },
        data: expect.objectContaining({ status: 'APPROVED', reviewed_by: 'admin' }),
      }),
    );
    prisma.partner_bank_accounts.updateMany.mockResolvedValue({ count: 0 });
    await expect(service.review('account', { status: BankAccountStatus.APPROVED }, 'admin')).rejects.toThrow(
      'already been reviewed',
    );
    expect((service as any).partnerEmailService.send).not.toHaveBeenCalled();
  });

  it('uses owned booking earnings and does not invent bank credits', async () => {
    expect(await service.summary('partner')).toEqual({ totalEarnings: 120, totalCredited: 80 });
    expect(prisma.partner_payouts.aggregate).toHaveBeenCalledWith({
      where: { partner_id: 'partner', status: 'SUCCESS' },
      _sum: { amount_paise: true },
    });
    expect(prisma.bookings.aggregate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ slots: { facilities: { venues: { partner_id: 'partner' } } } }),
      }),
    );
  });
});
