import { Injectable } from '@nestjs/common';
import type { Prisma } from '../../generated/prisma/client';
import { IsEnum, IsOptional } from 'class-validator';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { PrismaService } from '../../prisma/prisma.service';
import { computeBookingCommission } from '../commission/booking-commission';

export enum TransactionView {
  Payments = 'payments',
  Refunds = 'refunds',
  Commissions = 'commissions',
  Payouts = 'payouts',
}

export class AdminTransactionsQuery extends PaginationDto {
  @IsOptional()
  @IsEnum(TransactionView)
  view: TransactionView = TransactionView.Payments;
}

const bookingSelect = {
  booking_reference: true,
  total_paise: true,
  users: { select: { id: true, name: true } },
  slots: { select: { facilities: { select: { venues: { select: {
    id: true,
    name: true,
    commission_percent: true,
    partners: { select: { legal_name: true } },
  } } } } } },
} satisfies Prisma.bookingsSelect;

type Booking = Prisma.bookingsGetPayload<{ select: typeof bookingSelect }>;

function bookingDetails(booking: Booking) {
  const venue = booking.slots.facilities.venues;
  return {
    bookingReference: booking.booking_reference,
    customer: booking.users.name || booking.users.id,
    venueId: venue.id,
    venueName: venue.name,
    partner: venue.partners.legal_name,
  };
}

@Injectable()
export class AdminTransactionsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(query: AdminTransactionsQuery) {
    const page = query.page ?? 1;
    const limit = Math.min(query.limit ?? 10, 100);
    const pagination = { skip: (page - 1) * limit, take: limit };
    const result = await this.findRecords(query.view, pagination);
    return { ...result, page, limit, totalPages: Math.ceil(result.total / limit) };
  }

  private async findRecords(view: TransactionView, pagination: { skip: number; take: number }) {
    if (view === TransactionView.Payouts) {
      const [payouts, total] = await Promise.all([
        this.prisma.partner_payouts.findMany({
          ...pagination,
          orderBy: [{ payout_date: 'desc' }, { id: 'desc' }],
          select: {
            id: true, reference: true, amount_paise: true, status: true, payout_date: true,
            partners: { select: { legal_name: true } },
          },
        }),
        this.prisma.partner_payouts.count(),
      ]);
      return { total, items: payouts.map(payout => ({
        id: payout.id, reference: payout.reference, amount: Number(payout.amount_paise) / 100,
        currency: 'INR', status: payout.status, date: payout.payout_date, partner: payout.partners.legal_name,
      })) };
    }

    if (view === TransactionView.Refunds) {
      const [refunds, total] = await Promise.all([
        this.prisma.refunds.findMany({
          ...pagination,
          orderBy: [{ created_at: 'desc' }, { id: 'desc' }],
          select: {
            id: true, provider_ref: true, amount_paise: true, status: true, created_at: true,
            payments: { select: { currency: true, provider: true } },
            bookings: { select: bookingSelect },
          },
        }),
        this.prisma.refunds.count(),
      ]);
      return { total, items: refunds.map(refund => ({
        ...bookingDetails(refund.bookings),
        id: refund.id, reference: refund.provider_ref ?? refund.id, amount: Number(refund.amount_paise) / 100,
        currency: refund.payments.currency ?? 'INR', provider: refund.payments.provider,
        status: refund.status, date: refund.created_at,
      })) };
    }

    const showCommission = view === TransactionView.Commissions;
    const where: Prisma.paymentsWhereInput = showCommission ? { status: 'CAPTURED' } : {};
    const [payments, total] = await Promise.all([
      this.prisma.payments.findMany({
        ...pagination,
        where,
        orderBy: [{ created_at: 'desc' }, { id: 'desc' }],
        select: {
          id: true, provider: true, provider_order_id: true, provider_payment_id: true,
          amount_paise: true, currency: true, status: true, created_at: true,
          bookings: { select: bookingSelect },
        },
      }),
      this.prisma.payments.count({ where }),
    ]);
    return { total, items: payments.map(payment => ({
      ...bookingDetails(payment.bookings),
      id: payment.id, reference: payment.provider_payment_id ?? payment.provider_order_id ?? payment.id,
      amount: Number(payment.amount_paise) / 100, currency: payment.currency ?? 'INR',
      status: payment.status, provider: payment.provider, date: payment.created_at,
      ...(showCommission ? {
        commission: computeBookingCommission(
          Number(payment.bookings.total_paise) / 100,
          Number(payment.bookings.slots.facilities.venues.commission_percent ?? 5),
        ),
      } : {}),
    })) };
  }
}
