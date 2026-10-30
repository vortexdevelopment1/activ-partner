import { randomUUID } from 'crypto';
import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
} from "@nestjs/common";
import * as fs from "fs";
import * as path from "path";
import { PDFDocument, StandardFonts, rgb } from "pdf-lib";
import { PaymentStatus } from "../../common/enums/booking-status.enum";
import { CreateBookingDto } from "./dto/create-booking.dto";
import { BookingStatus } from "../../common/enums/booking-status.enum";
import { UserRole } from "../../common/enums/user-role.enum";
import { PaginationDto } from "../../common/dto/pagination.dto";
import type { UserRecord as User } from '../../common/domain-types';
import { PrismaService } from "../../prisma/prisma.service";
import { BookingPayoutQueryDto } from "./dto/booking-payout-query.dto";
import { bookingHasEnded } from './booking-expiry';
import { LegacySlotResolver } from './legacy-slot-resolver';
import { NormalizedBookingHoldService } from './normalized-booking-hold.service';
import { buildLegacyIdempotencyContext } from './legacy-idempotency';
import { lockSlotsForCapacity } from './slot-capacity-coordinator';

// ACTIV Commission GST rate — fixed for the MVP settlement model (not configurable).
const GST_ON_COMMISSION_RATE = 0.18;

@Injectable()
export class BookingsService {
  private readonly normalizedHoldService = new NormalizedBookingHoldService();
  constructor(
    private readonly prisma: PrismaService,
  ) {}

  private calculateDuration(startTime: string, endTime: string): number {
    const [startH, startM] = startTime.split(":").map(Number);
    const [endH, endM] = endTime.split(":").map(Number);
    return endH * 60 + endM - (startH * 60 + startM);
  }

  private calculateAmount(
    pricePerHour: number,
    durationMinutes: number,
  ): number {
    return (pricePerHour / 60) * durationMinutes;
  }

  /**
   * Inactive replacement for POST /bookings. The controller deliberately does
   * not call this until all competing writers are cut over. A stable key is
   * mandatory for this normalized path; legacy requests without one remain on
   * the existing implementation and are not advertised as retry-idempotent.
   */
  async createNormalizedFromLegacy(
    createBookingDto: CreateBookingDto,
    userId: string,
    idempotencyKey: string | undefined,
    timezone = 'Asia/Kolkata',
  ) {
    const resolver = new LegacySlotResolver(this.prisma);
    const resolved = await resolver.resolve(createBookingDto, timezone);
    const identity = buildLegacyIdempotencyContext(createBookingDto, userId, resolved.slotId, { 'idempotency-key': idempotencyKey });
    if (!identity.key) throw new ConflictException('Normalized booking requires an Idempotency-Key header');

    const pending = await this.prisma.$transaction(async tx => {
      const hold = await this.normalizedHoldService.createHold(
        tx,
        userId,
        resolved.slotId,
        identity.key!,
        1,
        10,
        new Date(),
        { venueId: resolved.venueId, serviceId: resolved.serviceId },
      );
      return this.normalizedHoldService.finalizeHoldToPendingBooking(tx, hold.id, new Date(), hold.expiresAt);
    });
    const record = await this.prisma.bookings.findUnique({
      where: { id: pending.id },
      include: this.normalizedBookingInclude,
    });
    if (!record) throw new NotFoundException('Booking was not created');
    return this.mapNormalizedBooking(record);
  }

  private readonly normalizedBookingInclude = {
    users: true,
    slots: {
      include: {
        facilities: {
          include: { venues: true, activities: true, partner_venue_services: true },
        },
      },
    },
    payments: { orderBy: { created_at: 'desc' as const }, take: 1 },
  } as const;

