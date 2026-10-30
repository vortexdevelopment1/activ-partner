import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
  UnauthorizedException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import type { PartnerRecord as Partner } from '../../common/domain-types';
import { GstVerificationRequestRecord as GstVerificationRequest, GstVerificationStatus } from '../../common/domain-types';
import { SubmitGstVerificationDto } from './dto/submit-gst-verification.dto';
import { ReviewGstVerificationDto } from './dto/review-gst-verification.dto';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { CreatePartnerDto } from './dto/create-partner.dto';
import { UpdatePartnerDto } from './dto/update-partner.dto';
import { AdminNotificationsService } from '../admin-notifications/admin-notifications.service';
import { AdminNotificationType } from '../../common/domain-types';
import { PrismaService } from '../../prisma/prisma.service';
import { deletePartnerAccount } from './delete-partner-account';
import { MailService } from '../mail/mail.service';
import { PartnerKycStatus, PartnerRole, PartnerStatus, UserStatus } from '../../generated/prisma/client';

@Injectable()
export class PartnersService {
  constructor(
    private readonly adminNotificationsService: AdminNotificationsService,
    private readonly prisma: PrismaService,
    private readonly mailService: MailService,
  ) {}

  async create(createPartnerDto: CreatePartnerDto): Promise<any> {
    if (!createPartnerDto.phone?.trim()) {
      throw new BadRequestException('Partner phone number is required');
    }

    const phone = this.normalizePhone(createPartnerDto.phone);
    const email = createPartnerDto.email?.trim().toLowerCase() || null;
    const fullName = [createPartnerDto.firstName, createPartnerDto.lastName]
      .map((value) => value?.trim())
      .filter(Boolean)
      .join(' ');
    const legalName = createPartnerDto.businessName?.trim() || fullName || 'Partner User';
    const now = new Date();

    try {
      const created = await this.prisma.$transaction(async (tx) => {
        const userWithPhone = await tx.users.findUnique({ where: { phone_e164: phone } });
        const userWithEmail = email
          ? await tx.users.findFirst({ where: { email: { equals: email, mode: 'insensitive' } } })
          : null;

        if (userWithEmail && userWithEmail.id !== userWithPhone?.id) {
          throw new ConflictException('A user with this email already exists');
        }

        if (userWithPhone) {
          const existingPartner = await tx.partner_users.findFirst({
            where: { user_id: userWithPhone.id },
          });
          if (existingPartner) {
            throw new ConflictException('A partner with this phone number already exists');
          }
        }

        const user = userWithPhone
          ? await tx.users.update({
              where: { id: userWithPhone.id },
              data: {
                name: fullName || userWithPhone.name,
                email: email || userWithPhone.email,
                status: UserStatus.ACTIVE,
                updated_at: now,
              },
            })
          : await tx.users.create({
              data: {
                id: randomUUID(),
                phone_e164: phone,
                name: fullName || null,
                email,
                status: UserStatus.ACTIVE,
                updated_at: now,
              },
            });

        const partnerId = randomUUID();
        const partner = await tx.partners.create({
          data: {
            id: partnerId,
            legal_name: legalName,
            status: PartnerStatus.PENDING,
            updated_at: now,
          },
        });
        await tx.partner_users.create({
          data: {
            id: randomUUID(),
            partner_id: partnerId,
            user_id: user.id,
            role: PartnerRole.PARTNER_ADMIN,
          },
        });
        await tx.partner_business_profiles.create({
          data: {
            id: randomUUID(),
            partner_id: partnerId,
            business_name: createPartnerDto.businessName?.trim() || null,
            owner_name: fullName || null,
            phone_e164: phone,
            email,
            pan_number: createPartnerDto.panNumber?.trim() || null,
            gst_number: createPartnerDto.gstNumber?.trim() || null,
            address_line_1: createPartnerDto.businessAddress?.trim() || null,
            city: createPartnerDto.city?.trim() || null,
            state: createPartnerDto.state?.trim() || null,
            postal_code: createPartnerDto.zipCode?.trim() || null,
            updated_at: now,
          },
        });

        return {
          id: partner.id,
          userId: user.id,
          firstName: createPartnerDto.firstName?.trim() || null,
          lastName: createPartnerDto.lastName?.trim() || null,
          email: user.email,
          phone: user.phone_e164,
          businessName: createPartnerDto.businessName?.trim() || partner.legal_name,
          status: partner.status.toLowerCase(),
          isActive: partner.status === PartnerStatus.ACTIVE,
          createdAt: partner.created_at,
          updatedAt: partner.updated_at,
        };
      });
      await this.adminNotificationsService.notify(
        AdminNotificationType.PARTNER_REGISTERED,
        'New partner created',
        `${created.businessName || 'A partner'} was added to ACTIV.`,
        { partnerId: created.id },
      );
      return created;
    } catch (error: any) {
      if (error instanceof ConflictException || error instanceof BadRequestException) throw error;
      if (error?.code === 'P2002') {
        throw new ConflictException('A partner with this phone number or email already exists');
      }
      throw error;
    }
  }

