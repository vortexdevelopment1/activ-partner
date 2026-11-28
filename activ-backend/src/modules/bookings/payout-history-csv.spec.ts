import * as ExcelJS from 'exceljs';
import { ConfigService } from '@nestjs/config';
import { BookingsService } from './bookings.service';
import { BookingPayoutQueryDto } from './dto/booking-payout-query.dto';

describe('payout history CSV', () => {
  it('exports the complete Payout Statement CSV format with company, venue, transaction, and summary sections', async () => {
    const payment = {
      status: 'CAPTURED',
      provider_payment_id: 'PAY-2',
      provider_order_id: null,
      updated_at: new Date('2026-11-23T10:00:00Z'),
      refunds: [],
      bookings: {
        id: 'booking-2',
        booking_reference: 'ACTIV-2',
        total_paise: 10000n,
        starts_at: new Date('2026-11-23T09:00:00Z'),
        users: { name: 'Rahul Sharma', phone_e164: '+919999999999' },
        slots: {
          facilities: {
            activities: { name: 'Badminton' },
            venues: {
              public_reference: 'VEN000124',
              name: 'ABC Sports Arena',
              commission_percent: 5,
              partner_venue_legal_documents: { gst_number: '33AAACA3430E1ZD' },
            },
          },
        },
      },
    };
    const secondPayment = {
      ...payment,
      provider_payment_id: 'PAY-1',
      bookings: { ...payment.bookings, id: 'booking-1', booking_reference: 'ACTIV-1' },
    };
    const prisma = {
      payments: {
        findMany: jest.fn().mockResolvedValue([payment, secondPayment]),
        count: jest.fn().mockResolvedValue(2),
      },
      venues: { findFirst: jest.fn().mockResolvedValue(null) },
      partner_business_profiles: {
        findUnique: jest.fn().mockResolvedValue({
          owner_name: 'Jai Kumar Singh',
          phone_e164: '7878797524',
          email: 'venuesports@gmail.com',
        }),
      },
      partner_users: { findFirst: jest.fn().mockResolvedValue(null) },
      partner_bank_accounts: {
        findFirst: jest.fn().mockResolvedValue({
          bank_name: 'HDFC Bank',
          account_number: '1234567890',
        }),
      },
    } as any;
    const service = new BookingsService(prisma, {} as ConfigService);
    const query = Object.assign(new BookingPayoutQueryDto(), {
      startDate: '2026-11-23', endDate: '2026-11-23', status: 'all' as const,
    });

    const file = await service.generatePayoutHistoryCsv(
      { id: 'partner', role: 'partner' }, query,
    );
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(Buffer.from(file.base64, 'base64') as any);
    const sheet = workbook.getWorksheet('Payout Statement')!;
    const allText = sheet.getSheetValues().flat().filter(Boolean).join(' | ');

    expect(allText).toContain('ACTIVPULSE BOOKING PRIVATE LIMITED');
    expect(allText).toContain('Payout Statement');
    expect(allText).toContain('Company Details');
    expect(allText).toContain('33ABCCA3430E1ZD');
    expect(allText).toContain('Venue Details');
    expect(allText).toContain('VEN000124');
    expect(allText).toContain('ABC Sports Arena');
    expect(allText).toContain('Jai Kumar Singh');
    expect(allText).toContain('HDFC Bank');
    expect(allText).toContain('XXXX7890');
    expect(allText).toContain('Booking Date');
    expect(allText).toContain('PAY-2');
    expect(allText).toContain('PAY-1');
    expect(allText).toContain('Badminton');
    expect(allText).toContain('Rahul Sharma');
    expect(allText).toContain('₹94.10');
    expect(allText).toContain('Success');
    expect(allText).toContain('Summary');
    expect(allText).toContain('Net Payable');
    expect(allText).toContain('GST on Commission (18%)');
    expect((sheet.getCell('A2').fill as ExcelJS.FillPattern).fgColor?.argb).toBe('FFFF9900');
    expect((sheet.getCell('A24').fill as ExcelJS.FillPattern).fgColor?.argb).toBe('FFFFFF00');
    expect(file.filename).toBe('activ-payouts-2026-11-23-2026-11-23.xlsx');
    expect(prisma.payments.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ take: 10_001 }),
    );
  });
});
