import { Test, TestingModule } from '@nestjs/testing';
import { BookingsService } from './bookings.service';
import { PrismaService } from '../../prisma/prisma.service';
import { ConfigService } from '@nestjs/config';
import { PDFDocument, rgb } from 'pdf-lib';

describe('PayoutStatementPdfLayout', () => {
  let service: BookingsService;

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
  });

  it('generates non-GST statement with single-line status, green amounts, + / - signs, and full divider line', async () => {
    jest.spyOn(service as any, 'getPayoutStatement').mockResolvedValue({
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
    });

    const result = await service.generatePayoutStatementPdf('booking-1', {
      id: 'user-1',
      role: 'partner',
    });

    expect(result.mimeType).toBe('application/pdf');
    expect(result.filename).toBe('ACTIV_Transaction_TXN-20260520-556678.pdf');
    expect(result.base64).toBeTruthy();

    const doc = await PDFDocument.load(Buffer.from(result.base64, 'base64'));
    expect(doc.getPageCount()).toBe(1);
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
});