  private normalizePhone(phone: string): string {
    const digits = phone.replace(/\D/g, '');
    if (digits.length === 10) return `+91${digits}`;
    if (digits.length === 12 && digits.startsWith('91')) return `+${digits}`;
    if (digits.length < 10 || digits.length > 15) {
      throw new BadRequestException('Enter a valid phone number');
    }
    return `+${digits}`;
  }

  async findAll(pagination: PaginationDto) {
    const where: any = pagination.search
      ? {
          OR: [
            { legal_name: { contains: pagination.search, mode: 'insensitive' } },
            {
              partner_business_profiles: {
                is: {
                  OR: [
                    { business_name: { contains: pagination.search, mode: 'insensitive' } },
                    { city: { contains: pagination.search, mode: 'insensitive' } },
                    { email: { contains: pagination.search, mode: 'insensitive' } },
                  ],
                },
              },
            },
          ],
        }
      : {};

    const [partners, total] = await Promise.all([
      this.prisma.partners.findMany({
        where,
        include: {
          partner_business_profiles: true,
          partner_users: { include: { users: true } },
          _count: { select: { venues: true } },
        },
        skip: pagination.skip,
        take: pagination.limit,
        orderBy: { created_at: 'desc' },
      }),
      this.prisma.partners.count({ where }),
    ]);

    const items = partners.map((partner) => {
      const profile = partner.partner_business_profiles;
      const owner = partner.partner_users[0]?.users;
      const names = (owner?.name || '').trim().split(/\s+/);
      return {
        id: partner.id,
        userId: owner?.id ?? null,
        firstName: names[0] || null,
        lastName: names.slice(1).join(' ') || null,
        email: owner?.email ?? profile?.email ?? null,
        phone: owner?.phone_e164 ?? profile?.phone_e164 ?? null,
        businessName: profile?.business_name ?? partner.legal_name,
        businessAddress: profile?.address_line_1 ?? null,
        city: profile?.city ?? null,
        state: profile?.state ?? null,
        zipCode: profile?.postal_code ?? null,
        gstNumber: profile?.gst_number ?? null,
        panNumber: profile?.pan_number ?? null,
        isVerified: profile?.kyc_status === 'APPROVED',
        isActive: partner.status === 'ACTIVE',
        status: partner.status.toLowerCase(),
        venueCount: partner._count.venues,
        createdAt: partner.created_at,
        updatedAt: partner.updated_at,
      };
    });

    return [items, total] as const;
  }

  async findOne(id: string) {
    const partner = await this.prisma.partners.findUnique({
      where: { id },
      include: {
        partner_business_profiles: true,
        partner_users: {
          where: { role: PartnerRole.PARTNER_ADMIN },
          include: { users: true },
        },
        _count: { select: { venues: true } },
      },
    });
    if (!partner) throw new NotFoundException(`Partner with id ${id} not found`);
    return this.mapPrismaPartner(partner);
  }

