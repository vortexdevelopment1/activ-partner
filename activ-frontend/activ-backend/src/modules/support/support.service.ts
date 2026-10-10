import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CallbackRequest } from './entities/callback-request.entity';
import { SupportEmail } from './entities/support-email.entity';
import { CreateCallbackRequestDto } from './dto/create-callback-request.dto';
import { UpdateCallbackRequestDto } from './dto/update-callback-request.dto';
import { CreateSupportEmailDto } from './dto/create-support-email.dto';
import { UpdateSupportEmailDto } from './dto/update-support-email.dto';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { CallbackStatus } from '../../common/enums/callback-status.enum';
import { MailService } from '../mail/mail.service';

@Injectable()
export class SupportService {
  constructor(
    @InjectRepository(CallbackRequest)
    private readonly callbackRepo: Repository<CallbackRequest>,
    @InjectRepository(SupportEmail)
    private readonly emailRepo: Repository<SupportEmail>,
    private readonly mailService: MailService,
  ) {}

  async createCallback(dto: CreateCallbackRequestDto, partnerId?: string): Promise<CallbackRequest> {
    const request = this.callbackRepo.create({ ...dto, partnerId });
    const saved = await this.callbackRepo.save(request);

    await this.mailService.sendCallbackRequestEmail({
      partnerName: dto.partnerName,
      partnerEmail: dto.email,
      phone: dto.phone,
      venueName: dto.venueName,
      city: dto.city,
      callbackDate: dto.callbackDate,
      callbackTime: dto.callbackTime,
      query: dto.query,
    });

    return saved;
  }

  async findAll(
    pagination: PaginationDto,
    status?: CallbackStatus,
  ): Promise<[CallbackRequest[], number]> {
    const qb = this.callbackRepo.createQueryBuilder('cb').orderBy('cb.createdAt', 'DESC');

    if (status) {
      qb.andWhere('cb.status = :status', { status });
    }

    if (pagination.search) {
      qb.andWhere(
        '(cb.partnerName ILIKE :search OR cb.email ILIKE :search OR cb.phone ILIKE :search OR cb.venueName ILIKE :search)',
        { search: `%${pagination.search}%` },
      );
    }

    qb.skip(pagination.skip).take(pagination.limit);

    return qb.getManyAndCount();
  }

  async findOne(id: string): Promise<CallbackRequest> {
    const request = await this.callbackRepo.findOne({ where: { id } });
    if (!request) throw new NotFoundException('Callback request not found');
    return request;
  }

  async update(id: string, dto: UpdateCallbackRequestDto): Promise<CallbackRequest> {
    const request = await this.findOne(id);
    Object.assign(request, dto);
    return this.callbackRepo.save(request);
  }

  async remove(id: string): Promise<void> {
    const request = await this.findOne(id);
    await this.callbackRepo.remove(request);
  }

  // ─── Support Email ────────────────────────────────────────────────────────

  async createEmail(
    dto: CreateSupportEmailDto,
    partnerId: string,
    file?: Express.Multer.File,
  ): Promise<SupportEmail> {
    const attachmentUrl = file
      ? `${process.env.APP_URL || ''}/uploads/support-attachments/${file.filename}`
      : null;
    const attachmentOriginalName = file ? file.originalname : null;

    const email = this.emailRepo.create({
      ...dto,
      partnerId,
      attachmentUrl,
      attachmentOriginalName,
    });
    return this.emailRepo.save(email);
  }

  async findAllEmails(
    pagination: PaginationDto,
    status?: CallbackStatus,
  ): Promise<[SupportEmail[], number]> {
    const qb = this.emailRepo.createQueryBuilder('se').orderBy('se.createdAt', 'DESC');

    if (status) {
      qb.andWhere('se.status = :status', { status });
    }

    if (pagination.search) {
      qb.andWhere('(se.subject ILIKE :search OR se.message ILIKE :search)', {
        search: `%${pagination.search}%`,
      });
    }

    qb.skip(pagination.skip).take(pagination.limit);
    return qb.getManyAndCount();
  }

  async findOneEmail(id: string): Promise<SupportEmail> {
    const email = await this.emailRepo.findOne({ where: { id } });
    if (!email) throw new NotFoundException('Support email not found');
    return email;
  }

  async updateEmail(id: string, dto: UpdateSupportEmailDto): Promise<SupportEmail> {
    const email = await this.findOneEmail(id);
    Object.assign(email, dto);
    return this.emailRepo.save(email);
  }

  async removeEmail(id: string): Promise<void> {
    const email = await this.findOneEmail(id);
    await this.emailRepo.remove(email);
  }
}
