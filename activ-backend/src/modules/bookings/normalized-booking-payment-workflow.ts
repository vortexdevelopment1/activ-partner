import { ConflictException } from '@nestjs/common';
import { CreateBookingDto } from './dto/create-booking.dto';
import { LegacySlotResolver } from './legacy-slot-resolver';
import { buildLegacyIdempotencyContext } from './legacy-idempotency';
import { NormalizedBookingHoldService } from './normalized-booking-hold.service';
import { NormalizedBookingPaymentService } from './normalized-booking-payment.service';
import { NormalizedRazorpayOrderService, RazorpayOrderClient } from '../payments/normalized-razorpay-order.service';

export class NormalizedBookingPaymentWorkflow {
  private readonly hold = new NormalizedBookingHoldService();
  private readonly payment = new NormalizedBookingPaymentService();
  private readonly orders = new NormalizedRazorpayOrderService();

  constructor(private readonly prisma: any) {}

  async createBookingAndOrder(input: { dto: CreateBookingDto; userId: string; idempotencyKey?: string; timezone: string; providerClient: RazorpayOrderClient }) {
    const resolved = await new LegacySlotResolver(this.prisma).resolve(input.dto, input.timezone);
    const identity = buildLegacyIdempotencyContext(input.dto, input.userId, resolved.slotId, { 'idempotency-key': input.idempotencyKey });
    if (!identity.key) throw new ConflictException('Normalized booking requires an Idempotency-Key header');
    const pending = await this.prisma.$transaction(async (tx: any) => {
      const hold = await this.hold.createHold(tx, input.userId, resolved.slotId, identity.key!, 1, 10, new Date(), { venueId: resolved.venueId, serviceId: resolved.serviceId });
      return this.hold.finalizeHoldToPendingBooking(tx, hold.id, new Date(), hold.expiresAt);
    });
    const persisted = await this.prisma.bookings.findUnique({ where: { id: pending.id }, select: { payment_deadline: true, total_paise: true } });
    if (!persisted) throw new ConflictException('Pending booking was not persisted');
    const order = await this.orders.createOrderWithProvider(this.prisma, {
      bookingId: pending.id, userId: input.userId, provider: 'razorpay', amountPaise: persisted.total_paise,
      currency: 'INR', paymentDeadline: persisted.payment_deadline, providerClient: input.providerClient,
    });
    return { booking: pending, order };
  }

  async confirmPayment(input: { bookingId: string; orderId: string; paymentId: string; signature: string; keySecret: string; expectedAmountPaise: bigint; currency: string; eventId?: string }) {
    return this.prisma.$transaction((tx: any) => this.payment.confirmRazorpayPayment(tx, input));
  }
}
