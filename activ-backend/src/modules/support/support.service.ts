import { randomUUID } from 'crypto';
import { Injectable, NotFoundException } from '@nestjs/common';
import { CreateCallbackRequestDto } from './dto/create-callback-request.dto';
import { UpdateCallbackRequestDto } from './dto/update-callback-request.dto';
import { CreateSupportEmailDto } from './dto/create-support-email.dto';
import { UpdateSupportEmailDto } from './dto/update-support-email.dto';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { CallbackStatus } from '../../common/enums/callback-status.enum';
import { MailService } from '../mail/mail.service';
import { PartnerEmailService } from '../mail/partner-email.service';
import { EmailTemplateId } from '../mail/templates/partner-email';
import { CloudinaryService } from '../cloudinary/cloudinary.service';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminNotificationsService } from '../admin-notifications/admin-notifications.service';
import { AdminNotificationType } from '../admin-notifications/entities/admin-notification.entity';

@Injectable()
export class SupportService {
  constructor(
    private readonly mailService: MailService,
    private readonly cloudinaryService: CloudinaryService,
    private readonly prisma: PrismaService,
    private readonly adminNotificationsService: AdminNotificationsService,
    private readonly partnerEmailService?: PartnerEmailService,
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

    await this.adminNotificationsService.notify(
      AdminNotificationType.CALLBACK_REQUESTED,
      'New callback request',
      `${dto.partnerName || 'A partner'} requested a callback.`,
      { callbackId: saved.id, ...(partnerId ? { partnerId } : {}) },
    );
    await this.mailService.sendCallbackRequestEmail({
      deliveryKey: `callback-support:${saved.id}`,
      partnerName: dto.partnerName,
      partnerEmail: dto.email,
      phone: dto.phone,
      venueName: dto.venueName,
      city: dto.city,
      callbackDate: dto.callbackDate,
      callbackTime: dto.callbackTime,
      query: dto.query,
    });
    await this.mailService.sendTemplateEmail?.(dto.email, 'callback_received', {
      deliveryKey: `callback-received:${saved.id}`,
      partnerName: dto.partnerName, venueName: dto.venueName, reference: saved.id,
      callbackDate: dto.callbackDate, callbackTime: dto.callbackTime,
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
    return [items.map((item) => this.mapCallbackRequest(item)), total];
  }

  async findOne(id: string) {
    const request = await this.prisma.partner_callback_requests.findUnique({
      where: { id },
    });
    if (!request) throw new NotFoundException('Callback request not found');
    return this.mapCallbackRequest(request);
  }

  async update(id: string, dto: UpdateCallbackRequestDto) {
    const current = await this.prisma.partner_callback_requests.findUnique({
      where: { id },
    });
    if (!current) throw new NotFoundException('Callback request not found');
    const updated = await this.prisma.partner_callback_requests.update({
      where: { id },
      data: {
        ...(dto.status ? { status: this.toPartnerRequestStatus(dto.status) } : {}),
        ...(dto.adminNotes !== undefined
          ? { notes: this.withAdminNotes(current.notes, dto.adminNotes) }
          : {}),
        ...(dto.status === CallbackStatus.RESOLVED || dto.status === CallbackStatus.CLOSED
          ? { resolved_at: new Date() }
          : {}),
        updated_at: new Date(),
      },
    });
    const mapped = this.mapCallbackRequest(updated);
    const template = this.statusTemplate('callback', updated.status);
    if (current.status !== updated.status && template) {
      await this.mailService.sendTemplateEmail?.(mapped.email, template, {
        deliveryKey: `callback-status:${id}:${updated.status}:${updated.updated_at?.toISOString?.()}`,
        partnerName: mapped.partnerName, venueName: mapped.venueName, reference: id,
        callbackDate: mapped.callbackDate, callbackTime: mapped.callbackTime,
      });
    }
    return mapped;
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
          include: { users: true },
        })
      : await this.prisma.partner_users.findFirst({
          where: { partner_id: partnerId },
          orderBy: { id: 'asc' },
          include: { users: true },
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

    const saved = await this.prisma.partner_support_requests.create({
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
    await this.adminNotificationsService.notify(
      AdminNotificationType.SUPPORT_REQUESTED,
      'New support request',
      'A partner submitted a support message.',
      { partnerId, supportRequestId: saved.id },
    );
    try {
      await this.mailService.sendSupportRequestEmail({
        deliveryKey: `support-internal:${saved.id}`,
        partnerName: partnerUser?.users?.name ?? 'Partner',
        partnerEmail: partnerUser?.users?.email,
        subject: dto.subject,
        message: dto.message,
      });
    } catch (error) {
      // Keep the support request successful even when mail credentials/provider
      // configuration is temporarily unavailable. The request is already saved
      // and remains visible to the admin support queue.
      console.error('Support request saved but email delivery failed; review email delivery records');
    }
    await this.partnerEmailService?.send(partnerId, 'support_received', { reference: saved.id, subject: dto.subject });
    return saved;
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
    const current = await this.findOneEmail(id);
    const updated = await this.prisma.partner_support_requests.update({
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
    const template = this.statusTemplate('support', updated.status);
    if (current.status !== updated.status && template) {
      await this.partnerEmailService?.send(current.partner_id, template, { reference: id, subject: current.subject,
        deliveryKey: `support-status:${id}:${updated.status}:${updated.updated_at?.toISOString?.()}` });
    }
    return updated;
  }

  private statusTemplate(kind: 'support' | 'callback', status: string): EmailTemplateId | undefined {
    const suffix = { IN_PROGRESS: 'in_progress', CONTACTED: 'in_progress', RESOLVED: 'resolved', CLOSED: 'cancelled', CANCELLED: 'cancelled' }[status];
    return suffix ? `${kind}_${suffix}` as EmailTemplateId : undefined;
  }

  async removeEmail(id: string): Promise<void> {
    await this.findOneEmail(id);
    await this.prisma.partner_support_requests.delete({ where: { id } });
  }

  private mapCallbackRequest(request: any) {
    const fields = this.parseCallbackNotes(request.notes);
    const preferredAt = request.preferred_at
      ? new Date(request.preferred_at)
      : null;
    return {
      id: request.id,
      partnerId: request.partner_id,
      partnerName: fields.Partner || this.nameFromSubject(request.subject),
      email: fields.Email || '',
      phone: fields.Phone || '',
      venueName: fields.Venue || '',
      city: fields.City || '',
      callbackDate:
        fields['Preferred date'] ||
        (preferredAt && !Number.isNaN(preferredAt.getTime())
          ? preferredAt.toISOString().slice(0, 10)
          : ''),
      callbackTime:
        fields['Preferred time'] ||
        (preferredAt && !Number.isNaN(preferredAt.getTime())
          ? preferredAt.toLocaleTimeString('en-IN', {
              hour: '2-digit',
              minute: '2-digit',
              hour12: true,
            })
          : ''),
      query: fields.Query || '',
      status: this.fromPartnerRequestStatus(request.status),
      adminNotes: fields.AdminNotes || null,
      createdAt: request.created_at,
      updatedAt: request.updated_at,
    };
  }

  private parseCallbackNotes(notes?: string | null): Record<string, string> {
    const result: Record<string, string> = {};
    const adminLines: string[] = [];
    for (const line of (notes || '').split('\n')) {
      const match = line.match(/^([^:]+):\s*(.*)$/);
      if (match) {
        result[match[1].trim()] = match[2].trim();
      } else if (line.trim()) {
        adminLines.push(line);
      }
    }
    if (adminLines.length) result.AdminNotes = adminLines.join('\n');
    return result;
  }

  private withAdminNotes(existingNotes: string | null | undefined, adminNotes: string) {
    const lines = (existingNotes || '')
      .split('\n')
      .filter((line) =>
        /^(Partner|Venue|City|Phone|Email|Preferred date|Preferred time|Query):/.test(line),
      );
    if (adminNotes.trim()) lines.push(adminNotes.trim());
    return lines.join('\n');
  }

  private nameFromSubject(subject?: string | null) {
    return (subject || '').replace(/^Callback request from\s+/i, '').trim();
  }

  private toPartnerRequestStatus(status: CallbackStatus) {
    if (status === CallbackStatus.CANCELLED) return 'CLOSED' as any;
    return status.toUpperCase() as any;
  }

  private fromPartnerRequestStatus(status: string) {
    if (status === 'CLOSED') return 'cancelled';
    if (status === 'CONTACTED') return 'in_progress';
    return status.toLowerCase();
  }
}
