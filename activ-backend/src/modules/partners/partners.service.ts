import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like, In, DataSource } from 'typeorm';
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
import { BookingStatus } from '../../common/enums/booking-status.enum';
import { CreatePartnerDto } from './dto/create-partner.dto';
import { UpdatePartnerDto } from './dto/update-partner.dto';
import { AdminNotificationsService } from '../admin-notifications/admin-notifications.service';
import { AdminNotificationType } from '../admin-notifications/entities/admin-notification.entity';
import { PrismaService } from '../../prisma/prisma.service';

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
  ) {}

  async create(createPartnerDto: CreatePartnerDto): Promise<Partner> {
    if (createPartnerDto.email) {
      const existing = await this.partnerRepository.findOne({
        where: { email: createPartnerDto.email },
      });

      if (existing) {
        throw new ConflictException('A partner with this email already exists');
      }
    }

    const partner = this.partnerRepository.create(createPartnerDto);
    return this.partnerRepository.save(partner);
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

  async update(id: string, updatePartnerDto: UpdatePartnerDto): Promise<Partner> {
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
    const partner = await this.findOne(id);

    // Delete all venues and their child records before removing the partner.
    // Team members cascade automatically via DB onDelete: 'CASCADE'.
    const venues = await this.venueRepository.find({
      where: { partnerId: id },
      select: ['id'],
    });

    if (venues.length > 0) {
      const venueIds = venues.map((v) => v.id);

      await this.venueAnswerRepository.delete({ venueId: In(venueIds) });
      await this.venueImageRepository.delete({ venueId: In(venueIds) });
      await this.venueServiceRepository.delete({ venueId: In(venueIds) });

      // Remove venue_categories join-table rows (ManyToMany, no cascade)
      await this.dataSource
        .createQueryBuilder()
        .delete()
        .from('venue_categories')
        .where('venue_id IN (:...ids)', { ids: venueIds })
        .execute();

      await this.venueRepository.delete({ partnerId: id });
    }

    await this.partnerRepository.remove(partner);
  }

  async toggleStatus(id: string): Promise<Partner> {
    const partner = await this.findOne(id);
    partner.isActive = !partner.isActive;
    return this.partnerRepository.save(partner);
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
    const partner = await this.findOne(partnerId);
    partner.avatarUrl = avatarUrl;
    return this.partnerRepository.save(partner);
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
    await this.findOne(partnerId);

    const venues = await this.venueRepository.find({
      where: { partnerId },
      select: ['id'],
    });

    if (venues.length > 0) {
      const venueIds = venues.map((v) => v.id);

      // Block deletion if any booking is still active
      const activeBookingCount = await this.bookingRepository.count({
        where: [
          { venueId: In(venueIds), status: BookingStatus.PENDING },
          { venueId: In(venueIds), status: BookingStatus.CONFIRMED },
        ],
      });

      if (activeBookingCount > 0) {
        throw new BadRequestException(
          'Cannot delete account: there are active bookings on your venues. Please cancel or complete all pending bookings first.',
        );
      }

      // Collect all booking IDs to delete payments first (FK: payments.booking_id → bookings.id)
      const bookings = await this.bookingRepository.find({
        where: { venueId: In(venueIds) },
        select: ['id'],
      });

      if (bookings.length > 0) {
        const bookingIds = bookings.map((b) => b.id);
        await this.paymentRepository.delete({ bookingId: In(bookingIds) });
        await this.bookingRepository.delete({ venueId: In(venueIds) });
      }

      // Delete venue child records (FK: each references venue_id)
      await this.venueAnswerRepository.delete({ venueId: In(venueIds) });
      await this.venueImageRepository.delete({ venueId: In(venueIds) });
      await this.venueServiceRepository.delete({ venueId: In(venueIds) });

      // Clear venue_categories junction table (no TypeORM repository for junction tables)
      await this.venueRepository.manager.query(
        `DELETE FROM venue_categories WHERE venue_id = ANY($1::uuid[])`,
        [venueIds],
      );

      await this.venueRepository.delete({ partnerId });
    }

    // Delete partner — DB-level onDelete: CASCADE on team_members.partner_id handles team cleanup
    await this.partnerRepository.delete({ id: partnerId });
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
      ? `${process.env.APP_URL || ''}/uploads/gst-docs/${gstDocFile.filename}`
      : null;

    const request = this.gstVerificationRepo.create({ partnerId, ...dto, gstDocUrl });
    return this.gstVerificationRepo.save(request);
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
      qb.andWhere('gst.status = :status', { status });
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
