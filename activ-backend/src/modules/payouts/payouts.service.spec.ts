import { PayoutsService } from './payouts.service';
import { PayoutQueryDto } from './dto/payout-query.dto';

describe('database payout history', () => {
  const record = { id: 'payout', reference: '=REFERENCE', amount_paise: 12550n,
    status: 'SUCCESS', payout_date: new Date('2026-10-09T20:00:00Z'), failure_reason: null,
    bank_account: { bank_name: 'Test Bank', account_number: '1234567890' } };
  let prisma: any, service: PayoutsService;
  beforeEach(() => {
    prisma = { partner_payouts: { findMany: jest.fn().mockResolvedValue([record]),
      count: jest.fn().mockResolvedValue(1), create: jest.fn().mockResolvedValue(record) },
      partners: { findUnique: jest.fn().mockResolvedValue({ id: 'partner' }) },
      partner_bank_accounts: { findFirst: jest.fn().mockResolvedValue({ id: 'bank' }) } };
    service = new PayoutsService(prisma);
  });
  const query = { startDate: '2026-10-10', endDate: '2026-10-10', status: 'success', page: 2, limit: 20 } as PayoutQueryDto;

  it('scopes pagination and inclusive Indian dates to authenticated ownership', async () => {
    const result = await service.history('partner', query);
    expect(prisma.partner_payouts.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { partner_id: 'partner', status: 'SUCCESS', payout_date: {
        gte: new Date('2026-10-09T18:30:00Z'), lt: new Date('2026-10-10T18:30:00Z'),
      } }, skip: 20, take: 20,
    }));
    expect(result.items[0]).toMatchObject({ amount: 125.5, status: 'success', accountLast4: '7890' });
    expect(JSON.stringify(result)).not.toContain('1234567890');
  });

  it('rejects reversed date ranges before querying', async () => {
    await expect(service.history('partner', { ...query, startDate: '2026-10-11' })).rejects.toThrow('valid date range');
    expect(prisma.partner_payouts.findMany).not.toHaveBeenCalled();
  });

  it('exports real filtered CSV data, escapes spreadsheet formulas and masks accounts', async () => {
    const file = await service.generateExport('partner', { ...query, format: 'csv' });
    const csv = Buffer.from(file.base64, 'base64').toString('utf8');
    expect(csv).toContain("'=REFERENCE");
    expect(csv).toContain('125.50');
    expect(csv).toContain('10/10/2026');
    expect(csv).not.toContain('1234567890');
    expect(file.mimeType).toBe('text/csv');
    expect(prisma.partner_payouts.count).toHaveBeenCalledWith({ where: expect.objectContaining({ partner_id: 'partner', status: 'SUCCESS' }) });
  });

  it('generates a valid PDF and an empty report without sample payouts', async () => {
    prisma.partner_payouts.findMany.mockResolvedValue([]);
    prisma.partner_payouts.count.mockResolvedValue(0);
    const pdf = await service.generateExport('partner', { ...query, format: 'pdf' });
    expect(Buffer.from(pdf.base64, 'base64').subarray(0, 5).toString()).toBe('%PDF-');
    const csv = await service.generateExport('partner', { ...query, format: 'csv' });
    expect(Buffer.from(csv.base64, 'base64').toString().split('\r\n')).toHaveLength(1);
  });

  it('limits large exports', async () => {
    prisma.partner_payouts.count.mockResolvedValue(10001);
    await expect(service.generateExport('partner', query)).rejects.toThrow('smaller date range');
  });

  const dto = { partnerId: 'partner', bankAccountId: 'bank', reference: ' ref ', amount: 125.5,
    status: 'success' as const, payoutDate: '2026-10-10T12:00:00Z' };
  it('persists actual payout records in integer paise with an owned approved bank account', async () => {
    await service.record(dto);
    expect(prisma.partner_bank_accounts.findFirst).toHaveBeenCalledWith({ where: {
      id: 'bank', partner_id: 'partner', status: 'APPROVED',
    } });
    expect(prisma.partner_payouts.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({
      partner_id: 'partner', amount_paise: 12550n, reference: 'ref', status: 'SUCCESS',
    }) }));
  });

  it('rejects another partner bank account and duplicate references', async () => {
    prisma.partner_bank_accounts.findFirst.mockResolvedValue(null);
    await expect(service.record(dto)).rejects.toThrow('belonging to this partner');
    expect(prisma.partner_payouts.create).not.toHaveBeenCalled();
    prisma.partner_bank_accounts.findFirst.mockResolvedValue({ id: 'bank' });
    prisma.partner_payouts.create.mockRejectedValue({ code: 'P2002' });
    await expect(service.record(dto)).rejects.toThrow('already been recorded');
  });
});
