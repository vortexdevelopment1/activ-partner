import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { BankAccountStatus } from './entities/bank-account.entity';
import { SubmitBankAccountDto } from './dto/submit-bank-account.dto';
import { ReviewBankAccountDto } from './dto/review-bank-account.dto';
import { PaginationDto } from '../../common/dto/pagination.dto';

@Injectable()
export class BankAccountsService {
  constructor(private readonly prisma: PrismaService) {}

  private map(record: any) {
    const owner = record.partners?.partner_users?.[0]?.users;
    const names = (owner?.name || '').trim().split(/\s+/);
    return {
      id: record.id, partnerId: record.partner_id,
      accountHolderName: record.account_holder_name, bankName: record.bank_name,
      accountNumber: record.account_number, ifscCode: record.ifsc_code,
      accountType: record.account_type, branchName: record.branch_name,
      cancelledChequeUrl: record.cancelled_cheque_url,
      status: record.status.toLowerCase(), rejectionReason: record.rejection_reason,
      reviewedBy: record.reviewed_by, reviewedAt: record.reviewed_at,
      hasSeenVerifiedScreen: record.has_seen_verified_screen,
      createdAt: record.created_at, updatedAt: record.updated_at,
      ...(record.partners ? { partner: {
        id: record.partners.id,
        businessName: record.partners.partner_business_profiles?.business_name ?? record.partners.legal_name,
        firstName: names[0] || null, lastName: names.slice(1).join(' ') || null,
        email: owner?.email ?? record.partners.partner_business_profiles?.email,
        phone: owner?.phone_e164 ?? record.partners.partner_business_profiles?.phone_e164,
      } } : {}),
    };
  }

  async submit(partnerId: string, dto: SubmitBankAccountDto, cancelledChequeUrl?: string) {
    const existing = await this.prisma.partner_bank_accounts.findFirst({
      where: { partner_id: partnerId, status: 'UNDER_REVIEW' },
    });
    if (existing) throw new BadRequestException('You already have a bank account submission under review. Please wait for admin approval.');
    if (!cancelledChequeUrl) throw new BadRequestException('Please upload a cancelled cheque.');
    try {
      const record = await this.prisma.partner_bank_accounts.create({ data: {
        id: randomUUID(), partner_id: partnerId,
        account_holder_name: dto.accountHolderName.trim(), bank_name: dto.bankName.trim(),
        account_number: dto.accountNumber, ifsc_code: dto.ifscCode,
        account_type: dto.accountType, branch_name: dto.branchName?.trim() || null,
        cancelled_cheque_url: cancelledChequeUrl, status: 'UNDER_REVIEW', updated_at: new Date(),
      } });
      return this.map(record);
    } catch (error) {
      if (error.code === 'P2002') throw new BadRequestException('A bank account submission is already under review.');
      throw error;
    }
  }

  async findByPartner(partnerId: string) {
    const records = await this.prisma.partner_bank_accounts.findMany({
      where: { partner_id: partnerId }, orderBy: { created_at: 'desc' },
    });
    return records.map((record) => this.map(record));
  }

  async findAll(pagination: PaginationDto, status?: BankAccountStatus) {
    const where: any = status ? { status: status.toUpperCase() } : {};
    const [records, total] = await Promise.all([
      this.prisma.partner_bank_accounts.findMany({ where, skip: pagination.skip,
        take: pagination.limit, orderBy: { created_at: 'desc' },
        include: { partners: { include: { partner_business_profiles: true, partner_users: { include: { users: true } } } } } }),
      this.prisma.partner_bank_accounts.count({ where }),
    ]);
    return [records.map((record) => this.map(record)), total] as const;
  }

  async findOne(id: string, partnerId?: string) {
    const record = await this.prisma.partner_bank_accounts.findFirst({
      where: { id, ...(partnerId ? { partner_id: partnerId } : {}) },
      include: { partners: { include: { partner_business_profiles: true, partner_users: { include: { users: true } } } } },
    });
    if (!record) throw new NotFoundException('Bank account record not found');
    return this.map(record);
  }

  async markVerifiedScreenSeen(id: string, partnerId: string) {
    await this.findOne(id, partnerId);
    return this.map(await this.prisma.partner_bank_accounts.update({
      where: { id }, data: { has_seen_verified_screen: true, updated_at: new Date() },
    }));
  }

  async review(id: string, dto: ReviewBankAccountDto, adminId: string) {
    const record = await this.findOne(id);
    if (record.status !== BankAccountStatus.UNDER_REVIEW) {
      throw new BadRequestException(`Cannot review a bank account that is already ${record.status}`);
    }
    const updated = await this.prisma.partner_bank_accounts.updateMany({
      where: { id, status: 'UNDER_REVIEW' }, data: {
        status: dto.status === BankAccountStatus.APPROVED ? 'APPROVED' : 'REJECTED',
        reviewed_by: adminId, reviewed_at: new Date(), updated_at: new Date(),
        rejection_reason: dto.status === BankAccountStatus.REJECTED ? dto.rejectionReason : null,
      },
    });
    if (!updated.count) throw new BadRequestException('This account has already been reviewed.');
    return this.findOne(id);
  }

  async summary(partnerId: string) {
    const totals = await this.prisma.bookings.aggregate({
      where: { status: { in: ['CONFIRMED', 'COMPLETED'] },
        slots: { facilities: { venues: { partner_id: partnerId } } } },
      _sum: { total_paise: true },
    });
    const totalEarnings = Number(totals._sum.total_paise ?? 0) / 100;
    const credited = await this.prisma.partner_payouts.aggregate({
      where: { partner_id: partnerId, status: 'SUCCESS' }, _sum: { amount_paise: true },
    });
    return { totalEarnings, totalCredited: Number(credited._sum.amount_paise ?? 0) / 100 };
  }
}
