import { ConfigService } from '@nestjs/config';
import { BookingsService } from './bookings.service';
import { BookingPayoutQueryDto } from './dto/booking-payout-query.dto';

describe('payout history CSV', () => {
  it('exports the same payment records used by payout history', async () => {
    const payment = {
      status: 'CAPTURED',
      provider_payment_id: 'PAY-2',
      provider_order_id: null,
      updated_at: new Date('2026-11-23T10:00:00Z'),
      bookings: {
        id: 'booking-2', booking_reference: 'ACTIV-2', total_paise: 10000n,
        starts_at: new Date('2026-11-23T09:00:00Z'),
        slots: { facilities: { venues: { commission_percent: 5 } } },
      },
    };
    const secondPayment = {
      ...payment,
      provider_payment_id: 'PAY-1',
      bookings: { ...payment.bookings, id: 'booking-1' },
    };
    const prisma = {
      payments: {
        findMany: jest.fn().mockResolvedValue([payment, secondPayment]),
        count: jest.fn().mockResolvedValue(2),
      },
    } as any;
    const service = new BookingsService(prisma, {} as ConfigService);
    const query = Object.assign(new BookingPayoutQueryDto(), {
      startDate: '2026-11-23', endDate: '2026-11-23', status: 'all' as const,
    });

    const file = await service.generatePayoutHistoryCsv(
      { id: 'partner', role: 'partner' }, query,
    );
    const csv = Buffer.from(file.base64, 'base64').toString('utf8');

    expect(csv).toContain('PAY-2');
    expect(csv).toContain('PAY-1');
    expect(csv.split('\r\n')).toHaveLength(3);
    expect(csv).toContain('94.10');
    expect(csv).toContain('success');
    expect(file.filename).toBe('activ-payouts-2026-11-23-2026-11-23.csv');
    expect(prisma.payments.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ take: 10_001 }),
    );
  });
});