  private mapPrismaPartner(partner: any) {
    const profile = partner.partner_business_profiles;
    const owner = partner.partner_users?.[0]?.users;
    const names = (owner?.name || '').trim().split(/\s+/);
    return {
      id: partner.id,
      userId: owner?.id ?? null,
      firstName: names[0] || null,
      lastName: names.slice(1).join(' ') || null,
      email: owner?.email ?? profile?.email ?? null,
      phone: owner?.phone_e164 ?? profile?.phone_e164 ?? null,
      businessName: profile?.business_name ?? partner.legal_name,
      businessAddress: profile?.address_line_1 ?? null,
      city: profile?.city ?? null,
      state: profile?.state ?? null,
      zipCode: profile?.postal_code ?? null,
      gstNumber: profile?.gst_number ?? null,
      panNumber: profile?.pan_number ?? null,
      isVerified: profile?.kyc_status === 'APPROVED',
      isActive: partner.status === PartnerStatus.ACTIVE,
      status: partner.status.toLowerCase(),
      venueCount: partner._count?.venues ?? 0,
      createdAt: partner.created_at,
      updatedAt: partner.updated_at,
      // These fields existed only on the legacy entity. Keep stable keys for
      // old clients, but never invent values from unrelated tables.
      businessDescription: null,
      country: null,
      contactPhone: profile?.phone_e164 ?? owner?.phone_e164 ?? null,
      gstinDocUrl: profile?.gst_document_url ?? null,
      panCardUrl: profile?.pan_document_url ?? null,
      aadhaarName: null,
      aadhaarNumber: null,
      aadhaarCardUrl: null,
      bankAccountNumber: null,
      bankIfscCode: null,
      bankAccountHolderName: null,
      logoUrl: null,
      documents: null,
    };
  }

  private mapPrismaGstVerification(request: any): GstVerificationRequest {
    return {
      id: request.id,
      partnerId: request.partner_id,
      gstNumber: request.gst_number,
      gstName: request.legal_name,
      gstDocUrl: request.document_url,
      status: String(request.status).toLowerCase() as GstVerificationStatus,
      adminNotes: request.rejection_reason,
      createdAt: request.created_at,
      updatedAt: request.updated_at,
    } as GstVerificationRequest;
  }

