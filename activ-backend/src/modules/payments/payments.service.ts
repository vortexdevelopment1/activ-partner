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

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    @InjectRepository(Payment)
    private readonly paymentRepository: Repository<Payment>,
    @InjectRepository(Booking)
    private readonly bookingRepository: Repository<Booking>,
    private configService: ConfigService,
  ) {}

  async createOrder(createPaymentDto: CreatePaymentOrderDto, userId: string) {
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

    return payment;
  }

  async findAll(pagination: PaginationDto, status?: PaymentStatus) {
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
    return this.paymentRepository.findAndCount({
      where: { userId },
      relations: ['booking'],
      skip: pagination.skip,
      take: pagination.limit,
      order: { createdAt: 'DESC' },
    });
  }

  async findOne(id: string): Promise<Payment> {
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
}
