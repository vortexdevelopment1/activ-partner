import { BankAccountsService } from './bank-accounts.service';
import { BankAccountStatus } from './entities/bank-account.entity';

describe('bank account persistence', () => {
  const dto = { accountHolderName: 'Test Partner', bankName: 'HDFC Bank',
    accountNumber: '1234567890', ifscCode: 'HDFC0001234', accountType: 'Saving Account', branchName: 'Test Branch' };
  const record = { id: 'account', partner_id: 'partner', account_holder_name: dto.accountHolderName,
    bank_name: dto.bankName, account_number: dto.accountNumber, ifsc_code: dto.ifscCode,
    account_type: dto.accountType, branch_name: dto.branchName, cancelled_cheque_url: '/uploads/cheque.pdf', status: 'UNDER_REVIEW' };
  let prisma: any, service: BankAccountsService;
  beforeEach(() => {
    prisma = { partner_bank_accounts: {
      findFirst: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue(record),
      findMany: jest.fn().mockResolvedValue([record]), updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    }, bookings: { aggregate: jest.fn().mockResolvedValue({ _sum: { total_paise: 12000n } }) },
    partner_payouts: { aggregate: jest.fn().mockResolvedValue({ _sum: { amount_paise: 8000n } }) } };
    service = new BankAccountsService(prisma);
  });

  it('writes submitted details to the normalized database table with authenticated partner ownership', async () => {
    const saved = await service.submit('partner', dto, '/uploads/cheque.pdf');
    expect(prisma.partner_bank_accounts.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      partner_id: 'partner', account_holder_name: dto.accountHolderName,
      bank_name: dto.bankName, account_number: dto.accountNumber, ifsc_code: dto.ifscCode,
      account_type: dto.accountType, branch_name: dto.branchName,
      cancelled_cheque_url: '/uploads/cheque.pdf', status: 'UNDER_REVIEW',
    }) });
    expect(saved.status).toBe('under_review');
    expect(saved.accountType).toBe(dto.accountType);
    const loaded = await service.findByPartner('partner');
    expect(loaded[0]).toMatchObject(saved);
    expect(prisma.partner_bank_accounts.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: { partner_id: 'partner' } }));
  });

  it('blocks duplicate pending submissions and missing cheque uploads', async () => {
    prisma.partner_bank_accounts.findFirst.mockResolvedValue(record);
    await expect(service.submit('partner', dto, '/cheque.pdf')).rejects.toThrow('under review');
    prisma.partner_bank_accounts.findFirst.mockResolvedValue(null);
    await expect(service.submit('partner', dto)).rejects.toThrow('cancelled cheque');
    expect(prisma.partner_bank_accounts.create).not.toHaveBeenCalled();
  });

  it('scopes individual account reads to the requesting partner', async () => {
    await expect(service.findOne('account', 'other-partner')).rejects.toThrow('not found');
    expect(prisma.partner_bank_accounts.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 'account', partner_id: 'other-partner' } }));
  });

  it('persists admin review in the same table and rejects concurrent reviews', async () => {
    prisma.partner_bank_accounts.findFirst.mockResolvedValue(record);
    await service.review('account', { status: BankAccountStatus.APPROVED }, 'admin');
    expect(prisma.partner_bank_accounts.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: 'account', status: 'UNDER_REVIEW' }, data: expect.objectContaining({ status: 'APPROVED', reviewed_by: 'admin' }),
    }));
    prisma.partner_bank_accounts.updateMany.mockResolvedValue({ count: 0 });
    await expect(service.review('account', { status: BankAccountStatus.APPROVED }, 'admin')).rejects.toThrow('already been reviewed');
  });

  it('uses owned booking earnings and does not invent bank credits', async () => {
    expect(await service.summary('partner')).toEqual({ totalEarnings: 120, totalCredited: 80 });
    expect(prisma.partner_payouts.aggregate).toHaveBeenCalledWith({
      where: { partner_id: 'partner', status: 'SUCCESS' }, _sum: { amount_paise: true },
    });
    expect(prisma.bookings.aggregate).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ slots: { facilities: { venues: { partner_id: 'partner' } } } }),
    }));
  });
});
