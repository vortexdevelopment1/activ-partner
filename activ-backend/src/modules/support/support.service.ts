import { randomUUID } from 'crypto';
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
import { CloudinaryService } from '../cloudinary/cloudinary.service';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class SupportService {
  constructor(
    @InjectRepository(CallbackRequest)
    private readonly callbackRepo: Repository<CallbackRequest>,
    @InjectRepository(SupportEmail)
    private readonly emailRepo: Repository<SupportEmail>,
    private readonly mailService: MailService,
    private readonly cloudinaryService: CloudinaryService,
    private readonly prisma: PrismaService,
  ) {}

  async createCallback(dto: CreateCallbackRequestDto, partnerId?: string) {
    const preferredAt = this.callbackPreferredAt(
      dto.callbackDate,
      dto.callbackTime,
    );
    const saved = await this.prisma.partner_callback_requests.create({
      data: {
        id: randomUUID(),
        partner_id: partnerId ?? null,
        subject: `Callback request from ${dto.partnerName}`,
        notes: [
          `Partner: ${dto.partnerName}`,
          `Venue: ${dto.venueName}`,
          `City: ${dto.city}`,
          `Phone: ${dto.phone}`,
          `Email: ${dto.email}`,
          `Preferred date: ${dto.callbackDate}`,
          `Preferred time: ${dto.callbackTime}`,
          `Query: ${dto.query}`,
        ].join('\n'),
        preferred_at: preferredAt,
        updated_at: new Date(),
      },
    });

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

  private callbackPreferredAt(date: string, time: string): Date | null {
    const value = new Date(`${date} ${time}`);
    return Number.isNaN(value.getTime()) ? null : value;
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
    userId?: string,
    file?: Express.Multer.File,
  ) {
    const partnerUser = userId
      ? await this.prisma.partner_users.findFirst({
          where: { partner_id: partnerId, user_id: userId },
        })
      : await this.prisma.partner_users.findFirst({
          where: { partner_id: partnerId },
          orderBy: { id: 'asc' },
        });

    const uploaded = file
      ? await this.cloudinaryService.uploadFile(
          file,
          'activ/support-attachments',
          'auto',
        )
      : null;
    const attachments = uploaded
      ? [
          {
            url: uploaded,
            originalName: file?.originalname ?? null,
          },
        ]
      : [];

    return this.prisma.partner_support_requests.create({
      data: {
        id: randomUUID(),
        partner_id: partnerId,
        partner_user_id: partnerUser?.id ?? null,
        subject: dto.subject,
        message: dto.message,
        attachments,
        updated_at: new Date(),
      },
    });
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
