import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Partner } from './entities/partner.entity';
import {
  GstVerificationRequest,
  GstVerificationStatus,
} from './entities/gst-verification-request.entity';
import { SubmitGstVerificationDto } from './dto/submit-gst-verification.dto';
import { ReviewGstVerificationDto } from './dto/review-gst-verification.dto';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { Venue } from '../venues/entities/venue.entity';
import { VenueImage } from '../venues/entities/venue-image.entity';
import { VenueService as VenueServiceEntity } from '../venues/entities/venue-service.entity';
import { VenueAnswer } from '../venues/entities/venue-answer.entity';
import { Booking } from '../bookings/entities/booking.entity';
import { Payment } from '../payments/entities/payment.entity';
import { CreatePartnerDto } from './dto/create-partner.dto';
import { UpdatePartnerDto } from './dto/update-partner.dto';
import { AdminNotificationsService } from '../admin-notifications/admin-notifications.service';
import { AdminNotificationType } from '../admin-notifications/entities/admin-notification.entity';
import { PrismaService } from '../../prisma/prisma.service';
import { deletePartnerAccount } from './delete-partner-account';
import { MailService } from '../mail/mail.service';
import { PartnerRole, PartnerStatus, UserStatus } from '../../generated/prisma/client';

@Injectable()
export class PartnersService {
  constructor(
    @InjectRepository(Partner)
    private readonly partnerRepository: Repository<Partner>,
    @InjectRepository(GstVerificationRequest)
    private readonly gstVerificationRepo: Repository<GstVerificationRequest>,
    @InjectRepository(Venue)
    private readonly venueRepository: Repository<Venue>,
    @InjectRepository(VenueImage)
    private readonly venueImageRepository: Repository<VenueImage>,
    @InjectRepository(VenueServiceEntity)
    private readonly venueServiceRepository: Repository<VenueServiceEntity>,
    @InjectRepository(VenueAnswer)
    private readonly venueAnswerRepository: Repository<VenueAnswer>,
    @InjectRepository(Booking)
    private readonly bookingRepository: Repository<Booking>,
    @InjectRepository(Payment)
    private readonly paymentRepository: Repository<Payment>,
    private readonly dataSource: DataSource,
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

  async findOne(id: string): Promise<Partner> {
    const partner = await this.partnerRepository.findOne({ where: { id } });

    if (!partner) {
      throw new NotFoundException(`Partner with id ${id} not found`);
    }

    return partner;
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
    };
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
          toEmail: owner?.email || mapped.email,
          partnerName: owner?.name || [mapped.firstName, mapped.lastName].filter(Boolean).join(' ') || mapped.businessName,
        });
      }
      return mapped;
    }

    const partner = await this.findOne(id);
    Object.assign(partner, updatePartnerDto);
    return this.partnerRepository.save(partner);
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

  async verify(id: string): Promise<Partner> {
    const partner = await this.findOne(id);
    partner.isVerified = true;
    return this.partnerRepository.save(partner);
  }

  async updateLogo(partnerId: string, logoUrl: string): Promise<Partner> {
    const partner = await this.findOne(partnerId);
    partner.logoUrl = logoUrl;
    return this.partnerRepository.save(partner);
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

  async updateLegalInfo(
    partnerId: string,
    fields: {
      aadhaarName?: string;
      aadhaarNumber?: string;
      panNumber?: string;
      gstNumber?: string;
      gstName?: string;
      panCardUrl?: string;
      aadhaarCardUrl?: string;
      gstinDocUrl?: string;
    },
  ): Promise<Partner> {
    const partner = await this.findOne(partnerId);

    // ── Regular fields via entity save ───────────────────────────────────────
    let aadhaarTouched = false;
    let panTouched     = false;
    let gstTouched     = false;

    if (fields.aadhaarName !== undefined)    { partner.aadhaarName    = fields.aadhaarName;    aadhaarTouched = true; }
    if (fields.aadhaarNumber !== undefined)  { partner.aadhaarNumber  = fields.aadhaarNumber;  aadhaarTouched = true; }
    if (fields.aadhaarCardUrl !== undefined) { partner.aadhaarCardUrl = fields.aadhaarCardUrl; aadhaarTouched = true; }
    if (fields.panNumber !== undefined)      { partner.panNumber      = fields.panNumber;       panTouched = true; }
    if (fields.panCardUrl !== undefined)     { partner.panCardUrl     = fields.panCardUrl;      panTouched = true; }
    if (fields.gstNumber !== undefined)      { partner.gstNumber      = fields.gstNumber;       gstTouched = true; }
    if (fields.gstName !== undefined)        { partner.gstName        = fields.gstName;         gstTouched = true; }
    if (fields.gstinDocUrl !== undefined)    { partner.gstinDocUrl    = fields.gstinDocUrl;     gstTouched = true; }

    await this.partnerRepository.save(partner);

    // ── Timestamp columns via raw SQL (bypasses TypeORM change detection) ────
    const setClauses: string[] = [];
    if (aadhaarTouched) setClauses.push(`aadhaar_verified_at = NOW()`);
    if (panTouched)     setClauses.push(`pan_verified_at     = NOW()`);
    if (gstTouched)     setClauses.push(`gst_verified_at     = NOW()`);

    if (setClauses.length > 0) {
      await this.dataSource.query(
        `UPDATE partners SET ${setClauses.join(', ')} WHERE id = $1`,
        [partnerId],
      );
    }

    return this.findOne(partnerId);
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
    const existing = await this.gstVerificationRepo.findOne({
      where: { partnerId, status: GstVerificationStatus.PENDING },
    });

    if (existing) {
      throw new ConflictException(
        'You already have a pending GST verification request. Please wait for admin review.',
      );
    }

    const gstDocUrl = gstDocFile
      ? ((gstDocFile as Express.Multer.File & { cloudinaryUrl?: string }).cloudinaryUrl ?? null)
      : null;

    const request = this.gstVerificationRepo.create({ partnerId, ...dto, gstDocUrl });
    const saved = await this.gstVerificationRepo.save(request);
    await this.adminNotificationsService.notify(
      AdminNotificationType.GST_VERIFICATION_SUBMITTED,
      'GST verification submitted',
      'A partner submitted GST details for review.',
      { partnerId, gstVerificationId: saved.id },
    );
    return saved;
  }

  async findMyGstVerification(partnerId: string): Promise<GstVerificationRequest> {
    return this.gstVerificationRepo.findOne({
      where: { partnerId },
      order: { createdAt: 'DESC' },
    });
  }

  async findAllGstVerifications(
    pagination: PaginationDto,
    status?: GstVerificationStatus,
  ): Promise<[GstVerificationRequest[], number]> {
    const qb = this.gstVerificationRepo
      .createQueryBuilder('gst')
      .orderBy('gst.createdAt', 'DESC');

    if (status) {
      qb.andWhere({ status });
    }

    if (pagination.search) {
      qb.andWhere(
        '(gst.gstNumber ILIKE :search OR gst.gstName ILIKE :search)',
        { search: `%${pagination.search}%` },
      );
    }

    qb.skip(pagination.skip).take(pagination.limit);
    return qb.getManyAndCount();
  }

  async findOneGstVerification(id: string): Promise<GstVerificationRequest> {
    const request = await this.gstVerificationRepo.findOne({ where: { id } });
    if (!request) throw new NotFoundException('GST verification request not found');
    return request;
  }

  async approveGstVerification(id: string): Promise<Partner> {
    const request = await this.findOneGstVerification(id);

    if (request.status !== GstVerificationStatus.PENDING) {
      throw new BadRequestException('Only pending requests can be approved');
    }

    const partner = await this.findOne(request.partnerId);
    partner.gstNumber     = request.gstNumber;
    partner.gstName       = request.gstName;
    partner.gstinDocUrl   = request.gstDocUrl;
    partner.gstVerifiedAt = new Date();
    await this.partnerRepository.save(partner);

    await this.gstVerificationRepo.remove(request);
    return partner;
  }

  async rejectGstVerification(
    id: string,
    dto: ReviewGstVerificationDto,
  ): Promise<GstVerificationRequest> {
    const request = await this.findOneGstVerification(id);

    if (request.status !== GstVerificationStatus.PENDING) {
      throw new BadRequestException('Only pending requests can be rejected');
    }

    request.status     = GstVerificationStatus.REJECTED;
    request.adminNotes = dto.adminNotes ?? null;
    return this.gstVerificationRepo.save(request);
  }
}