  async update(id: string, updatePartnerDto: UpdatePartnerDto): Promise<any> {
    if (updatePartnerDto.isActive !== undefined) {
      const previous = updatePartnerDto.isActive === false
        ? await this.prisma.partners.findUnique({ where: { id }, select: { status: true } })
        : null;
      const partner = await this.prisma.partners.update({
        where: { id },
        data: {
          status: updatePartnerDto.isActive
            ? PartnerStatus.ACTIVE
            : PartnerStatus.SUSPENDED,
          updated_at: new Date(),
        },
        include: {
          partner_business_profiles: true,
          partner_users: { include: { users: true } },
          _count: { select: { venues: true } },
        },
      });
      const mapped = this.mapPrismaPartner(partner);
      if (updatePartnerDto.isActive === false && previous?.status !== PartnerStatus.SUSPENDED) {
        const owner = partner.partner_users?.find((link) => link.role === 'PARTNER_ADMIN')?.users;
        await this.mailService.sendSuspensionEmail({
          deliveryKey: `partner-suspended:${id}:${partner.updated_at.toISOString()}`,
          toEmail: owner?.email || mapped.email,
          partnerName: owner?.name || [mapped.firstName, mapped.lastName].filter(Boolean).join(' ') || mapped.businessName,
        });
      }
      return mapped;
    }

    const unsupported = [
      'businessDescription', 'country', 'gstinDocUrl', 'panCardUrl',
      'aadhaarName', 'aadhaarNumber', 'aadhaarCardUrl', 'bankAccountNumber',
      'bankIfscCode', 'bankAccountHolderName', 'isVerified',
    ].filter((field) => (updatePartnerDto as any)[field] !== undefined);
    if (unsupported.length > 0) {
      throw new BadRequestException(`Unsupported partner profile fields: ${unsupported.join(', ')}`);
    }

    const result = await this.prisma.$transaction(async (tx) => {
      const current = await tx.partners.findUnique({
        where: { id },
        include: {
          partner_business_profiles: true,
          partner_users: { where: { role: PartnerRole.PARTNER_ADMIN }, include: { users: true } },
        },
      });
      if (!current) throw new NotFoundException(`Partner with id ${id} not found`);
      const ownerLink = current.partner_users[0];
      if (!ownerLink) throw new NotFoundException('Partner owner not found');

      const currentName = (ownerLink.users.name || '').trim().split(/\s+/).filter(Boolean);
      const firstName = updatePartnerDto.firstName?.trim() ?? currentName[0] ?? '';
      const lastName = updatePartnerDto.lastName?.trim() ?? currentName.slice(1).join(' ');
      const nextName = [firstName, lastName].filter(Boolean).join(' ') || null;
      const nextEmail = updatePartnerDto.email?.trim().toLowerCase();
      const nextPhone = updatePartnerDto.phone ? this.normalizePhone(updatePartnerDto.phone) : undefined;

      if (nextEmail && nextEmail !== (ownerLink.users.email || '').toLowerCase()) {
        const emailOwner = await tx.users.findFirst({
          where: { email: { equals: nextEmail, mode: 'insensitive' }, id: { not: ownerLink.user_id } },
          select: { id: true },
        });
        if (emailOwner) throw new ConflictException('Email is already registered');
      }
      if (nextPhone && nextPhone !== ownerLink.users.phone_e164) {
        const phoneOwner = await tx.users.findUnique({ where: { phone_e164: nextPhone }, select: { id: true } });
        if (phoneOwner && phoneOwner.id !== ownerLink.user_id) throw new ConflictException('Phone number is already registered');
      }

      const user = await tx.users.update({
        where: { id: ownerLink.user_id },
        data: {
          ...(nextName !== null ? { name: nextName } : {}),
          ...(nextEmail !== undefined ? { email: nextEmail } : {}),
          ...(nextPhone !== undefined ? { phone_e164: nextPhone } : {}),
          updated_at: new Date(),
        },
      });
      const profile = await tx.partner_business_profiles.upsert({
        where: { partner_id: id },
        create: {
          id: randomUUID(), partner_id: id,
          business_name: updatePartnerDto.businessName?.trim() || current.legal_name,
          owner_name: nextName, email: nextEmail ?? user.email, phone_e164: nextPhone ?? user.phone_e164,
          address_line_1: updatePartnerDto.businessAddress?.trim() || null,
          city: updatePartnerDto.city?.trim() || null, state: updatePartnerDto.state?.trim() || null,
          postal_code: updatePartnerDto.zipCode?.trim() || null, updated_at: new Date(),
        },
        update: {
          ...(updatePartnerDto.businessName !== undefined ? { business_name: updatePartnerDto.businessName.trim() } : {}),
          owner_name: nextName,
          ...(nextEmail !== undefined ? { email: nextEmail } : {}),
          ...(nextPhone !== undefined ? { phone_e164: nextPhone } : {}),
          ...(updatePartnerDto.businessAddress !== undefined ? { address_line_1: updatePartnerDto.businessAddress.trim() } : {}),
          ...(updatePartnerDto.city !== undefined ? { city: updatePartnerDto.city.trim() } : {}),
          ...(updatePartnerDto.state !== undefined ? { state: updatePartnerDto.state.trim() } : {}),
          ...(updatePartnerDto.zipCode !== undefined ? { postal_code: updatePartnerDto.zipCode.trim() } : {}),
          updated_at: new Date(),
        },
      });
      const partner = await tx.partners.update({
        where: { id },
        data: {
          ...(updatePartnerDto.businessName !== undefined ? { legal_name: updatePartnerDto.businessName.trim() } : {}),
          updated_at: new Date(),
        },
      });
      return { partner, user, profile };
    });

    return this.mapPrismaPartner({
      ...result.partner,
      partner_business_profiles: result.profile,
      partner_users: [{ users: result.user }],
      _count: { venues: 0 },
    });
  }

