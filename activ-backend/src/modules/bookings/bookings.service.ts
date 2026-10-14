import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as fs from 'fs';
import * as path from 'path';
import { PDFDocument, StandardFonts, rgb } from 'pdf-lib';
import { Booking } from './entities/booking.entity';
import { VenueService } from '../venues/entities/venue-service.entity';
import { Venue } from '../venues/entities/venue.entity';
import { Payment } from '../payments/entities/payment.entity';
import { PaymentStatus } from '../../common/enums/booking-status.enum';
import { BankAccount, BankAccountStatus } from '../bank-accounts/entities/bank-account.entity';
import { CreateBookingDto } from './dto/create-booking.dto';
import { BookingStatus } from '../../common/enums/booking-status.enum';
import { UserRole } from '../../common/enums/user-role.enum';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { User } from '../users/entities/user.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/entities/notification.entity';

// ACTIV Commission GST rate — fixed for the MVP settlement model (not configurable).
const GST_ON_COMMISSION_RATE = 0.18;

@Injectable()
export class BookingsService {
  constructor(
    @InjectRepository(Booking)
    private readonly bookingRepository: Repository<Booking>,
    @InjectRepository(VenueService)
    private readonly venueServiceRepository: Repository<VenueService>,
    @InjectRepository(Venue)
    private readonly venueRepository: Repository<Venue>,
    @InjectRepository(Payment)
    private readonly paymentRepository: Repository<Payment>,
    @InjectRepository(BankAccount)
    private readonly bankAccountRepository: Repository<BankAccount>,
    private readonly notificationsService: NotificationsService,
  ) {}

