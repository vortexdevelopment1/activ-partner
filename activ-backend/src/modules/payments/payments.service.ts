import {
  Injectable,
  ConflictException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CreatePaymentOrderDto, VerifyPaymentDto } from './dto/create-payment.dto';
import { PaymentStatus } from '../../common/enums/booking-status.enum';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { PrismaService } from '../../prisma/prisma.service';
import { assertPrismaPaymentWriteCompatibility } from '../bookings/normalized-booking-feature';
import { NormalizedRazorpayOrderService } from './normalized-razorpay-order.service';
import { createRazorpayOrderClient } from './razorpay-order-client';
import { NormalizedBookingPaymentService } from '../bookings/normalized-booking-payment.service';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  private readonly normalizedOrderService = new NormalizedRazorpayOrderService();
  private readonly normalizedPaymentService = new NormalizedBookingPaymentService();

  async createOrder(createPaymentDto: CreatePaymentOrderDto, userId: string) {
    assertPrismaPaymentWriteCompatibility(this.configService);
    return this.createNormalizedOrder(createPaymentDto.bookingId, userId);
  }

  async verifyPayment(verifyDto: VerifyPaymentDto, userId: string): Promise<any> {
    assertPrismaPaymentWriteCompatibility(this.configService);
    return this.verifyNormalizedPayment(verifyDto, userId);
  }

  private async createNormalizedOrder(bookingId: string, userId: string) {
    const booking = await this.prisma.bookings.findUnique({
      where: { id: bookingId },
      select: { id: true, user_id: true, status: true, total_paise: true, payment_deadline: true, booking_reference: true },
    });
    if (!booking || booking.user_id !== userId) throw new NotFoundException('Booking not found');
    const result = await this.normalizedOrderService.createOrderWithProvider(this.prisma, {
      bookingId,
      userId,
      provider: 'razorpay',
      amountPaise: booking.total_paise,
      currency: 'INR',
      paymentDeadline: booking.payment_deadline,
      providerClient: createRazorpayOrderClient(this.configService),
    });
    const payment = result.payment as any;
    return {
      paymentId: payment.id,
      orderId: payment.provider_order_id,
      amount: Number(payment.amount_paise),
      currency: payment.currency,
      bookingReference: booking.booking_reference,
      key: this.configService.get<string>('RAZORPAY_KEY_ID'),
    };
  }

  private async verifyNormalizedPayment(verifyDto: VerifyPaymentDto, userId: string) {
    const booking = await this.prisma.bookings.findUnique({
      where: { id: verifyDto.bookingId },
      select: { id: true, user_id: true, total_paise: true },
    });
    if (!booking || booking.user_id !== userId) throw new NotFoundException('Payment record not found');
    const payment = await this.prisma.payments.findFirst({
      where: { booking_id: booking.id, provider: 'razorpay', provider_order_id: verifyDto.razorpayOrderId },
      select: { amount_paise: true, currency: true },
    });
    if (!payment) throw new NotFoundException('Payment record not found');
    if (payment.currency !== 'INR') {
      throw new ConflictException('Payment currency is unresolved; verification is disabled until historical reconciliation');
    }
    await this.normalizedPaymentService.confirmRazorpayPayment(this.prisma as any, {
      bookingId: booking.id,
      orderId: verifyDto.razorpayOrderId,
      paymentId: verifyDto.razorpayPaymentId,
      signature: verifyDto.razorpaySignature,
      keySecret: this.configService.get<string>('RAZORPAY_KEY_SECRET') ?? '',
      expectedAmountPaise: payment.amount_paise,
      currency: payment.currency,
    });
    const confirmedPayment = await this.prisma.payments.findFirstOrThrow({
      where: { booking_id: booking.id, provider_order_id: verifyDto.razorpayOrderId },
      include: { bookings: { include: { users: true, slots: true } } },
    });
    return this.mapNormalizedPayment(confirmedPayment);
  }

  async findAll(pagination: PaginationDto, status?: PaymentStatus) {
    const where = status ? { status: status === PaymentStatus.SUCCESS ? 'CAPTURED' as const : status as any } : {};
    const [items, total] = await Promise.all([
      this.prisma.payments.findMany({ where, include: { bookings: { include: { users: true, slots: true } } }, skip: pagination.skip, take: pagination.limit, orderBy: { created_at: 'desc' } }),
      this.prisma.payments.count({ where }),
    ]);
    return [items.map(payment => this.mapNormalizedPayment(payment)), total] as const;
  }

  async findByUser(userId: string, pagination: PaginationDto) {
    const where = { bookings: { user_id: userId } };
    const [items, total] = await Promise.all([
      this.prisma.payments.findMany({ where, include: { bookings: { include: { users: true, slots: true } } }, skip: pagination.skip, take: pagination.limit, orderBy: { created_at: 'desc' } }),
      this.prisma.payments.count({ where }),
    ]);
    return [items.map(payment => this.mapNormalizedPayment(payment)), total] as const;
  }

  async findOne(id: string): Promise<any> {
    const payment = await this.prisma.payments.findUnique({ where: { id }, include: { bookings: { include: { users: true, slots: true } } } });
    if (!payment) throw new NotFoundException(`Payment with id ${id} not found`);
    return this.mapNormalizedPayment(payment);
  }

  async getRevenueStats() {
    const [aggregate, count] = await Promise.all([
      this.prisma.payments.aggregate({ _sum: { amount_paise: true }, where: { status: 'CAPTURED' } }),
      this.prisma.payments.count({ where: { status: 'CAPTURED' } }),
    ]);
    return { totalRevenue: Number(aggregate._sum.amount_paise ?? 0n) / 100, totalTransactions: count };
  }

  private mapNormalizedPayment(payment: any) {
    const booking = payment.bookings;
    return {
      id: payment.id,
      bookingId: payment.booking_id,
      userId: booking?.user_id,
      amount: Number(payment.amount_paise) / 100,
      currency: payment.currency,
      paymentMethod: null,
      paymentGateway: payment.provider,
      transactionId: payment.provider_payment_id,
      gatewayOrderId: payment.provider_order_id,
      gatewayPaymentId: payment.provider_payment_id,
      gatewaySignature: null,
      status: payment.status === 'CAPTURED' ? PaymentStatus.SUCCESS : String(payment.status).toLowerCase(),
      refundAmount: null,
      refundStatus: null,
      refundId: null,
      metadata: null,
      failureReason: null,
      createdAt: payment.created_at,
      updatedAt: payment.updated_at,
      booking: jsonSafe(booking),
      user: jsonSafe(booking?.users),
    };
  }
}

function jsonSafe(value: any): any {
  if (typeof value === 'bigint') return Number(value);
  if (Array.isArray(value)) return value.map(jsonSafe);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, entry]) => [key, jsonSafe(entry)]));
  }
  return value;
}