  async updateOwnProfile(id: string, updatePartnerDto: UpdatePartnerDto): Promise<Partner> {
    const saved = await this.update(id, updatePartnerDto);

    await this.adminNotificationsService.notify(
      AdminNotificationType.PARTNER_PROFILE_UPDATED,
      'Partner profile updated',
      `${saved.fullName || saved.businessName || saved.email} updated their profile`,
      { partnerId: id, fields: Object.keys(updatePartnerDto) },
    );

    return saved;
  }

  async remove(id: string): Promise<void> {
    // Admin and self-service deletion share the normalized schema and guards.
    await this.deleteAccount(id);
  }

  async toggleStatus(id: string): Promise<any> {
    const current = await this.prisma.partners.findUnique({ where: { id } });
    if (!current) throw new NotFoundException(`Partner with id ${id} not found`);
    return this.update(id, {
      isActive: current.status !== PartnerStatus.ACTIVE,
    });
  }

  async updateAvatar(partnerId: string, avatarUrl: string): Promise<Partner> {
    const owner = await this.prisma.partner_users.findFirst({
      where: { partner_id: partnerId, role: 'PARTNER_ADMIN' },
    });
    if (!owner) throw new NotFoundException('Partner owner not found');
    await this.prisma.users.update({
      where: { id: owner.user_id }, data: { profile_photo: avatarUrl },
    });
    return { id: partnerId, avatarUrl } as Partner;
  }

  async removeAvatar(partnerId: string): Promise<Partner> {
    const owner = await this.prisma.partner_users.findFirst({
      where: { partner_id: partnerId, role: 'PARTNER_ADMIN' },
    });
    if (!owner) throw new NotFoundException('Partner owner not found');
    await this.prisma.users.update({
      where: { id: owner.user_id },
      data: { profile_photo: null },
    });
    return { id: partnerId, avatarUrl: '' } as Partner;
  }

  async deleteAccount(partnerId: string): Promise<void> {
    await this.prisma.$transaction(
      (tx) => deletePartnerAccount(tx, partnerId),
      { maxWait: 10000, timeout: 60000, isolationLevel: 'Serializable' },
    );
  }

  // ─── GST Verification ────────────────────────────────────────────────────

  async submitGstVerification(
    partnerId: string,
    dto: SubmitGstVerificationDto,
    gstDocFile?: Express.Multer.File,
  ): Promise<GstVerificationRequest> {
    const gstDocUrl = gstDocFile
      ? ((gstDocFile as Express.Multer.File & { cloudinaryUrl?: string }).cloudinaryUrl ?? null)
      : null;

    const saved = await this.prisma.$transaction(async (tx) => {
      const existing = await tx.partner_gst_verification_requests.findFirst({
        where: { partner_id: partnerId, status: PartnerKycStatus.PENDING },
      });
      if (existing) {
        throw new ConflictException(
          'You already have a pending GST verification request. Please wait for admin review.',
        );
      }
      return tx.partner_gst_verification_requests.create({
        data: {
          id: randomUUID(),
          partner_id: partnerId,
          gst_number: dto.gstNumber,
          legal_name: dto.gstName,
          document_url: gstDocUrl,
          status: PartnerKycStatus.PENDING,
          updated_at: new Date(),
        },
      });
    }, { isolationLevel: 'Serializable', maxWait: 10000, timeout: 30000 });
    await this.adminNotificationsService.notify(
      AdminNotificationType.GST_VERIFICATION_SUBMITTED,
      'GST verification submitted',
      'A partner submitted GST details for review.',
      { partnerId, gstVerificationId: saved.id },
    );
    return this.mapPrismaGstVerification(saved);
  }

  async findMyGstVerification(partnerId: string): Promise<GstVerificationRequest> {
    const request = await this.prisma.partner_gst_verification_requests.findFirst({
      where: { partner_id: partnerId },
      orderBy: { created_at: 'desc' },
    });
    return request ? this.mapPrismaGstVerification(request) : null;
  }