  private mapNormalizedBooking(record: any) {
    const slot = record.slots;
    const facility = slot.facilities;
    const service = facility.partner_venue_services?.[0] ?? null;
    const formatTime = (value: Date) => new Intl.DateTimeFormat('en-IN', {
      timeZone: 'Asia/Kolkata', hour: '2-digit', minute: '2-digit', hour12: true,
    }).format(value);
    const formatDate = (value: Date) => new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit',
    }).format(value);
    const status = String(record.status).toLowerCase() === 'pending_payment'
      ? BookingStatus.PENDING
      : String(record.status).toLowerCase() as BookingStatus;
    const paymentStatus = record.payments?.[0]?.status;
    return {
      id: record.id,
      userId: record.user_id,
      user: record.users,
      venueId: facility.venue_id,
      venue: facility.venues,
      serviceId: service?.id ?? facility.activity_id,
      service: service ? {
        id: service.id,
        name: service.title,
        venueId: service.venue_id,
        isActive: service.is_active,
      } : { id: facility.activity_id, name: facility.activities?.name ?? facility.name, venueId: facility.venue_id },
      categoryId: service?.service_category_id ?? null,
      bookingDate: formatDate(slot.starts_at),
      startTime: formatTime(slot.starts_at),
      endTime: formatTime(slot.ends_at),
      durationMinutes: Math.round((slot.ends_at.getTime() - slot.starts_at.getTime()) / 60000),
      totalAmount: Number(record.total_paise) / 100,
      subtotalAmount: Number(record.subtotal_paise) / 100,
      discountAmount: Number(record.discount_paise) / 100,
      status,
      paymentStatus: paymentStatus ? String(paymentStatus).toLowerCase() : null,
      cancellationReason: null,
      notes: null,
      bookingReference: record.booking_reference,
      createdAt: record.created_at,
      updatedAt: record.updated_at,
    };
  }

  // Convert "09:00 AM" / "09:00 PM" → total minutes since midnight
  private to24hMinutes(time12h: string): number {
    const [timePart, meridiem] = time12h.trim().split(" ");
    let [h, m] = timePart.split(":").map(Number);
    if (meridiem?.toUpperCase() === "PM" && h !== 12) h += 12;
    if (meridiem?.toUpperCase() === "AM" && h === 12) h = 0;
    return h * 60 + m;
  }

  // Convert "10:00" (24h HH:mm) → total minutes since midnight
  private hhmm24ToMinutes(time24h: string): number {
    const [h, m] = time24h.split(":").map(Number);
    return h * 60 + m;
  }

  /**
   * Resolve the per-slot price from the venue's availability JSONB.
   * Looks up categoryId → day → slot that contains startTime.
   * Returns { price, discountedPrice } from the matching slot.
   * Falls back to { price: fallbackPricePerHour, discountedPrice: 0 } if no match.
   */
  private resolveSlotPrice(
    venue: any,
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
    const dayName = new Date(bookingDate)
      .toLocaleDateString("en-US", { weekday: "long" })
      .toLowerCase();
    const dayEntry = categorySchedule.find(
      (d) => d.day.toLowerCase() === dayName,
    );
    if (!dayEntry?.slots?.length) return fallback;

    const startMinutes = this.hhmm24ToMinutes(startTime);

    const matchedSlot = dayEntry.slots.find((slot) => {
      const slotOpen = this.to24hMinutes(slot.openTime);
      const slotClose = this.to24hMinutes(slot.closeTime);
      return startMinutes >= slotOpen && startMinutes < slotClose;
    });

    if (!matchedSlot) return fallback;

    return {
      price: Number(matchedSlot.price) || fallbackPricePerHour,
      discountedPrice: Number(matchedSlot.discountedPrice) || 0,
    };
  }

  private resolveNormalizedSlotPrice(
    rows: Array<{
      day: string;
      open_time: string;
      close_time: string;
      price_paise: bigint;
      discounted_price_paise: bigint;
    }>,
    bookingDate: string,
    startTime: string,
    fallbackPricePerHour: number,
  ): { price: number; discountedPrice: number } {
    const dayName = new Date(bookingDate)
      .toLocaleDateString("en-US", { weekday: "long" })
      .toLowerCase();
    const startMinutes = this.to24hMinutes(startTime);
    const matched = rows.find(
      (row) =>
        row.day.toLowerCase() === dayName &&
        startMinutes >= this.to24hMinutes(row.open_time) &&
        startMinutes < this.to24hMinutes(row.close_time),
    );
    if (!matched) return { price: fallbackPricePerHour, discountedPrice: 0 };
    return {
      price: Number(matched.price_paise) / 100 || fallbackPricePerHour,
      discountedPrice: Number(matched.discounted_price_paise) / 100 || 0,
    };
  }

  async create(
    createBookingDto: CreateBookingDto,
    userId: string,
  ): Promise<any> {
    return this.createNormalizedFromLegacy(
      createBookingDto,
      userId,
      `legacy:${userId}:${createBookingDto.venueId}:${createBookingDto.serviceId}:${createBookingDto.bookingDate}:${createBookingDto.startTime}`,
    );
  }

  async findAll(pagination: PaginationDto, status?: BookingStatus) {
    const normalizedStatus = status === BookingStatus.PENDING ? 'PENDING_PAYMENT' : status?.toUpperCase();
    const where = normalizedStatus ? { status: normalizedStatus as any } : {};
    const [items, total] = await Promise.all([
      this.prisma.bookings.findMany({ where, include: this.normalizedBookingInclude, skip: pagination.skip, take: pagination.limit, orderBy: { created_at: 'desc' } }),
      this.prisma.bookings.count({ where }),
    ]);
    return [items.map((item) => this.mapNormalizedBooking(item)), total] as const;
  }

  async findByUser(
    userId: string,
    pagination: PaginationDto,
    status?: BookingStatus,
  ) {
    const normalizedStatus = status === BookingStatus.PENDING ? 'PENDING_PAYMENT' : status?.toUpperCase();
    const where: any = { user_id: userId };
    if (normalizedStatus) where.status = normalizedStatus;
    const [items, total] = await Promise.all([
      this.prisma.bookings.findMany({ where, include: this.normalizedBookingInclude, skip: pagination.skip, take: pagination.limit, orderBy: { created_at: 'desc' } }),
      this.prisma.bookings.count({ where }),
    ]);
    return [items.map((item) => this.mapNormalizedBooking(item)), total] as const;
  }

  async findByVenue(
    venueId: string,
    pagination: PaginationDto,
    status?: BookingStatus,
  ) {
    const normalizedStatus = status === BookingStatus.PENDING ? 'PENDING_PAYMENT' : status?.toUpperCase();
    const where: any = { slots: { facilities: { venue_id: venueId } } };
    if (normalizedStatus) where.status = normalizedStatus;
    const [items, total] = await Promise.all([
      this.prisma.bookings.findMany({ where, include: this.normalizedBookingInclude, skip: pagination.skip, take: pagination.limit, orderBy: { starts_at: 'desc' } }),
      this.prisma.bookings.count({ where }),
    ]);
    return [items.map((item) => this.mapNormalizedBooking(item)), total] as const;
  }

  async findOneForRead(id: string) {
    const booking = await this.prisma.bookings.findUnique({
      where: { id }, include: this.normalizedBookingInclude,
    });
    if (!booking) throw new NotFoundException(`Booking with id ${id} not found`);
    return this.mapNormalizedBooking(booking);
  }

  async findOne(id: string): Promise<any> {
    const booking = await this.prisma.bookings.findUnique({
      where: { id },
      include: this.normalizedBookingInclude,
    });
    if (!booking) throw new NotFoundException(`Booking with id ${id} not found`);
    return this.mapNormalizedBooking(booking);
  }

  async findByReference(reference: string): Promise<any> {
    const normalizedReference = reference.trim().toUpperCase();
    const booking = await this.prisma.bookings.findUnique({
      where: { booking_reference: normalizedReference },
      include: this.normalizedBookingInclude,
    });

    if (!booking) {
      throw new NotFoundException(
        `Booking with reference ${normalizedReference} not found`,
      );
    }

    return this.mapNormalizedBooking(booking);
  }

  async cancel(
    id: string,
    reason: string,
    currentUser: User,
  ): Promise<any> {
    return this.cancelNormalized(id, reason, currentUser);
  }

  /** Default-off normalized cancellation path; legacy cancellation remains authoritative. */
  private async cancelNormalized(id: string, reason: string, currentUser: User) {
    return this.prisma.$transaction(async tx => {
      const booking = await tx.bookings.findUnique({ where: { id }, include: { slots: true } });
      if (!booking) throw new NotFoundException('Booking not found');
      if (currentUser.role === UserRole.USER && booking.user_id !== currentUser.id) {
        throw new ForbiddenException('You can only cancel your own bookings');
      }
      if (booking.status === 'CANCELLED') throw new BadRequestException('Booking is already cancelled');
      if (booking.status === 'COMPLETED') throw new BadRequestException('Cannot cancel a completed booking');
      await lockSlotsForCapacity(tx, [booking.slot_id]);
      await tx.$queryRaw`SELECT id FROM bookings WHERE id = ${booking.id}::uuid FOR UPDATE`;
      const updated = await tx.bookings.updateMany({
        where: { id, status: { not: 'CANCELLED' } },
        data: { status: 'CANCELLED', updated_at: new Date() },
      });
      if (updated.count !== 1) throw new ConflictException('Booking changed during cancellation');
      if (booking.attempt_id) {
        await tx.booking_attempts.updateMany({
          where: { id: booking.attempt_id, status: { in: ['HELD', 'PAYMENT_PROCESSING', 'CONSUMED'] } },
          data: { status: 'RELEASED', updated_at: new Date() },
        });
      }
      const record = await tx.bookings.findUnique({ where: { id }, include: this.normalizedBookingInclude });
      if (!record) throw new NotFoundException('Booking not found');
      return this.mapNormalizedBooking(record);
    });
  }

  async confirm(id: string): Promise<never> {
    throw new ConflictException('Administrative confirmation is blocked: only verified payment capture may confirm a booking');
  }

  async complete(id: string, partnerId?: string) {
    return this.updateAttendance(id, partnerId, 'complete');
  }

  async checkIn(bookingId: string, partnerUserId: string) {
    if (!partnerUserId) throw new ForbiddenException('Partner identity is required');
    return this.updateAttendance(bookingId, partnerUserId, 'check-in');
  }

  async markNoShow(bookingId: string, partnerUserId: string) {
    if (!partnerUserId) throw new ForbiddenException('Partner identity is required');
    return this.updateAttendance(bookingId, partnerUserId, 'no-show');
  }

  private async updateAttendance(id: string, ownerId: string | undefined,
    action: 'check-in' | 'no-show' | 'complete') {
    return this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${'booking-attendance:' + id}))`;
      const walkIn = await tx.partner_walk_in_reservations.findUnique({
        where: { id }, include: { venues: { select: { partner_id: true } } },
      });
      const status = action === 'check-in' ? 'ongoing' : action === 'no-show' ? 'no_show' : 'completed';
      if (walkIn) {
        if (ownerId !== undefined && walkIn.venues.partner_id !== ownerId)
          throw new ForbiddenException('Not authorized to manage this booking');
        const result = { id, status, source: 'WALK_IN' };
        if ((walkIn.status === 'NO_SHOW' && action === 'no-show') ||
            (walkIn.status === 'COMPLETED' && action === 'complete')) return result;
        if (walkIn.status !== 'RESERVED')
          throw new BadRequestException('This booking can no longer be updated');
        const checkedIn = /^Checked-in: /m.test(walkIn.notes ?? '');
        if (action === 'check-in' && checkedIn) return result;
        if (action !== 'no-show' && !checkedIn && bookingHasEnded(walkIn.ends_at, new Date(), true))
          throw new BadRequestException('This slot has ended without check-in and is a no-show. Please refresh.');
        const updated = await tx.partner_walk_in_reservations.updateMany({
          where: { id, status: 'RESERVED' },
          data: {
            ...(action === 'no-show' ? { status: 'NO_SHOW' as const } :
                action === 'complete' ? { status: 'COMPLETED' as const } :
                { notes: [walkIn.notes, 'Checked-in: ' + new Date().toISOString()].filter(Boolean).join('\n') }),
            updated_at: new Date(),
          },
        });
        if (updated.count !== 1) throw new ConflictException('Booking changed. Please refresh and try again.');
        return result;
      }

      const booking = await tx.bookings.findUnique({ where: { id }, include: {
        slots: { include: { facilities: { include: { venues: { select: { partner_id: true } } } } } },
      } });
      if (!booking) throw new NotFoundException('Booking not found');
      if (ownerId !== undefined && booking.slots.facilities.venues.partner_id !== ownerId)
        throw new ForbiddenException('Not authorized to manage this booking');
      const result = { id, status, source: 'ACTIV' };
      if (booking.status === 'COMPLETED' && action === 'complete') return result;
      if (booking.status === 'NO_SHOW' && action === 'no-show') return result;
      if (booking.status !== 'CONFIRMED')
        throw new BadRequestException('Only confirmed bookings can be updated');
      const previous = await tx.booking_events.findFirst({
        where: { booking_id: id, to_status: { in: ['CHECKED_IN', 'NO_SHOW'] } },
        orderBy: { created_at: 'desc' },
      });
      if (previous?.to_status === 'NO_SHOW') {
        if (action === 'no-show') return result;
        throw new BadRequestException('Booking is already marked as no-show');
      }
      if ((previous?.to_status === 'CHECKED_IN' || booking.checked_in_at) && action === 'check-in') return result;
      if (action !== 'no-show' && previous?.to_status !== 'CHECKED_IN' && !booking.checked_in_at &&
          bookingHasEnded(booking.slots.ends_at))
        throw new BadRequestException('This slot has ended without check-in and is a no-show. Please refresh.');
      const updated = await tx.bookings.updateMany({
        where: { id, status: 'CONFIRMED' },
        data: { updated_at: new Date(), ...(action === 'complete' ? { status: 'COMPLETED' as const } : {}) },
      });
      if (updated.count !== 1) throw new ConflictException('Booking changed. Please refresh and try again.');
      await tx.booking_events.create({ data: {
        id: randomUUID(), booking_id: id, actor_id: ownerId ?? null,
        from_status: previous?.to_status ?? booking.status,
        to_status: action === 'check-in' ? 'CHECKED_IN' : action === 'no-show' ? 'NO_SHOW' : 'COMPLETED',
        metadata: { type: 'partner_attendance' },
      } });
      return result;
    });
  }

  async getBookingStats(partnerId?: string) {
    const scope: any = partnerId
      ? { slots: { facilities: { venues: { partner_id: partnerId } } } }
      : {};
    const [total, pending, confirmed, completed] = await Promise.all([
      this.prisma.bookings.count({ where: scope }),
      this.prisma.bookings.count({ where: { ...scope, status: 'PENDING_PAYMENT' } }),
      this.prisma.bookings.count({ where: { ...scope, status: 'CONFIRMED' } }),
      this.prisma.bookings.count({ where: { ...scope, status: 'COMPLETED' } }),
    ]);

    return { total, pending, confirmed, completed };
  }

  // ── Payout statement (Transaction Details screen) ─────────────────────────

  private mapPayoutStatus(
    status: PaymentStatus,
  ): "success" | "pending" | "failed" {
    if (status === PaymentStatus.SUCCESS) return "success";
    if (status === PaymentStatus.PENDING || status === PaymentStatus.PROCESSING)
      return "pending";
    return "failed";
  }

  private mapCurrentPayoutStatus(
    status: string,
  ): "success" | "pending" | "failed" {
    if (status === "CAPTURED") return "success";
    if (status === "CREATED" || status === "AUTHORIZED") return "pending";
    return "failed";
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

  async getPayoutStatement(
    bookingId: string,
    currentUser: { id: string; role: string },
  ) {
    const payment = await this.prisma.payments.findFirst({
      where: { booking_id: bookingId },
      include: {
        bookings: {
          include: {
            slots: {
              include: {
                facilities: { include: { venues: true, activities: true } },
              },
            },
          },
        },
      },
    });
    const booking = payment?.bookings;
    const venue = booking?.slots.facilities.venues;
    if (!payment || !booking || !venue)
      throw new NotFoundException("Booking not found");
    if (
      currentUser.role === UserRole.PARTNER &&
      venue.partner_id !== currentUser.id
    ) {
      throw new ForbiddenException(
        "You can only view payouts for your own venues",
      );
    }

    const { commissionPercent, activCommission, gstOnCommission, netReceived } =
      this.computeBreakdown(
        Number(booking.total_paise) / 100,
        Number(venue.commission_percent ?? 5),
      );

    const legal = await this.prisma.partner_venue_legal_documents.findUnique({
      where: { venue_id: venue.id },
    });
    const isGstRegistered = Boolean(legal?.gst_number && legal?.gstin_doc_url);

    const bankAccount = await this.prisma.partner_bank_accounts.findFirst({
      where: { partner_id: venue.partner_id, status: "APPROVED" },
      orderBy: { updated_at: "desc" },
    });

    // Settlement follows a T+7 cycle from when the payment succeeded.
    const payoutDate = payment.updated_at
      ? new Date(
          new Date(payment.updated_at).getTime() + 7 * 24 * 60 * 60 * 1000,
        )
      : null;
    const slot = booking.slots;

    return {
      status: this.mapCurrentPayoutStatus(payment.status),
      isGstRegistered,
      grossBookingAmount: Number(booking.total_paise) / 100,
      commissionPercent,
      activCommission,
      gstOnCommission,
      netReceived,
      amountReceived: netReceived,
      payoutDate,
      activityName: slot.facilities.activities.name,
      slotDate: slot.starts_at.toISOString().slice(0, 10),
      slotTime: `${slot.starts_at.toISOString().slice(11, 16)} to ${slot.ends_at.toISOString().slice(11, 16)}`,
      slotBasePrice: Number(booking.total_paise) / 100,
      bookingId: booking.booking_reference,
      transactionId:
        payment.provider_payment_id ?? payment.provider_order_id ?? "",
      bank: bankAccount
        ? {
            accountHolderName: bankAccount.account_holder_name,
            bankName: bankAccount.bank_name,
            accountNumber: this.maskAccountNumber(bankAccount.account_number),
            ifscCode: bankAccount.ifsc_code,
            verified: bankAccount.status === "APPROVED",
          }
        : null,
    };
  }

  async getPayoutHistory(
    currentUser: { id: string; role: string },
    query: BookingPayoutQueryDto,
  ) {
    const where: any = {
      bookings: {
        slots: { facilities: { venues: { partner_id: currentUser.id } } },
      },
    };
    if (query.startDate || query.endDate) {
      where.updated_at = {
        ...(query.startDate
          ? { gte: new Date(`${query.startDate}T00:00:00.000Z`) }
          : {}),
        ...(query.endDate
          ? { lte: new Date(`${query.endDate}T23:59:59.999Z`) }
          : {}),
      };
    }
    if (query.status === "success") where.status = "CAPTURED";
    if (query.status === "pending")
      where.status = { in: ["CREATED", "AUTHORIZED"] };
    if (query.status === "failed")
      where.status = {
        in: ["FAILED", "REFUND_PENDING", "REFUNDED", "EXCEPTION_REVIEW"],
      };

    const [payments, total] = await Promise.all([
      this.prisma.payments.findMany({
        where,
        include: {
          bookings: {
            include: {
              slots: { include: { facilities: { include: { venues: true } } } },
            },
          },
        },
        orderBy: { updated_at: "desc" },
        skip: query.skip,
        take: query.limit,
      }),
      this.prisma.payments.count({ where }),
    ]);

    const items = payments.map((payment) => {
      const { netReceived } = this.computeBreakdown(
        Number(payment.bookings.total_paise) / 100,
        Number(
          payment.bookings.slots.facilities.venues.commission_percent ?? 5,
        ),
      );
      return {
        id: payment.bookings.id,
        reference:
          payment.provider_payment_id ||
          payment.provider_order_id ||
          payment.bookings.booking_reference,
        date: payment.bookings.starts_at,
        payoutDate: payment.updated_at,
        amount: netReceived,
        netReceived,
        status: this.mapCurrentPayoutStatus(payment.status),
      };
    });

    return {
      items,
      total,
      page: query.page,
      limit: query.limit,
      totalPages: Math.ceil(total / query.limit),
    };
  }

  async generatePayoutStatementPdf(
    bookingId: string,
    currentUser: { id: string; role: string },
  ): Promise<{ base64: string; filename: string; mimeType: string }> {
    const statement = await this.getPayoutStatement(bookingId, currentUser);

    const templateFile = statement.isGstRegistered
      ? "transaction-statement-gst.pdf"
      : "transaction-statement-non-gst.pdf";
    const templatePath = path.join(
      __dirname,
      "..",
      "legal",
      "templates",
      templateFile,
    );
    const templateBytes = fs.readFileSync(templatePath);
    const templateDoc = await PDFDocument.load(templateBytes);

    const outDoc = await PDFDocument.create();
    const [page] = await outDoc.copyPages(templateDoc, [0]);
    outDoc.addPage(page);
    const font = await outDoc.embedFont(StandardFonts.Helvetica);
    const boldFont = await outDoc.embedFont(StandardFonts.HelveticaBold);

    const money = (v: number) => `Rs. ${v.toFixed(2)}`;
    const statusLabel =
      statement.status.charAt(0).toUpperCase() + statement.status.slice(1);
    const payoutDateLabel = statement.payoutDate
      ? new Date(statement.payoutDate).toLocaleString("en-IN", {
          day: "2-digit",
          month: "long",
          year: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        })
      : "-";

    const draw = (
      text: string,
      x: number,
      boxY: number,
      boxW: number,
      boxH: number,
      textY: number,
      bold = false,
      size = 11,
    ) => {
      page.drawRectangle({
        x,
        y: boxY,
        width: boxW,
        height: boxH,
        color: rgb(1, 1, 1),
      });
      page.drawText(text, {
        x: x + 3,
        y: textY,
        size,
        font: bold ? boldFont : font,
        color: rgb(0.12, 0.12, 0.12),
      });
    };

    // Payout Breakdown (right column)
    draw(money(statement.grossBookingAmount), 470, 546.36, 95, 20, 552.36);
    draw(money(statement.activCommission), 470, 519.38, 95, 20, 525.38);
    draw(money(statement.gstOnCommission), 470, 492.29, 95, 20, 498.29);
    draw(money(statement.netReceived), 470, 463.01, 95, 20, 469.01, true);

    // Transaction Details summary (left column)
    draw(statusLabel, 82, 546.36, 42, 20, 552.1, true, 10);
    draw(money(statement.amountReceived), 40, 503.49, 240, 20, 509.49, true);
    draw(payoutDateLabel, 40, 462.21, 240, 20, 468.21);

    // Transaction & Slot Details
    draw(statement.activityName, 438, 405.16, 127, 16, 410.16);
    draw(statement.slotDate, 438, 381.16, 127, 16, 386.16);
    draw(statement.slotTime, 438, 357.16, 127, 16, 362.16);
    draw(money(statement.slotBasePrice), 438, 333.16, 127, 16, 338.16);
    draw(statement.bookingId, 438, 309.16, 127, 16, 314.16, false, 10);
    draw(statement.transactionId, 438, 285.17, 127, 16, 290.17, false, 10);

    // Credited Bank Account Details
    draw(statement.bank?.accountHolderName ?? "-", 470, 224.2, 95, 16, 229.2);
    draw(statement.bank?.bankName ?? "-", 470, 200.2, 95, 16, 205.2);
    draw(statement.bank?.accountNumber ?? "-", 470, 176.2, 95, 16, 181.2);
    draw(statement.bank?.ifscCode ?? "-", 470, 152.2, 106, 16, 157.2);
    draw(
      statement.bank?.verified ? "Verified" : "Unverified",
      470,
      128.2,
      106,
      16,
      133.2,
    );

    const pdfBytes = await outDoc.save();
    return {
      base64: Buffer.from(pdfBytes).toString("base64"),
      filename: `ACTIV_Transaction_${statement.transactionId || statement.bookingId}.pdf`,
      mimeType: "application/pdf",
    };
  }
}
