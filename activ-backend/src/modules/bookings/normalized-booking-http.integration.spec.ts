import { randomUUID, createHmac } from 'crypto';
import * as http from 'http';
import { Test } from '@nestjs/testing';
import { ValidationPipe } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AppModule } from '../../app.module';
import { PrismaService } from '../../prisma/prisma.service';

let mockCreateOrder: jest.Mock;
jest.mock('../payments/razorpay-order-client', () => ({
  createRazorpayOrderClient: jest.fn(() => ((input: unknown) => mockCreateOrder(input))),
}));

const url = process.env.TEST_DATABASE_URL;
const databaseName = process.env.TEST_DATABASE_NAME;
const enabled = process.env.TEST_HTTP_E2E_ALLOW_WRITES === 'true' && Boolean(url && databaseName);
const describeHttp = enabled ? describe : describe.skip;

type Fixture = { userId: string; partnerId: string; venueId: string; serviceId: string; facilityId: string; slotId: string; categoryId: string; activityId: string };

describeHttp('normalized booking/payment HTTP integration (local PostgreSQL only)', () => {
  let moduleRef: any;
  let app: any;
  let server: http.Server;
  let address: { port: number };
  let prisma: PrismaService;
  let fixture: Fixture;
  let token: string;

  const request = (method: string, path: string, body?: unknown, headers: Record<string, string> = {}) => new Promise<{ status: number; body: any }>((resolve, reject) => {
    const payload = body === undefined ? undefined : JSON.stringify(body);
    const req = http.request({ hostname: '127.0.0.1', port: address.port, path, method, headers: {
      ...(payload ? { 'content-type': 'application/json', 'content-length': Buffer.byteLength(payload) } : {}),
      authorization: `Bearer ${token}`, ...headers,
    }}, res => {
      let text = '';
      res.setEncoding('utf8');
      res.on('data', chunk => { text += chunk; });
      res.on('end', () => { try { resolve({ status: res.statusCode ?? 0, body: JSON.parse(text) }); } catch { resolve({ status: res.statusCode ?? 0, body: text }); } });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });

  beforeAll(async () => {
    if (!url || !databaseName) throw new Error('HTTP E2E requires TEST_DATABASE_URL and TEST_DATABASE_NAME');
    const parsed = new URL(url);
    if (!['localhost', '127.0.0.1', '::1'].includes(parsed.hostname) || (parsed.port || '5432') !== '5432') throw new Error('HTTP E2E refuses non-local PostgreSQL');
    if (parsed.pathname.slice(1) !== databaseName) throw new Error('HTTP E2E database identity mismatch');
    // AppModule intentionally receives this same local URL through .env.local;
    // the safety check above (host, port and database name) prevents Supabase
    // or another non-disposable database from being used.

    moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    await app.init();
    server = app.getHttpServer();
    await new Promise<void>((resolve, reject) => { server.listen(0, '127.0.0.1', () => resolve()); server.once('error', reject); });
    address = server.address() as { port: number };
    prisma = moduleRef.get(PrismaService);
    const identity = await prisma.$queryRaw<Array<{ database_name: string }>>`SELECT current_database() AS database_name`;
    if (identity[0]?.database_name !== databaseName) throw new Error('HTTP E2E connected to unexpected database');
    fixture = await createFixture();
    token = moduleRef.get(JwtService).sign({ sub: fixture.userId, role: 'user', type: 'user' });
    mockCreateOrder = jest.fn(async (input: any) => ({ id: `order_${fixture.slotId.slice(0, 8)}`, amount: input.amountPaise, currency: input.currency }));
  });

  afterAll(async () => {
    if (fixture) {
      await prisma.payments.deleteMany({ where: { bookings: { user_id: fixture.userId } } });
      await prisma.bookings.deleteMany({ where: { user_id: fixture.userId } });
      await prisma.booking_attempts.deleteMany({ where: { user_id: fixture.userId } });
      await prisma.slots.deleteMany({ where: { id: fixture.slotId } });
      await prisma.partner_venue_availability.deleteMany({ where: { venue_id: fixture.venueId } });
      await prisma.partner_venue_services.deleteMany({ where: { id: fixture.serviceId } });
      await prisma.facilities.deleteMany({ where: { id: fixture.facilityId } });
      await prisma.venues.delete({ where: { id: fixture.venueId } });
      await prisma.activities.delete({ where: { id: fixture.activityId } }).catch(() => undefined);
      await prisma.partner_service_categories.delete({ where: { id: fixture.categoryId } }).catch(() => undefined);
      await prisma.partners.delete({ where: { id: fixture.partnerId } });
      await prisma.users.delete({ where: { id: fixture.userId } });
    }
    await app?.close();
    await moduleRef?.close();
  });

  async function createFixture(): Promise<Fixture> {
    const ids = { userId: randomUUID(), partnerId: randomUUID(), venueId: randomUUID(), serviceId: randomUUID(), facilityId: randomUUID(), slotId: randomUUID(), categoryId: randomUUID(), activityId: randomUUID() };
    const start = new Date(Date.now() + 2 * 86400000);
    start.setMinutes(0, 0, 0);
    const end = new Date(start.getTime() + 3600000);
    const localDate = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' }).format(start);
    const day = new Intl.DateTimeFormat('en-US', { timeZone: 'Asia/Kolkata', weekday: 'long' }).format(start);
    await prisma.$transaction(async tx => {
      await tx.users.create({ data: { id: ids.userId, phone_e164: `+1555${ids.userId.replace(/-/g, '').slice(0, 10)}`, status: 'ACTIVE', updated_at: new Date() } });
      await tx.partners.create({ data: { id: ids.partnerId, legal_name: `HTTP test partner ${ids.partnerId}`, status: 'ACTIVE', updated_at: new Date() } });
      await tx.venues.create({ data: { id: ids.venueId, partner_id: ids.partnerId, name: 'HTTP test venue', city_code: 'TEST', latitude: 0, longitude: 0, status: 'PUBLISHED', policy_version: 'v1', booking_accept: true } });
      await tx.partner_service_categories.create({ data: { id: ids.categoryId, slug: `http-${ids.categoryId}`, name: 'HTTP test activity', status: 'APPROVED', updated_at: new Date() } });
      await tx.activities.create({ data: { id: ids.activityId, sport_code: `HTTP-${ids.activityId}`, name: 'HTTP activity', status: 'PUBLISHED' } });
      await tx.facilities.create({ data: { id: ids.facilityId, venue_id: ids.venueId, activity_id: ids.activityId, name: 'HTTP court', capacity: 1 } });
      await tx.partner_venue_services.create({ data: { id: ids.serviceId, venue_id: ids.venueId, facility_id: ids.facilityId, service_category_id: ids.categoryId, title: 'HTTP service', status: 'APPROVED', updated_at: new Date() } });
      await tx.partner_venue_availability.create({ data: { id: randomUUID(), venue_id: ids.venueId, service_category_id: ids.categoryId, day, open_time: '00:00', close_time: '23:59', capacity: 1, price_paise: 1000n, discounted_price_paise: 1000n } });
      await tx.slots.create({ data: { id: ids.slotId, facility_id: ids.facilityId, starts_at: start, ends_at: end, capacity: 1, booked_quantity: 0, status: 'AVAILABLE', price_paise: 1000n } });
    });
    void localDate;
    return ids;
  }

  it('creates a booking over HTTP and persists a pending payment booking', async () => {
    const start = new Date((await prisma.slots.findUniqueOrThrow({ where: { id: fixture.slotId } })).starts_at);
    const date = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' }).format(start);
    const time = (d: Date) => new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Kolkata', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).format(d);
    const response = await request('POST', '/api/v1/bookings', { venueId: fixture.venueId, serviceId: fixture.serviceId, bookingDate: date, startTime: time(start), endTime: time(new Date(start.getTime() + 3600000)) }, { 'idempotency-key': `http-${randomUUID()}` });
    expect(response.status).toBe(201);
    const bookingId = response.body.data.id;
    const booking = await prisma.bookings.findUnique({ where: { id: bookingId } });
    expect(booking).toMatchObject({ user_id: fixture.userId, status: 'PENDING_PAYMENT' });
  });

  it('rejects unauthorized access and accepts authenticated payment history', async () => {
    const response = await request('GET', '/api/v1/payments/my-payments');
    expect(response.status).toBe(200);
    expect(response.body.data).toHaveProperty('items');
    const unauthorized = await new Promise<number>(resolve => { const req = http.request({ hostname: '127.0.0.1', port: address.port, path: '/api/v1/payments/my-payments' }, res => resolve(res.statusCode ?? 0)); req.end(); });
    expect(unauthorized).toBe(401);
  });

  it('uses a trusted signature for verification', async () => {
    const booking = await prisma.bookings.findFirstOrThrow({ where: { user_id: fixture.userId, status: 'PENDING_PAYMENT' } });
    const order = await request('POST', '/api/v1/payments/create-order', { bookingId: booking.id });
    expect(order.status).toBe(201);
    const payment = await prisma.payments.findUnique({ where: { id: order.body.data.paymentId } });
    expect(payment?.provider_order_id).toBe(order.body.data.orderId);
    const signature = createHmac('sha256', process.env.RAZORPAY_KEY_SECRET || '').update(`${order.body.data.orderId}|pay_http`).digest('hex');
    const verified = await request('POST', '/api/v1/payments/verify', { bookingId: booking.id, razorpayOrderId: order.body.data.orderId, razorpayPaymentId: 'pay_http', razorpaySignature: signature });
    expect(verified.status).toBe(200);
    expect((await prisma.bookings.findUnique({ where: { id: booking.id } }))?.status).toBe('CONFIRMED');
  });
});

if (!enabled) test('HTTP PostgreSQL E2E requires explicit localhost opt-in', () => undefined);
