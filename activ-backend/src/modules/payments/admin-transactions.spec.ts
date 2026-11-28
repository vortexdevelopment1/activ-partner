import { CanActivate, ExecutionContext, INestApplication, UnauthorizedException, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { RolesGuard } from '../../common/guards/roles.guard';
import { ResponseInterceptor } from '../../common/interceptors/response.interceptor';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminTransactionsController } from './admin-transactions.controller';
import { AdminTransactionsService } from './admin-transactions.service';

describe('admin transactions API', () => {
  const date = new Date('2026-11-27T12:00:00Z');
  const booking = {
    booking_reference: 'ACT-123', total_paise: 100000n,
    users: { id: 'user-id', name: 'Customer', password_hash: 'private' },
    slots: { facilities: { venues: {
      id: 'arena-id', name: 'Arena', commission_percent: 7.5,
      partners: { legal_name: 'Venue Partner' },
    } } },
  };
  const prisma = {
    payments: {
      findMany: jest.fn().mockResolvedValue([{
        id: 'payment', provider_payment_id: 'pay_example', provider: 'razorpay',
        status: 'CAPTURED', amount_paise: 100000n, currency: 'INR', created_at: date, bookings: booking,
      }]),
      count: jest.fn().mockResolvedValue(201),
    },
    refunds: {
      findMany: jest.fn().mockResolvedValue([{
        id: 'refund', provider_ref: 'rfnd_example', amount_paise: 12550n, status: 'PROCESSED',
        created_at: date, payments: { provider: 'razorpay', currency: 'INR' }, bookings: booking,
      }]),
      count: jest.fn().mockResolvedValue(1),
    },
    partner_payouts: {
      findMany: jest.fn().mockResolvedValue([{
        id: 'payout', reference: 'UTR123', amount_paise: 91150n, status: 'SUCCESS',
        payout_date: date, partners: { legal_name: 'Venue Partner' },
      }]),
      count: jest.fn().mockResolvedValue(1),
    },
  };
  let app: INestApplication;
  let url: string;
  const request = (query = '', role: string | null = 'admin') =>
    fetch(`${url}/api/v1/admin/transactions${query}`, { headers: role ? { 'test-role': role } : {} });

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [AdminTransactionsController],
      providers: [AdminTransactionsService, RolesGuard, { provide: PrismaService, useValue: prisma }],
    }).compile();
    const testIdentityGuard: CanActivate = {
      canActivate(context: ExecutionContext) {
        const req = context.switchToHttp().getRequest();
        const role = req.headers['test-role'];
        if (!role) throw new UnauthorizedException();
        req.user = { role };
        return true;
      },
    };
    app = module.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalGuards(testIdentityGuard, module.get(RolesGuard));
    app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }));
    app.useGlobalInterceptors(new ResponseInterceptor());
    await app.listen(0, '127.0.0.1');
    url = await app.getUrl();
  });
  afterAll(async () => { await app?.close(); });

  it.each([null, 'user', 'partner', 'team_member'])('restricts access for %s', async (role) => {
    expect((await request('', role)).status).toBe(role ? 403 : 401);
  });

  it.each(['?view=invalid', '?page=0', '?limit=-1'])('validates %s', async (query) => {
    expect((await request(query)).status).toBe(400);
  });

  it('returns paginated payments without nested identity records', async () => {
    const response = await request('?page=2&limit=500');
    expect(response.status).toBe(200);
    const { data } = await response.json();
    expect(data).toMatchObject({ page: 2, limit: 100, total: 201, totalPages: 3, items: [{
      customer: 'Customer', partner: 'Venue Partner', venueName: 'Arena', bookingReference: 'ACT-123',
      amount: 1000, reference: 'pay_example', status: 'CAPTURED',
    }] });
    expect(data.items[0]).not.toHaveProperty('bookings');
    expect(JSON.stringify(data)).not.toContain('password_hash');
    expect(prisma.payments.findMany).toHaveBeenLastCalledWith(expect.objectContaining({ skip: 100, take: 100, where: {} }));
  });

  it('calculates commission estimates using captured payments and the venue rate', async () => {
    const { data } = await (await request('?view=commissions')).json();
    expect(prisma.payments.count).toHaveBeenLastCalledWith({ where: { status: 'CAPTURED' } });
    expect(data.items[0].commission).toEqual({
      commissionPercent: 7.5, activCommission: 75, gstOnCommission: 13.5, netReceived: 911.5,
    });
  });

  it.each([
    ['refunds', 'rfnd_example', 125.5, 'PROCESSED'],
    ['payouts', 'UTR123', 911.5, 'SUCCESS'],
  ])('reads %s from their own transaction records', async (view, reference, amount, status) => {
    const { data } = await (await request(`?view=${view}`)).json();
    expect(data.total).toBe(1);
    expect(data.items[0]).toMatchObject({ reference, amount, status, partner: 'Venue Partner' });
  });
});