  async findAllGstVerifications(
    pagination: PaginationDto,
    status?: GstVerificationStatus,
  ): Promise<[GstVerificationRequest[], number]> {
    const where: any = {};
    if (status) where.status = status.toUpperCase();
    if (pagination.search) {
      where.OR = [
        { gst_number: { contains: pagination.search, mode: 'insensitive' } },
        { legal_name: { contains: pagination.search, mode: 'insensitive' } },
      ];
    }
    const [requests, total] = await Promise.all([
      this.prisma.partner_gst_verification_requests.findMany({
        where,
        orderBy: { created_at: 'desc' },
        skip: pagination.skip,
        take: pagination.limit,
      }),
      this.prisma.partner_gst_verification_requests.count({ where }),
    ]);
    return [requests.map((request) => this.mapPrismaGstVerification(request)), total];
  }

  async findOneGstVerification(id: string): Promise<GstVerificationRequest> {
    const request = await this.prisma.partner_gst_verification_requests.findUnique({
      where: { id },
    });
    if (!request) throw new NotFoundException('GST verification request not found');
    return this.mapPrismaGstVerification(request);
  }

  async approveGstVerification(id: string, reviewerId: string) {
    if (!reviewerId) throw new UnauthorizedException('Authenticated reviewer is required');
    const approvedAt = new Date();
    const result = await this.prisma.$transaction(async (tx) => {
      const request = await tx.partner_gst_verification_requests.findUnique({ where: { id } });
      if (!request) throw new NotFoundException('GST verification request not found');
      if (request.status !== PartnerKycStatus.PENDING) {
        throw new BadRequestException('Only pending requests can be approved');
      }
      const profile = await tx.partner_business_profiles.findUnique({
        where: { partner_id: request.partner_id },
        select: { partner_id: true, business_name: true, kyc_status: true },
      });
      if (!profile) throw new NotFoundException('Partner business profile not found');

      const claimed = await tx.partner_gst_verification_requests.updateMany({
        where: { id, status: PartnerKycStatus.PENDING },
        data: {
          status: PartnerKycStatus.APPROVED,
          reviewed_by: reviewerId,
          reviewed_at: approvedAt,
          updated_at: approvedAt,
        },
      });
      if (claimed.count !== 1) {
        throw new BadRequestException('GST verification request is no longer pending');
      }

      const updatedProfile = await tx.partner_business_profiles.update({
        where: { partner_id: request.partner_id },
        data: {
          gst_number: request.gst_number,
          gst_document_url: request.document_url,
          updated_at: approvedAt,
        },
        select: { partner_id: true, business_name: true, kyc_status: true, gst_number: true, gst_document_url: true },
      });
      return { request, updatedProfile, reviewedAt: approvedAt };
    }, { isolationLevel: 'Serializable', maxWait: 10000, timeout: 30000 });

    return {
      request: {
        ...this.mapPrismaGstVerification({
        ...result.request,
        status: PartnerKycStatus.APPROVED,
        reviewed_by: reviewerId,
        reviewed_at: result.reviewedAt,
        }),
        reviewedBy: reviewerId,
        reviewedAt: result.reviewedAt,
      },
      businessProfile: {
        partnerId: result.updatedProfile.partner_id,
        businessName: result.updatedProfile.business_name,
        gstNumber: result.updatedProfile.gst_number,
        gstDocumentUrl: result.updatedProfile.gst_document_url,
        kycStatus: String(result.updatedProfile.kyc_status).toLowerCase(),
      },
    };
  }

  async rejectGstVerification(
    id: string,
    dto: ReviewGstVerificationDto,
  ): Promise<GstVerificationRequest> {
    const updated = await this.prisma.partner_gst_verification_requests.updateMany({
      where: { id, status: PartnerKycStatus.PENDING },
      data: {
        status: PartnerKycStatus.REJECTED,
        rejection_reason: dto.adminNotes ?? null,
        updated_at: new Date(),
      },
    });
    if (updated.count === 0) {
      const request = await this.prisma.partner_gst_verification_requests.findUnique({ where: { id } });
      if (!request) throw new NotFoundException('GST verification request not found');
      throw new BadRequestException('Only pending requests can be rejected');
    }
    return this.findOneGstVerification(id);
  }
}
