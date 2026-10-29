import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import { Payment } from './entities/payment.entity';
import { Booking } from '../bookings/entities/booking.entity';
import { CreatePaymentOrderDto, VerifyPaymentDto } from './dto/create-payment.dto';
import { PaymentStatus, BookingStatus } from '../../common/enums/booking-status.enum';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/entities/notification.entity';
import { PrismaService } from '../../prisma/prisma.service';
import { normalizedBookingRoutesEnabled } from '../bookings/normalized-booking-feature';
import { NormalizedRazorpayOrderService } from './normalized-razorpay-order.service';
import { createRazorpayOrderClient } from './razorpay-order-client';
import { NormalizedBookingPaymentService } from '../bookings/normalized-booking-payment.service';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    @InjectRepository(Payment)
    private readonly paymentRepository: Repository<Payment>,
    @InjectRepository(Booking)
    private readonly bookingRepository: Repository<Booking>,
    private configService: ConfigService,
    private readonly notificationsService: NotificationsService,
    private readonly prisma: PrismaService,
  ) {}

  private readonly normalizedOrderService = new NormalizedRazorpayOrderService();
  private readonly normalizedPaymentService = new NormalizedBookingPaymentService();

  async createOrder(createPaymentDto: CreatePaymentOrderDto, userId: string) {
    if (normalizedBookingRoutesEnabled(this.configService)) {
      return this.createNormalizedOrder(createPaymentDto.bookingId, userId);
    }
    const booking = await this.bookingRepository.findOne({
      where: { id: createPaymentDto.bookingId, userId },
    });

    if (!booking) {
      throw new NotFoundException('Booking not found');
    }

    if (booking.status !== BookingStatus.PENDING) {
      throw new BadRequestException('Booking is not in pending state');
    }

    // Check for existing payment
    const existingPayment = await this.paymentRepository.findOne({
      where: { bookingId: booking.id, status: PaymentStatus.SUCCESS },
    });

    if (existingPayment) {
      throw new BadRequestException('Booking is already paid');
    }

    // Create a Razorpay order (simulated - in production, call Razorpay API)
    const gatewayOrderId = `order_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;

    const payment = this.paymentRepository.create({
      bookingId: booking.id,
      userId,
      amount: booking.totalAmount,
      currency: 'INR',
      paymentMethod: createPaymentDto.paymentMethod,
      paymentGateway: 'razorpay',
      gatewayOrderId,
      status: PaymentStatus.PENDING,
    });

    const savedPayment = await this.paymentRepository.save(payment);

    return {
      paymentId: savedPayment.id,
      orderId: gatewayOrderId,
      amount: booking.totalAmount * 100, // Razorpay expects paise
      currency: 'INR',
      bookingReference: booking.bookingReference,
      key: this.configService.get<string>('RAZORPAY_KEY_ID'),
    };
  }

  async verifyPayment(verifyDto: VerifyPaymentDto, userId: string): Promise<Payment> {
    if (normalizedBookingRoutesEnabled(this.configService)) {
      return this.verifyNormalizedPayment(verifyDto, userId) as unknown as Payment;
    }
    const { razorpayOrderId, razorpayPaymentId, razorpaySignature, bookingId } = verifyDto;

    const payment = await this.paymentRepository.findOne({
      where: { gatewayOrderId: razorpayOrderId, bookingId, userId },
    });

    if (!payment) {
      throw new NotFoundException('Payment record not found');
    }

    // Verify Razorpay signature
    const keySecret = this.configService.get<string>('RAZORPAY_KEY_SECRET');
    const body = `${razorpayOrderId}|${razorpayPaymentId}`;
    const expectedSignature = crypto
      .createHmac('sha256', keySecret)
      .update(body)
      .digest('hex');

    if (expectedSignature !== razorpaySignature) {
      payment.status = PaymentStatus.FAILED;
      payment.failureReason = 'Signature verification failed';
      await this.paymentRepository.save(payment);
      throw new BadRequestException('Invalid payment signature');
    }

    // Update payment
    payment.status = PaymentStatus.SUCCESS;
    payment.gatewayPaymentId = razorpayPaymentId;
    payment.gatewaySignature = razorpaySignature;
    payment.transactionId = razorpayPaymentId;

    await this.paymentRepository.save(payment);

    // Confirm the booking
    await this.bookingRepository.update(bookingId, { status: BookingStatus.CONFIRMED });

    const confirmedBooking = await this.bookingRepository.findOne({
      where: { id: bookingId },
      relations: ['venue', 'service'],
    });
    if (confirmedBooking?.venue?.partnerId) {
      await this.notificationsService.notify(
        confirmedBooking.venue.partnerId,
        NotificationType.PAYMENT_RECEIVED,
        'Payment received',
        `${confirmedBooking.totalAmount} received for ${confirmedBooking.service?.name ?? 'your booking'}`,
        { bookingId, paymentId: payment.id },
      );
    }

    return payment;
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
    return this.mapNormalizedPayment(confirmedPayment) as unknown as Payment;
  }

  async findAll(pagination: PaginationDto, status?: PaymentStatus) {
    if (normalizedBookingRoutesEnabled(this.configService)) {
      const where = status ? { status: status === PaymentStatus.SUCCESS ? 'CAPTURED' as const : status as any } : {};
      const [items, total] = await Promise.all([
        this.prisma.payments.findMany({ where, include: { bookings: { include: { users: true, slots: true } } }, skip: pagination.skip, take: pagination.limit, orderBy: { created_at: 'desc' } }),
        this.prisma.payments.count({ where }),
      ]);
      return [items.map(payment => this.mapNormalizedPayment(payment)), total] as const;
    }
    const where: any = {};
    if (status) where.status = status;

    return this.paymentRepository.findAndCount({
      where,
      relations: ['user', 'booking'],
      skip: pagination.skip,
      take: pagination.limit,
      order: { createdAt: 'DESC' },
    });
  }

  async findByUser(userId: string, pagination: PaginationDto) {
    if (normalizedBookingRoutesEnabled(this.configService)) {
      const where = { bookings: { user_id: userId } };
      const [items, total] = await Promise.all([
        this.prisma.payments.findMany({ where, include: { bookings: { include: { users: true, slots: true } } }, skip: pagination.skip, take: pagination.limit, orderBy: { created_at: 'desc' } }),
        this.prisma.payments.count({ where }),
      ]);
      return [items.map(payment => this.mapNormalizedPayment(payment)), total] as const;
    }
    return this.paymentRepository.findAndCount({
      where: { userId },
      relations: ['booking'],
      skip: pagination.skip,
      take: pagination.limit,
      order: { createdAt: 'DESC' },
    });
  }

  async findOne(id: string): Promise<Payment> {
    if (normalizedBookingRoutesEnabled(this.configService)) {
      const payment = await this.prisma.payments.findUnique({ where: { id }, include: { bookings: { include: { users: true, slots: true } } } });
      if (!payment) throw new NotFoundException(`Payment with id ${id} not found`);
      return this.mapNormalizedPayment(payment) as unknown as Payment;
    }
    const payment = await this.paymentRepository.findOne({
      where: { id },
      relations: ['user', 'booking'],
    });

    if (!payment) {
      throw new NotFoundException(`Payment with id ${id} not found`);
    }

    return payment;
  }

  async getRevenueStats() {
    if (normalizedBookingRoutesEnabled(this.configService)) {
      const [aggregate, count] = await Promise.all([
        this.prisma.payments.aggregate({ _sum: { amount_paise: true }, where: { status: 'CAPTURED' } }),
        this.prisma.payments.count({ where: { status: 'CAPTURED' } }),
      ]);
      return { totalRevenue: Number(aggregate._sum.amount_paise ?? 0n) / 100, totalTransactions: count };
    }
    const result = await this.paymentRepository
      .createQueryBuilder('payment')
      .select('SUM(payment.amount)', 'totalRevenue')
      .addSelect('COUNT(payment.id)', 'totalTransactions')
      .where('payment.status = :status', { status: PaymentStatus.SUCCESS })
      .getRawOne();

    return {
      totalRevenue: parseFloat(result.totalRevenue || '0'),
      totalTransactions: parseInt(result.totalTransactions || '0'),
    };
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
