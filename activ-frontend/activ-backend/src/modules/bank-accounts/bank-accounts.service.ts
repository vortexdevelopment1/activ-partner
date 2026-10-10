import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BankAccount, BankAccountStatus } from './entities/bank-account.entity';
import { SubmitBankAccountDto } from './dto/submit-bank-account.dto';
import { ReviewBankAccountDto } from './dto/review-bank-account.dto';
import { PaginationDto } from '../../common/dto/pagination.dto';

@Injectable()
export class BankAccountsService {
  constructor(
    @InjectRepository(BankAccount)
    private readonly bankAccountRepository: Repository<BankAccount>,
  ) {}

  async submit(
    partnerId: string,
    dto: SubmitBankAccountDto,
    cancelledChequeUrl?: string,
  ): Promise<BankAccount> {
    // If a previous submission exists and is still under review, block re-submission
    const existing = await this.bankAccountRepository.findOne({
      where: { partnerId, status: BankAccountStatus.UNDER_REVIEW },
    });

    if (existing) {
      throw new BadRequestException(
        'You already have a bank account submission under review. Please wait for admin approval.',
      );
    }

    const bankAccount = this.bankAccountRepository.create({
      ...dto,
      partnerId,
      cancelledChequeUrl,
      status: BankAccountStatus.UNDER_REVIEW,
    });

    return this.bankAccountRepository.save(bankAccount);
  }

  async findAll(pagination: PaginationDto, status?: BankAccountStatus) {
    const qb = this.bankAccountRepository
      .createQueryBuilder('ba')
      .leftJoinAndSelect('ba.partner', 'partner')
      .orderBy('ba.createdAt', 'DESC')
      .skip(pagination.skip)
      .take(pagination.limit);

    if (status) qb.where('ba.status = :status', { status });

    const [items, total] = await qb.getManyAndCount();
    return [items, total] as [BankAccount[], number];
  }

  async findByPartner(partnerId: string): Promise<BankAccount[]> {
    return this.bankAccountRepository.find({
      where: { partnerId },
      order: { createdAt: 'DESC' },
    });
  }

  async findOne(id: string): Promise<BankAccount> {
    const record = await this.bankAccountRepository.findOne({
      where: { id },
      relations: ['partner'],
    });
    if (!record) throw new NotFoundException('Bank account record not found');
    return record;
  }

  async markVerifiedScreenSeen(id: string, partnerId: string): Promise<BankAccount> {
    const record = await this.bankAccountRepository.findOne({ where: { id, partnerId } });
    if (!record) throw new NotFoundException('Bank account record not found');
    record.hasSeenVerifiedScreen = true;
    return this.bankAccountRepository.save(record);
  }

  async review(
    id: string,
    dto: ReviewBankAccountDto,
    adminId: string,
  ): Promise<BankAccount> {
    const record = await this.findOne(id);

    if (record.status !== BankAccountStatus.UNDER_REVIEW) {
      throw new BadRequestException(
        `Cannot review a bank account that is already ${record.status}`,
      );
    }

    record.status       = dto.status;
    record.reviewedBy   = adminId;
    record.reviewedAt   = new Date();
    record.rejectionReason = dto.status === BankAccountStatus.REJECTED
      ? dto.rejectionReason
      : null;

    return this.bankAccountRepository.save(record);
  }
}
