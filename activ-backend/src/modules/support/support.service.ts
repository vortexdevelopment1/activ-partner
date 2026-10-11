import { randomUUID } from 'crypto';
import { Injectable, NotFoundException } from '@nestjs/common';
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
  ): Promise<[any[], number]> {
    const where: any = {
      ...(status ? { status: this.toPartnerRequestStatus(status) } : {}),
      ...(pagination.search
        ? {
            OR: [
              { subject: { contains: pagination.search, mode: 'insensitive' } },
              { notes: { contains: pagination.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };
    const [items, total] = await Promise.all([
      this.prisma.partner_callback_requests.findMany({
        where,
        skip: pagination.skip,
        take: pagination.limit,
        orderBy: { created_at: 'desc' },
      }),
      this.prisma.partner_callback_requests.count({ where }),
    ]);
    return [items, total];
  }

  async findOne(id: string) {
    const request = await this.prisma.partner_callback_requests.findUnique({
      where: { id },
    });
    if (!request) throw new NotFoundException('Callback request not found');
    return request;
  }

  async update(id: string, dto: UpdateCallbackRequestDto) {
    await this.findOne(id);
    return this.prisma.partner_callback_requests.update({
      where: { id },
      data: {
        ...(dto.status ? { status: this.toPartnerRequestStatus(dto.status) } : {}),
        ...(dto.adminNotes ? { notes: dto.adminNotes } : {}),
        ...(dto.status === CallbackStatus.RESOLVED || dto.status === CallbackStatus.CLOSED
          ? { resolved_at: new Date() }
          : {}),
        updated_at: new Date(),
      },
    });
  }

  async remove(id: string): Promise<void> {
    await this.findOne(id);
    await this.prisma.partner_callback_requests.delete({ where: { id } });
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
  ): Promise<[any[], number]> {
    const where: any = {
      ...(status ? { status: this.toPartnerRequestStatus(status) } : {}),
      ...(pagination.search
        ? {
            OR: [
              { subject: { contains: pagination.search, mode: 'insensitive' } },
              { message: { contains: pagination.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };
    const [items, total] = await Promise.all([
      this.prisma.partner_support_requests.findMany({
        where,
        skip: pagination.skip,
        take: pagination.limit,
        orderBy: { created_at: 'desc' },
      }),
      this.prisma.partner_support_requests.count({ where }),
    ]);
    return [items, total];
  }

  async findOneEmail(id: string) {
    const email = await this.prisma.partner_support_requests.findUnique({
      where: { id },
    });
    if (!email) throw new NotFoundException('Support email not found');
    return email;
  }

  async updateEmail(id: string, dto: UpdateSupportEmailDto) {
    await this.findOneEmail(id);
    return this.prisma.partner_support_requests.update({
      where: { id },
      data: {
        ...(dto.status ? { status: this.toPartnerRequestStatus(dto.status) } : {}),
        ...(dto.adminNotes ? { message: dto.adminNotes } : {}),
        ...(dto.status === CallbackStatus.RESOLVED || dto.status === CallbackStatus.CLOSED
          ? { resolved_at: new Date() }
          : {}),
        updated_at: new Date(),
      },
    });
  }

  async removeEmail(id: string): Promise<void> {
    await this.findOneEmail(id);
    await this.prisma.partner_support_requests.delete({ where: { id } });
  }

  private toPartnerRequestStatus(status: CallbackStatus) {
    return status.toUpperCase() as any;
  }
}