  private generateBookingReference(): string {
    const timestamp = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).substring(2, 6).toUpperCase();
    return `BK-${timestamp}-${random}`;
  }

  private calculateDuration(startTime: string, endTime: string): number {
    const [startH, startM] = startTime.split(':').map(Number);
    const [endH, endM] = endTime.split(':').map(Number);
    return (endH * 60 + endM) - (startH * 60 + startM);
  }

  private calculateAmount(pricePerHour: number, durationMinutes: number): number {
    return (pricePerHour / 60) * durationMinutes;
  }

  // Convert "09:00 AM" / "09:00 PM" → total minutes since midnight
  private to24hMinutes(time12h: string): number {
    const [timePart, meridiem] = time12h.trim().split(' ');
    let [h, m] = timePart.split(':').map(Number);
    if (meridiem?.toUpperCase() === 'PM' && h !== 12) h += 12;
    if (meridiem?.toUpperCase() === 'AM' && h === 12) h = 0;
    return h * 60 + m;
  }

  // Convert "10:00" (24h HH:mm) → total minutes since midnight
  private hhmm24ToMinutes(time24h: string): number {
    const [h, m] = time24h.split(':').map(Number);
    return h * 60 + m;
  }

  /**
   * Resolve the per-slot price from the venue's availability JSONB.
   * Looks up categoryId → day → slot that contains startTime.
   * Returns { price, discountedPrice } from the matching slot.
   * Falls back to { price: fallbackPricePerHour, discountedPrice: 0 } if no match.
   */
  private resolveSlotPrice(
    venue: Venue,
    categoryId: string,
    bookingDate: string,
    startTime: string,
    fallbackPricePerHour: number,
  ): { price: number; discountedPrice: number } {
    const fallback = { price: fallbackPricePerHour, discountedPrice: 0 };

    if (!categoryId || !venue.availability) return fallback;

    const categorySchedule = venue.availability[categoryId];
    if (!categorySchedule) return fallback;

    // bookingDate is YYYY-MM-DD — get the weekday name in lowercase
    const dayName = new Date(bookingDate).toLocaleDateString('en-US', { weekday: 'long' }).toLowerCase();
    const dayEntry = categorySchedule.find((d) => d.day.toLowerCase() === dayName);
    if (!dayEntry?.slots?.length) return fallback;

    const startMinutes = this.hhmm24ToMinutes(startTime);

    const matchedSlot = dayEntry.slots.find((slot) => {
      const slotOpen  = this.to24hMinutes(slot.openTime);
      const slotClose = this.to24hMinutes(slot.closeTime);
      return startMinutes >= slotOpen && startMinutes < slotClose;
    });

    if (!matchedSlot) return fallback;

    return {
      price: Number(matchedSlot.price) || fallbackPricePerHour,
      discountedPrice: Number(matchedSlot.discountedPrice) || 0,
    };
  }

  async create(createBookingDto: CreateBookingDto, userId: string): Promise<Booking> {
    const { venueId, serviceId, bookingDate, startTime, endTime, notes, categoryId } = createBookingDto;

    const service = await this.venueServiceRepository.findOne({
      where: { id: serviceId, venueId, isActive: true },
    });

    if (!service) {
      throw new NotFoundException('Service not found or not available');
    }

    const durationMinutes = this.calculateDuration(startTime, endTime);

    if (durationMinutes <= 0) {
      throw new BadRequestException('End time must be after start time');
    }

    if (service.minDuration && durationMinutes < service.minDuration) {
      throw new BadRequestException(
        `Minimum booking duration is ${service.minDuration} minutes`,
      );
    }

    if (service.maxDuration && durationMinutes > service.maxDuration) {
      throw new BadRequestException(
        `Maximum booking duration is ${service.maxDuration} minutes`,
      );
    }

    // Check for conflicting bookings
    const conflict = await this.bookingRepository
      .createQueryBuilder('booking')
      .where('booking.venueId = :venueId', { venueId })
      .andWhere('booking.serviceId = :serviceId', { serviceId })
      .andWhere('booking.bookingDate = :bookingDate', { bookingDate })
      .andWhere('booking.status NOT IN (:...statuses)', {
        statuses: [BookingStatus.CANCELLED],
      })
      .andWhere(
        '(booking.startTime < :endTime AND booking.endTime > :startTime)',
        { startTime, endTime },
      )
      .getOne();

    if (conflict) {
      throw new BadRequestException('This time slot is already booked');
    }

    // Resolve price from JSONB availability slot; fallback to service.pricePerHour
    const venue = await this.venueRepository.findOne({ where: { id: venueId } });
    const { price: slotPrice, discountedPrice: slotDiscountedPrice } = this.resolveSlotPrice(
      venue,
      categoryId,
      bookingDate,
      startTime,
      Number(service.pricePerHour),
    );

    // Use discountedPrice when set (> 0), otherwise use base price
    const effectivePrice = slotDiscountedPrice > 0 ? slotDiscountedPrice : slotPrice;
    const totalAmount = this.calculateAmount(effectivePrice, durationMinutes);

    const booking = this.bookingRepository.create({
      userId,
      venueId,
      serviceId,
      categoryId: categoryId ?? null,
      bookingDate,
      startTime,
      endTime,
      durationMinutes,
      totalAmount,
      notes,
      status: BookingStatus.PENDING,
      bookingReference: this.generateBookingReference(),
    });

    return this.bookingRepository.save(booking);
  }

  async findAll(pagination: PaginationDto, status?: BookingStatus) {
    const where: any = {};
    if (status) where.status = status;

    return this.bookingRepository.findAndCount({
      where,
      relations: ['user', 'venue', 'service'],
      skip: pagination.skip,
      take: pagination.limit,
      order: { createdAt: 'DESC' },
    });
  }

  async findByUser(userId: string, pagination: PaginationDto, status?: BookingStatus) {
    const where: any = { userId };
    if (status) where.status = status;

    return this.bookingRepository.findAndCount({
      where,
      relations: ['venue', 'service', 'venue.images'],
      skip: pagination.skip,
      take: pagination.limit,
      order: { createdAt: 'DESC' },
    });
  }

  async findByVenue(venueId: string, pagination: PaginationDto, status?: BookingStatus) {
    const where: any = { venueId };
    if (status) where.status = status;

    return this.bookingRepository.findAndCount({
      where,
      relations: ['user', 'service'],
      skip: pagination.skip,
      take: pagination.limit,
      order: { bookingDate: 'DESC' },
    });
  }

  async findOne(id: string): Promise<Booking> {
    const booking = await this.bookingRepository.findOne({
      where: { id },
      relations: ['user', 'venue', 'service'],
    });

    if (!booking) {
      throw new NotFoundException(`Booking with id ${id} not found`);
    }

    return booking;
  }

  async findByReference(reference: string): Promise<Booking> {
    const booking = await this.bookingRepository.findOne({
      where: { bookingReference: reference },
      relations: ['user', 'venue', 'service'],
    });

    if (!booking) {
      throw new NotFoundException(`Booking with reference ${reference} not found`);
    }

    return booking;
  }

  async cancel(id: string, reason: string, currentUser: User): Promise<Booking> {
    const booking = await this.findOne(id);

    if (currentUser.role === UserRole.USER && booking.userId !== currentUser.id) {
      throw new ForbiddenException('You can only cancel your own bookings');
    }

    if (booking.status === BookingStatus.CANCELLED) {
      throw new BadRequestException('Booking is already cancelled');
    }

    if (booking.status === BookingStatus.COMPLETED) {
      throw new BadRequestException('Cannot cancel a completed booking');
    }

    booking.status = BookingStatus.CANCELLED;
    booking.cancellationReason = reason;
    return this.bookingRepository.save(booking);
  }

  async confirm(id: string): Promise<Booking> {
    const booking = await this.findOne(id);
    booking.status = BookingStatus.CONFIRMED;
    const saved = await this.bookingRepository.save(booking);

    // Notify the venue partner about the confirmed (paid) booking
    const venue = await this.venueRepository.findOne({ where: { id: saved.venueId } });
    if (venue?.partnerId) {
      const service = await this.venueServiceRepository.findOne({ where: { id: saved.serviceId } });
      await this.notificationsService.notify(
        venue.partnerId,
        NotificationType.BOOKING_RECEIVED,
        'New booking received',
        `${service?.name ?? 'Activity'} booked for ${saved.bookingDate} ${saved.startTime}-${saved.endTime}`,
        { bookingId: saved.id, serviceId: saved.serviceId },
      );
    }

    return saved;
  }

  async complete(id: string): Promise<Booking> {
    const booking = await this.findOne(id);
    booking.status = BookingStatus.COMPLETED;
    return this.bookingRepository.save(booking);
  }

  async checkIn(bookingId: string, partnerUserId: string): Promise<Booking> {
    const booking = await this.bookingRepository.findOne({
      where: { id: bookingId },
      relations: ['venue'],
    });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.venue.partnerId !== partnerUserId)
      throw new ForbiddenException('Not authorized to manage this booking');
    if (booking.status === BookingStatus.CANCELLED)
      throw new BadRequestException('Cannot check in a cancelled booking');
    if (booking.status === BookingStatus.NO_SHOW)
      throw new BadRequestException('Booking is already marked as no-show');
    booking.status = BookingStatus.CONFIRMED;
    return this.bookingRepository.save(booking);
  }

  async markNoShow(bookingId: string, partnerUserId: string): Promise<Booking> {
    const booking = await this.bookingRepository.findOne({
      where: { id: bookingId },
      relations: ['venue'],
    });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.venue.partnerId !== partnerUserId)
      throw new ForbiddenException('Not authorized to manage this booking');
    if (booking.status === BookingStatus.CANCELLED)
      throw new BadRequestException('Cannot mark a cancelled booking as no-show');
    if (booking.status === BookingStatus.COMPLETED)
      throw new BadRequestException('Cannot mark a completed booking as no-show');
    booking.status = BookingStatus.NO_SHOW;
    return this.bookingRepository.save(booking);
  }

  async getBookingStats(partnerId?: string) {
    const query = this.bookingRepository.createQueryBuilder('booking');

    if (partnerId) {
      query.innerJoin('booking.venue', 'venue').where('venue.partnerId = :partnerId', { partnerId });
    }

    const total = await query.getCount();
    const pending = await this.bookingRepository.count({ where: partnerId ? {} : { status: BookingStatus.PENDING } });
    const confirmed = await this.bookingRepository.count({ where: { status: BookingStatus.CONFIRMED } });
    const completed = await this.bookingRepository.count({ where: { status: BookingStatus.COMPLETED } });

    return { total, pending, confirmed, completed };
  }

  // ── Payout statement (Transaction Details screen) ─────────────────────────

  private mapPayoutStatus(status: PaymentStatus): 'success' | 'pending' | 'failed' {
    if (status === PaymentStatus.SUCCESS) return 'success';
    if (status === PaymentStatus.PENDING || status === PaymentStatus.PROCESSING) return 'pending';
    return 'failed';
  }

  private computeBreakdown(totalAmount: number, commissionPercent: number) {
    const round2 = (n: number) => Math.round(n * 100) / 100;
    const activCommission = round2((totalAmount * commissionPercent) / 100);
    const gstOnCommission = round2(activCommission * GST_ON_COMMISSION_RATE);
    const netReceived = round2(totalAmount - activCommission - gstOnCommission);
    return { commissionPercent, activCommission, gstOnCommission, netReceived };
  }

  private maskAccountNumber(accountNumber: string): string {
    const last4 = accountNumber.slice(-4);
    return `XXXX XXXX ${last4}`;
  }

  async getPayoutStatement(bookingId: string, currentUser: { id: string; role: string }) {
    const booking = await this.bookingRepository.findOne({
      where: { id: bookingId },
      relations: ['venue', 'venue.partner', 'service'],
    });
    if (!booking) throw new NotFoundException('Booking not found');
    if (currentUser.role === UserRole.PARTNER && booking.venue.partnerId !== currentUser.id) {
      throw new ForbiddenException('You can only view payouts for your own venues');
    }

    const payment = await this.paymentRepository.findOne({ where: { bookingId: booking.id } });
    const { commissionPercent, activCommission, gstOnCommission, netReceived } =
      this.computeBreakdown(Number(booking.totalAmount), Number(booking.venue.commission ?? 10));

    const partner = booking.venue.partner;
    const isGstRegistered = !!(partner?.gstNumber && partner?.gstVerifiedAt);

    const bankAccount = await this.bankAccountRepository.findOne({
      where: { partnerId: booking.venue.partnerId },
      order: { updatedAt: 'DESC' },
    });

    // Settlement follows a T+7 cycle from when the payment succeeded.
    const payoutDate = payment?.updatedAt
      ? new Date(new Date(payment.updatedAt).getTime() + 7 * 24 * 60 * 60 * 1000)
      : null;

    return {
      status: payment ? this.mapPayoutStatus(payment.status) : 'pending',
      isGstRegistered,
      grossBookingAmount: Number(booking.totalAmount),
      commissionPercent,
      activCommission,
      gstOnCommission,
      netReceived,
      amountReceived: netReceived,
      payoutDate,
      activityName: booking.service?.name ?? '',
      slotDate: booking.bookingDate,
      slotTime: `${booking.startTime} to ${booking.endTime}`,
      slotBasePrice: Number(booking.totalAmount),
      bookingId: booking.bookingReference,
      transactionId: payment?.transactionId ?? '',
      bank: bankAccount
        ? {
            accountHolderName: bankAccount.accountHolderName,
            bankName: bankAccount.bankName,
            accountNumber: this.maskAccountNumber(bankAccount.accountNumber),
            ifscCode: bankAccount.ifscCode,
            verified: bankAccount.status === BankAccountStatus.APPROVED,
          }
        : null,
    };
  }

  async getPayoutHistory(
    currentUser: { id: string; role: string },
    pagination: PaginationDto,
    status?: 'success' | 'pending' | 'failed',
  ) {
    const qb = this.paymentRepository
      .createQueryBuilder('payment')
      .innerJoinAndSelect('payment.booking', 'booking')
      .innerJoinAndSelect('booking.venue', 'venue')
      .where('venue.partnerId = :partnerId', { partnerId: currentUser.id })
      .orderBy('payment.updatedAt', 'DESC')
      .skip(pagination.skip)
      .take(pagination.limit);

    if (status === 'success') {
      qb.andWhere('payment.status = :s', { s: PaymentStatus.SUCCESS });
    } else if (status === 'pending') {
      qb.andWhere('payment.status IN (:...s)', { s: [PaymentStatus.PENDING, PaymentStatus.PROCESSING] });
    } else if (status === 'failed') {
      qb.andWhere('payment.status IN (:...s)', {
        s: [PaymentStatus.FAILED, PaymentStatus.REFUNDED, PaymentStatus.PARTIALLY_REFUNDED],
      });
    }

    const [payments, total] = await qb.getManyAndCount();

    const items = payments.map((payment) => {
      const { netReceived } = this.computeBreakdown(
        Number(payment.booking.totalAmount),
        Number(payment.booking.venue.commission ?? 10),
      );
      return {
        id: payment.booking.id,
        date: payment.booking.bookingDate,
        netReceived,
        status: this.mapPayoutStatus(payment.status),
      };
    });

    return {
      items,
      total,
      page: pagination.page,
      limit: pagination.limit,
      totalPages: Math.ceil(total / pagination.limit),
    };
  }

  async generatePayoutStatementPdf(
    bookingId: string,
    currentUser: { id: string; role: string },
  ): Promise<{ base64: string; filename: string; mimeType: string }> {
    const statement = await this.getPayoutStatement(bookingId, currentUser);

    const templateFile = statement.isGstRegistered
      ? 'transaction-statement-gst.pdf'
      : 'transaction-statement-non-gst.pdf';
    const templatePath = path.join(__dirname, '..', 'legal', 'templates', templateFile);
    const templateBytes = fs.readFileSync(templatePath);
    const templateDoc = await PDFDocument.load(templateBytes);

    const outDoc = await PDFDocument.create();
    const [page] = await outDoc.copyPages(templateDoc, [0]);
    outDoc.addPage(page);
    const font = await outDoc.embedFont(StandardFonts.Helvetica);
    const boldFont = await outDoc.embedFont(StandardFonts.HelveticaBold);

    const money = (v: number) => `Rs. ${v.toFixed(2)}`;
    const statusLabel = statement.status.charAt(0).toUpperCase() + statement.status.slice(1);
    const payoutDateLabel = statement.payoutDate
      ? new Date(statement.payoutDate).toLocaleString('en-IN', {
          day: '2-digit', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit',
        })
      : '-';

    const draw = (
      text: string, x: number, boxY: number, boxW: number, boxH: number, textY: number,
      bold = false, size = 11,
    ) => {
      page.drawRectangle({ x, y: boxY, width: boxW, height: boxH, color: rgb(1, 1, 1) });
      page.drawText(text, { x: x + 3, y: textY, size, font: bold ? boldFont : font, color: rgb(0.12, 0.12, 0.12) });
    };

    // Payout Breakdown (right column)
    draw(money(statement.grossBookingAmount), 470, 546.36, 95, 20, 552.36);
    draw(money(statement.activCommission),    470, 519.38, 95, 20, 525.38);
    draw(money(statement.gstOnCommission),    470, 492.29, 95, 20, 498.29);
    draw(money(statement.netReceived),        470, 463.01, 95, 20, 469.01, true);

    // Transaction Details summary (left column)
    draw(statusLabel,                     82, 546.36,  42, 20, 552.1, true, 10);
    draw(money(statement.amountReceived), 40, 503.49, 240, 20, 509.49, true);
    draw(payoutDateLabel,                 40, 462.21, 240, 20, 468.21);

    // Transaction & Slot Details
    draw(statement.activityName,         438, 405.16, 127, 16, 410.16);
    draw(statement.slotDate,             438, 381.16, 127, 16, 386.16);
    draw(statement.slotTime,             438, 357.16, 127, 16, 362.16);
    draw(money(statement.slotBasePrice), 438, 333.16, 127, 16, 338.16);
    draw(statement.bookingId,            438, 309.16, 127, 16, 314.16, false, 10);
    draw(statement.transactionId,        438, 285.17, 127, 16, 290.17, false, 10);

    // Credited Bank Account Details
    draw(statement.bank?.accountHolderName ?? '-',              470, 224.20, 95, 16, 229.20);
    draw(statement.bank?.bankName ?? '-',                       470, 200.20, 95, 16, 205.20);
    draw(statement.bank?.accountNumber ?? '-',                  470, 176.20, 95, 16, 181.20);
    draw(statement.bank?.ifscCode ?? '-',                       470, 152.20, 106, 16, 157.20);
    draw(statement.bank?.verified ? 'Verified' : 'Unverified',  470, 128.20, 106, 16, 133.20);

    const pdfBytes = await outDoc.save();
    return {
      base64: Buffer.from(pdfBytes).toString('base64'),
      filename: `ACTIV_Transaction_${statement.transactionId || statement.bookingId}.pdf`,
      mimeType: 'application/pdf',
    };
  }
}
