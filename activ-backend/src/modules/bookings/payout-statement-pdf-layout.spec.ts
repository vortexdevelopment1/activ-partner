import { Test, TestingModule } from '@nestjs/testing';
import { BookingsService } from './bookings.service';
import { PrismaService } from '../../prisma/prisma.service';
import { ConfigService } from '@nestjs/config';
import { PDFDocument, PDFPage } from 'pdf-lib';

describe('PayoutStatementPdfLayout', () => {
  let service: BookingsService;
  const statement = {
    id: 'booking-1',
    bookingId: 'ACTIV-18052026-124',
    transactionId: 'TXN-20260520-556678',
    activityName: 'Badminton',
    slotDate: '20-05-2026',
    slotTime: '6 PM to 7 PM',
    slotBasePrice: 500.0,
    grossBookingAmount: 500.0,
    commissionPercent: 10,
    activCommission: 50.0,
    gstOnCommissionRate: 0.18,
    gstOnCommission: 9.0,
    netReceived: 441.0,
    amountReceived: 441.0,
    status: 'success',
    payoutDate: new Date('2026-11-23T04:24:00Z'),
    isGstRegistered: false,
    bank: {
      accountHolderName: 'Rahul Sharma',
      bankName: 'HDFC Bank',
      accountNumber: '**** **** 1234',
      ifscCode: 'HDFC0001234',
      verified: true,
    },
  };
  let rectangles: jest.SpyInstance;
  let texts: jest.SpyInstance;
  afterEach(() => jest.restoreAllMocks());

  const mockPrisma = {
    bookings: {
      findUnique: jest.fn(),
    },
    payments: {
      findFirst: jest.fn(),
    },
    venue_bank_details: {
      findFirst: jest.fn(),
    },
  };

  const mockConfig = {
    get: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: ConfigService, useValue: mockConfig },
      ],
    }).compile();

    service = module.get<BookingsService>(BookingsService);
    rectangles = jest.spyOn(PDFPage.prototype, 'drawRectangle');
    texts = jest.spyOn(PDFPage.prototype, 'drawText');
  });

  it('generates non-GST statement with single-line status, green amounts, + / - signs, and full divider line', async () => {
    jest.spyOn(service as any, 'getPayoutStatement').mockResolvedValue(statement);

    const result = await service.generatePayoutStatementPdf('booking-1', {
      id: 'user-1',
      role: 'partner',
    });

    expect(result.mimeType).toBe('application/pdf');
    expect(result.filename).toBe('ACTIV_Transaction_TXN-20260520-556678.pdf');
    expect(result.base64).toBeTruthy();

    const doc = await PDFDocument.load(Buffer.from(result.base64, 'base64'));
    expect(doc.getPageCount()).toBe(1);
    expectCellsStayInsideGrid();
  });

  it('generates GST-registered statement with correct venue suffix and styling', async () => {
    jest.spyOn(service as any, 'getPayoutStatement').mockResolvedValue({
      id: 'booking-2',
      bookingId: 'ACTIV-18052026-125',
      transactionId: 'TXN-20260520-999999',
      activityName: 'Tennis',
      slotDate: '21-05-2026',
      slotTime: '7 AM to 8 AM',
      slotBasePrice: 1000.0,
      grossBookingAmount: 1000.0,
      commissionPercent: 10,
      activCommission: 100.0,
      gstOnCommissionRate: 0.18,
      gstOnCommission: 18.0,
      netReceived: 882.0,
      amountReceived: 882.0,
      status: 'success',
      payoutDate: new Date('2026-11-23T05:00:00Z'),
      isGstRegistered: true,
      bank: null,
    });

    const result = await service.generatePayoutStatementPdf('booking-2', {
      id: 'user-2',
      role: 'partner',
    });

    expect(result.filename).toBe('ACTIV_Transaction_TXN-20260520-999999.pdf');
    const doc = await PDFDocument.load(Buffer.from(result.base64, 'base64'));
    expect(doc.getPageCount()).toBe(1);
  });

  function expectCellsStayInsideGrid() {
    const cells = rectangles.mock.calls.filter(([box]) => box.x === 123 || box.x === 124);
    expect(cells).toHaveLength(11);
    cells.forEach(([box], index) => {
      const bank = index >= 6;
      const row = bank ? index - 6 : index;
      const top = (bank ? 244.7 : 425.66) - row * 24.009;
      const bottom = top - 24.009;
      expect(box.y).toBeGreaterThan(bottom + 0.5);
      expect(box.y + box.height).toBeLessThan(top - 0.5);
      expect(box.x).toBeGreaterThan(bank ? 122 : 121);
      expect(box.x + box.width).toBeLessThan(bank ? 570 : 567);
      const fill = box.color;
      expect(fill.red).toBeCloseTo(row % 2 ? 246 / 255 : 1);
      expect(fill.green).toBeCloseTo(row % 2 ? 244 / 255 : 1);
    });
    const values = texts.mock.calls.filter(([, options]) =>
        options.y < 430 && options.y > 120);
    expect(values).toHaveLength(11);
    values.forEach(([value, options], index) => {
      const bank = index >= 6;
      expect(options.x).toBeGreaterThan(bank ? 124 : 123);
      expect(options.x + options.font.widthOfTextAtSize(value, options.size))
          .toBeLessThan(bank ? 568 : 565);
    });
  }

  it('formats the payout date in India time with space above the summary border', async () => {
    jest.spyOn(service as any, 'getPayoutStatement').mockResolvedValue(statement);
    await service.generatePayoutStatementPdf('booking-1', { id: 'user-1', role: 'partner' });
    const [date, options] = texts.mock.calls.find(([value]) => value.endsWith(' IST'))!;
    expect(date).toBe('23 Nov 2026, 09:54 AM IST');
    expect(options.y).toBeGreaterThan(461.98 + 5);
    expect(options.x + options.font.widthOfTextAtSize(date, options.size)).toBeLessThan(285);
  });

  it('fits long names and references without crossing the value-column borders', async () => {
    jest.spyOn(service as any, 'getPayoutStatement').mockResolvedValue({
      ...statement, activityName: 'Community Sports and Fitness Centre '.repeat(4),
      transactionId: 'payment_reference_'.repeat(8),
      bank: { ...statement.bank, accountHolderName: 'Registered Venue Partner Name '.repeat(5) },
    });
    await service.generatePayoutStatementPdf('booking-1', { id: 'user-1', role: 'partner' });
    expectCellsStayInsideGrid();
    expect(texts.mock.calls.some(([, options]) => options.y < 430 && options.size < 10)).toBe(true);
  });

  it('keeps placeholders inside the grid when the payout date and bank are unavailable', async () => {
    jest.spyOn(service as any, 'getPayoutStatement').mockResolvedValue({ ...statement, payoutDate: null, bank: null });
    await service.generatePayoutStatementPdf('booking-1', { id: 'user-1', role: 'partner' });
    expectCellsStayInsideGrid();
    expect(texts.mock.calls.find(([, options]) => options.y === 471.21)?.[0]).toBe('-');
  });
});
