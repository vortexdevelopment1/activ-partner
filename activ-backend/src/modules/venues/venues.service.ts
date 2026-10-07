import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, DataSource, IsNull, Not } from 'typeorm';
import { Category } from '../categories/entities/category.entity';
import * as bcrypt from 'bcryptjs';
import * as fs from 'fs';
import * as path from 'path';
import { randomUUID } from 'crypto';
import { PDFDocument, StandardFonts, rgb } from 'pdf-lib';
import { Venue } from './entities/venue.entity';
import { VenueImage } from './entities/venue-image.entity';
import { VenueService } from './entities/venue-service.entity';
import { VenueAnswer } from './entities/venue-answer.entity';
import { CreateVenueDto } from './dto/create-venue.dto';
import { UpdateVenueDto } from './dto/update-venue.dto';
import { VenueApprovalDto } from './dto/venue-approval.dto';
import { AddVenueServiceDto } from './dto/add-venue-service.dto';
import { CreateVenueActivityDto } from './dto/create-venue-activity.dto';
import { SetActivityAmenitiesDto } from './dto/set-activity-amenities.dto';
import { ActivityApprovalDto } from './dto/activity-approval.dto';
import { VenueStatus } from '../../common/enums/venue-status.enum';
import { VenueServiceStatus } from '../../common/enums/venue-service-status.enum';
import { UserRole } from '../../common/enums/user-role.enum';
import { BookingStatus } from '../../common/enums/booking-status.enum';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { Partner } from '../partners/entities/partner.entity';
import { MailService } from '../mail/mail.service';
import { Booking } from '../bookings/entities/booking.entity';
import { QuestionsService } from '../questions/questions.service';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/entities/notification.entity';
import { AdminNotificationsService } from '../admin-notifications/admin-notifications.service';
import { AdminNotificationType } from '../admin-notifications/entities/admin-notification.entity';
import { PushNotificationsService } from '../push-notifications/push-notifications.service';
import {
  VenueUpdateRequest,
  VenueUpdateRequestStatus,
} from './entities/venue-update-request.entity';
import { SubmitVenueUpdateDto } from './dto/submit-venue-update.dto';
import { ReviewVenueUpdateDto } from './dto/review-venue-update.dto';
import { WalkInReservation } from './entities/walk-in-reservation.entity';
import { CreateWalkInReservationDto } from './dto/create-walk-in-reservation.dto';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class VenuesService {
  constructor(
    @InjectRepository(Venue)
    private readonly venueRepository: Repository<Venue>,
    @InjectRepository(VenueImage)
    private readonly venueImageRepository: Repository<VenueImage>,
    @InjectRepository(VenueService)
    private readonly venueServiceRepository: Repository<VenueService>,
    @InjectRepository(VenueAnswer)
    private readonly venueAnswerRepository: Repository<VenueAnswer>,
    @InjectRepository(Partner)
    private readonly partnerRepository: Repository<Partner>,
    @InjectRepository(Category)
    private readonly categoryRepository: Repository<Category>,
    @InjectRepository(Booking)
    private readonly bookingRepository: Repository<Booking>,
    private readonly mailService: MailService,
    private readonly dataSource: DataSource,
    private readonly questionsService: QuestionsService,
    @InjectRepository(VenueUpdateRequest)
    private readonly venueUpdateRequestRepo: Repository<VenueUpdateRequest>,
    @InjectRepository(WalkInReservation)
    private readonly walkInRepository: Repository<WalkInReservation>,
    private readonly notificationsService: NotificationsService,
    private readonly adminNotificationsService: AdminNotificationsService,
    private readonly pushNotificationsService: PushNotificationsService,
    private readonly prisma: PrismaService,
  ) {}

  async create(createVenueDto: CreateVenueDto, partnerId: string): Promise<any> {
    const { services, answers, categoryIds, ...venueData } = createVenueDto;

    if (!categoryIds || categoryIds.length === 0) {
      throw new BadRequestException('At least one categoryId is required');
    }

    const [partner, categories] = await Promise.all([
      this.prisma.partners.findUnique({ where: { id: partnerId } }),
      this.prisma.partner_service_categories.findMany({
        where: { id: { in: categoryIds }, status: 'APPROVED' },
        orderBy: { sort_order: 'asc' },
      }),
    ]);

    if (!partner) throw new NotFoundException('Partner not found');

    const validCategoryIds = new Set(categories.map((category) => category.id));
    const invalidCategoryIds = categoryIds.filter((id) => !validCategoryIds.has(id));
    if (invalidCategoryIds.length > 0) {
      throw new BadRequestException(
        `Invalid or inactive categoryIds: ${invalidCategoryIds.join(', ')}`,
      );
    }

    if (venueData.latitude == null || venueData.longitude == null) {
      throw new BadRequestException('Venue latitude and longitude are required');
    }

    const categorySlugs = categories.map((category) => category.slug);
    const activities = await this.prisma.activities.findMany({
      where: { sport_code: { in: categorySlugs }, status: 'PUBLISHED' },
    });
    const now = new Date();
    const venueId = randomUUID();
    const contactPhone = venueData.venuePhone || venueData.phone || null;

    await this.prisma.$transaction(async (tx) => {
      await tx.venues.create({
        data: {
          id: venueId,
          partner_id: partnerId,
          name: venueData.name,
          city_code: venueData.city?.trim() || 'UNKNOWN',
          latitude: venueData.latitude,
          longitude: venueData.longitude,
          status: 'DRAFT',
          policy_version: 'v1',
          metadata: {
            openingTime: venueData.openingTime ?? null,
            closingTime: venueData.closingTime ?? null,
            rules: venueData.rules ?? null,
            locationUrl: venueData.locationUrl ?? null,
            ownerPhone: venueData.phone ?? null,
            venuePhone: venueData.venuePhone ?? null,
            commission: venueData.commission ?? null,
            categoryIds,
            services: (services ?? []).map((service) => ({
              name: service.name,
              description: service.description ?? null,
              pricePerHour: service.pricePerHour,
              minDuration: service.minDuration ?? null,
              maxDuration: service.maxDuration ?? null,
              capacity: service.capacity ?? null,
              imageUrl: service.imageUrl ?? null,
            })),
          },
        },
      });

      await tx.partner_venue_profiles.create({
        data: {
          id: randomUUID(),
          partner_id: partnerId,
          venue_id: venueId,
          display_name: venueData.name,
          description: venueData.description ?? null,
          contact_phone_e164: contactPhone,
          address_line_1: venueData.venueAddress || venueData.address || null,
          address_line_2: venueData.flatBuilding ?? null,
          city: venueData.city ?? null,
          state: venueData.state ?? null,
          postal_code: venueData.zipCode ?? null,
          amenities: venueData.amenities ?? [],
          operating_hours: {
            openingTime: venueData.openingTime ?? null,
            closingTime: venueData.closingTime ?? null,
          },
          updated_at: now,
        },
      });

      await tx.partner_venue_services.createMany({
        data: categories.map((category) => ({
          id: randomUUID(),
          venue_id: venueId,
          service_category_id: category.id,
          title: category.name,
          description: category.description,
          status: 'DRAFT',
          onboarding_data: {},
          updated_at: now,
        })),
      });

      if (activities.length > 0) {
        await tx.venue_activities.createMany({
          data: activities.map((activity) => ({
            venue_id: venueId,
            activity_id: activity.id,
            status: 'PENDING',
          })),
          skipDuplicates: true,
        });
      }

      if (answers && answers.length > 0) {
        await tx.partner_venue_answers.createMany({
          data: answers.map((answer) => ({
            id: randomUUID(),
            venue_id: venueId,
            question_id: answer.questionId,
            answer: answer.answer,
            updated_at: now,
          })),
        });
      }
    });

    return {
      id: venueId,
      partnerId,
      categoryIds,
      categories: categories.map(({ id, name, slug }) => ({ id, name, slug })),
      ...venueData,
      status: VenueStatus.DRAFT,
      createdAt: now,
      updatedAt: now,
    };
  }

  // Partner submits venue for admin review (draft → pending)
  async submitForReview(venueId: string, partnerId: string): Promise<Venue> {
    const venue = await this.prisma.venues.findUnique({ where: { id: venueId } });

    if (!venue) {
      throw new NotFoundException(`Venue with id ${venueId} not found`);
    }

    if (venue.partner_id !== partnerId) {
      throw new ForbiddenException('You can only submit your own venues');
    }

    if (venue.status !== 'DRAFT') {
      throw new BadRequestException('Only draft venues can be submitted for review');
    }

    const metadata = this.asRecord(venue.metadata);
    await this.prisma.$transaction([
      this.prisma.venues.update({
        where: { id: venueId },
        data: {
          metadata: { ...metadata, submittedAt: new Date().toISOString() },
        },
      }),
      this.prisma.partner_venue_services.updateMany({
        where: { venue_id: venueId, status: 'DRAFT' },
        data: { status: 'PENDING', updated_at: new Date() },
      }),
    ]);

    return this.findOne(venueId);
  }

  // Partner saves legal info with uploaded document URLs
  async saveLegalInfo(
    venueId: string,
    callerId: string,
    legalData: {
      aadhaarName?: string;
      aadhaarNumber?: string;
      panNumber?: string;
      panCardUrl?: string;
      aadhaarCardUrl?: string;
      gstNumber?: string;
      gstName?: string;
      gstinDocUrl?: string;
    },
    isAdmin = false,
  ): Promise<any> {
    const venue = await this.prisma.venues.findUnique({
      where: { id: venueId },
      include: { partners: { include: { partner_business_profiles: true } } },
    });

    if (!venue) {
      throw new NotFoundException(`Venue with id ${venueId} not found`);
    }

    if (!isAdmin && venue.partner_id !== callerId) {
      throw new ForbiddenException('Access denied');
    }

    const partnerId = venue.partner_id;
    const existingMetadata = this.asRecord(venue.metadata);
    const existingLegalInfo = this.asRecord(existingMetadata.legalInfo);
    const now = new Date();
    const profileData = {
      ...(legalData.panNumber !== undefined && { pan_number: legalData.panNumber }),
      ...(legalData.gstNumber !== undefined && { gst_number: legalData.gstNumber }),
      ...(legalData.panCardUrl !== undefined && { pan_document_url: legalData.panCardUrl }),
      ...(legalData.gstinDocUrl !== undefined && { gst_document_url: legalData.gstinDocUrl }),
      updated_at: now,
    };

    const [, profile] = await this.prisma.$transaction([
      this.prisma.venues.update({
        where: { id: venueId },
        data: {
          metadata: {
            ...existingMetadata,
            legalInfo: { ...existingLegalInfo, ...legalData, updatedAt: now.toISOString() },
          },
        },
      }),
      this.prisma.partner_business_profiles.upsert({
        where: { partner_id: partnerId },
        update: profileData,
        create: {
          id: randomUUID(),
          partner_id: partnerId,
          ...profileData,
        },
      }),
    ]);

    return {
      id: venue.partners.id,
      legalName: venue.partners.legal_name,
      panNumber: profile.pan_number,
      gstNumber: profile.gst_number,
      panCardUrl: profile.pan_document_url,
      gstinDocUrl: profile.gst_document_url,
      ...legalData,
      updatedAt: profile.updated_at,
    };
  }

  // Partner accepts terms and provides electronic signature
  async acceptTerms(
    venueId: string,
    partnerId: string,
    electronicSignature: string,
  ): Promise<Venue> {
    const venue = await this.prisma.venues.findUnique({
      where: { id: venueId },
      include: { partner_venue_profiles: true },
    });

    if (!venue) {
      throw new NotFoundException(`Venue with id ${venueId} not found`);
    }

    if (venue.partner_id !== partnerId) {
      throw new ForbiddenException('You can only sign your own venue agreements');
    }

    const acceptedAt = new Date();
    const metadata = this.asRecord(venue.metadata);
    await this.prisma.$transaction([
      this.prisma.venues.update({
        where: { id: venueId },
        data: { metadata: { ...metadata, electronicSignature } },
      }),
      this.prisma.partner_venue_profiles.update({
        where: { venue_id: venueId },
        data: { terms_accepted_at: acceptedAt, updated_at: acceptedAt },
      }),
    ]);

    return this.findOne(venueId);
  }

  // Downloads the official branded Partner Agreement PDF with the
  // Agreement Acceptance page (page 3) populated for this venue/partner.
  // Pages 1-2 are copied verbatim from the approved template so branding
  // and content always match exactly what was presented at signing time.
  async generatePartnerAgreementPdf(
    venueId: string,
    currentUser: { id: string; role: string },
  ): Promise<{ base64: string; filename: string; mimeType: string }> {
    const venue = await this.findOne(venueId);

    if (currentUser.role === UserRole.PARTNER && venue.partnerId !== currentUser.id) {
      throw new ForbiddenException('You can only download your own venue agreement');
    }

    const templatePath = path.join(
      __dirname, '..', 'legal', 'templates', 'partner-agreement-template.pdf',
    );
    const templateBytes = fs.readFileSync(templatePath);
    const templateDoc = await PDFDocument.load(templateBytes);

    const outDoc = await PDFDocument.create();
    const copiedPages = await outDoc.copyPages(templateDoc, [0, 1, 2]);
    copiedPages.forEach((p) => outDoc.addPage(p));

    const page3 = outDoc.getPage(2);
    const font = await outDoc.embedFont(StandardFonts.Helvetica);

    const partnerName = venue.partner
      ? `${venue.partner.firstName || ''} ${venue.partner.lastName || ''}`.trim()
      : '';
    const signature = venue.electronicSignature || partnerName;
    const acceptedAt = venue.termsAcceptedAt
      ? new Date(venue.termsAcceptedAt).toLocaleString('en-IN', {
          day: '2-digit', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit',
        })
      : '';

    // Row top-Y positions (PDF points, bottom-up) measured from the
    // template's Agreement Acceptance table on page 3.
    const rows: Array<{ top: number; value: string }> = [
      { top: 603.14, value: signature },                 // Partner Name
      { top: 564.88, value: venue.name || '' },           // Venue Name
      { top: 526.63, value: venue.partner?.email || '' }, // Registered Email
      { top: 488.38, value: venue.partner?.phone || '' }, // Registered Mobile
      { top: 450.06, value: acceptedAt },                 // Date & Time of Acceptance
      { top: 357.33, value: signature },                  // Electronic Signature
    ];

    for (const row of rows) {
      // Cover the {{placeholder}} text with white, then draw the real value
      // in roughly the same spot — keeps the table borders/graphics intact.
      page3.drawRectangle({
        x: 328, y: row.top - 16, width: 210, height: 32,
        color: rgb(1, 1, 1),
      });
      page3.drawText(row.value, {
        x: 333, y: row.top - 10, size: 11, font, color: rgb(0.12, 0.12, 0.12),
      });
    }

    const pdfBytes = await outDoc.save();
    return {
      base64: Buffer.from(pdfBytes).toString('base64'),
      filename: `activ-partner-agreement-${venue.id}.pdf`,
      mimeType: 'application/pdf',
    };
  }

  async findAll(pagination: PaginationDto, status?: VenueStatus, categoryId?: string) {
    const statusMap: Record<string, 'DRAFT' | 'PUBLISHED' | 'ARCHIVED'> = {
      draft: 'DRAFT',
      pending: 'DRAFT',
      approved: 'PUBLISHED',
      rejected: 'ARCHIVED',
      suspended: 'ARCHIVED',
    };
    const where: any = {};
    if (status) where.status = statusMap[status] || undefined;
    if (pagination.search) {
      where.OR = [
        { name: { contains: pagination.search, mode: 'insensitive' } },
        { city_code: { contains: pagination.search, mode: 'insensitive' } },
      ];
    }
    if (categoryId) {
      where.partner_venue_services = { some: { service_category_id: categoryId } };
    }

    const [venues, total] = await Promise.all([
      this.prisma.venues.findMany({
        where,
        include: {
          partners: {
            include: {
              partner_business_profiles: true,
              partner_users: { include: { users: true } },
            },
          },
          partner_venue_profiles: true,
          partner_venue_images: { orderBy: { sort_order: 'asc' } },
          partner_venue_services: {
            include: { partner_service_categories: true },
          },
        },
        skip: pagination.skip,
        take: pagination.limit,
        orderBy: { name: 'asc' },
      }),
      this.prisma.venues.count({ where }),
    ]);

    const items = venues.map((venue) => {
      const profile = venue.partner_venue_profiles;
      const owner = venue.partners.partner_users[0]?.users;
      const ownerNames = (owner?.name || '').trim().split(/\s+/);
      const serviceCategory = venue.partner_venue_services[0]?.partner_service_categories;
      const mappedStatus = venue.status === 'PUBLISHED'
        ? 'approved'
        : venue.status === 'ARCHIVED' ? 'rejected' : 'pending';
      return {
        id: venue.id,
        partnerId: venue.partner_id,
        partner: {
          id: venue.partner_id,
          firstName: ownerNames[0] || null,
          lastName: ownerNames.slice(1).join(' ') || null,
          email: owner?.email ?? null,
          businessName: venue.partners.partner_business_profiles?.business_name
            ?? venue.partners.legal_name,
        },
        categoryId: serviceCategory?.id ?? null,
        category: serviceCategory
          ? { id: serviceCategory.id, name: serviceCategory.name }
          : null,
        name: profile?.display_name || venue.name,
        description: profile?.description,
        address: profile?.address_line_1,
        city: profile?.city || venue.city_code,
        state: profile?.state,
        zipCode: profile?.postal_code,
        latitude: Number(venue.latitude),
        longitude: Number(venue.longitude),
        phone: profile?.contact_phone_e164,
        status: mappedStatus,
        isActive: venue.status === 'PUBLISHED',
        images: venue.partner_venue_images.map((image) => ({
          id: image.id,
          venueId: image.venue_id,
          imageUrl: image.url,
          isPrimary: image.is_primary,
          caption: image.caption,
          createdAt: image.created_at,
        })),
        createdAt: profile?.created_at ?? new Date(0),
        updatedAt: profile?.updated_at ?? new Date(0),
      };
    });

    return [items, total] as const;
  }

  async findByPartner(partnerId: string, pagination: PaginationDto) {
    const qb = this.venueRepository
      .createQueryBuilder('venue')
      .leftJoinAndSelect('venue.categories', 'category')
      .leftJoinAndSelect('venue.images', 'images')
      .leftJoinAndSelect('venue.services', 'services')
      .where('venue.partnerId = :partnerId', { partnerId })
      .orderBy('venue.createdAt', 'DESC')
      .skip(pagination.skip)
      .take(pagination.limit);

    const [items, total] = await qb.getManyAndCount();
    return [items, total] as [Venue[], number];
  }

  async pauseBookings(id: string, partnerId: string, bookingAccept: boolean): Promise<Venue> {
    const venue = await this.findOne(id);
    if (venue.partnerId !== partnerId) {
      throw new ForbiddenException('You can only manage bookings for your own venues');
    }
    venue.bookingAccept = bookingAccept;
    const saved = await this.venueRepository.save(venue);

    const partner = await this.partnerRepository.findOne({ where: { id: partnerId } });
    const partnerName = partner?.fullName || partner?.businessName || partner?.email || 'A partner';

    if (bookingAccept === false) {
      await this.adminNotificationsService.notify(
        AdminNotificationType.VENUE_BOOKINGS_PAUSED,
        'Bookings paused',
        `${partnerName} paused bookings for ${venue.name} — follow up to find out why`,
        { partnerId, venueId: id },
      );
    } else {
      await this.adminNotificationsService.notify(
        AdminNotificationType.VENUE_BOOKINGS_RESUMED,
        'Bookings resumed',
        `${partnerName} resumed bookings for ${venue.name}`,
        { partnerId, venueId: id },
      );
    }

    return saved;
  }

  async markWelcomeSeen(venueId: string, partnerId: string): Promise<Venue> {
    const venue = await this.findOne(venueId);
    if (venue.partnerId !== partnerId) {
      throw new ForbiddenException('You can only update your own venues');
    }
    venue.hasSeenWelcome = true;
    return this.venueRepository.save(venue);
  }

  async findApprovedByPartner(partnerId: string): Promise<any[]> {
    if (!partnerId) throw new ForbiddenException('Partner identity is required');
    const records = await this.prisma.venues.findMany({
      where: { partner_id: partnerId, status: 'PUBLISHED' },
      select: { id: true },
      orderBy: [{ partner_venue_profiles: { created_at: 'desc' } }, { id: 'asc' }],
    });
    const venues = await Promise.all(records.map((record) => this.findOne(record.id)));

    // Match by IDs: activity titles can be customized independently of categories.
    return venues.map((venue) => ({
      ...venue,
      services: (venue.services || []).map((service) => ({
        ...service,
        answers: (venue.answers || []).filter(
          (a) => a.venueServiceId === service.id ||
            (!a.venueServiceId && a.question?.categoryId === service.categoryId),
        ),
      })),
    }));
  }

  async findApproved(pagination: PaginationDto, categoryId?: string) {
    const qb = this.venueRepository
      .createQueryBuilder('venue')
      .leftJoinAndSelect('venue.categories', 'category')
      .leftJoinAndSelect('venue.images', 'images')
      .leftJoinAndSelect('venue.services', 'services')
      .where('venue.status = :status', { status: VenueStatus.APPROVED })
      .andWhere('venue.isActive = true');

    if (categoryId) qb.andWhere('category.id = :categoryId', { categoryId });

    if (pagination.search) {
      qb.andWhere('(venue.name ILIKE :search OR venue.city ILIKE :search)', {
        search: `%${pagination.search}%`,
      });
    }

    qb.orderBy('venue.createdAt', 'DESC')
      .skip(pagination.skip)
      .take(pagination.limit);

    const [items, total] = await qb.getManyAndCount();
    return [items, total] as [Venue[], number];
  }

  async findOne(id: string): Promise<Venue> {
    const venue = await this.prisma.venues.findUnique({
      where: { id },
      include: {
        partners: {
          include: {
            partner_business_profiles: true,
            partner_users: { include: { users: true } },
          },
        },
        partner_venue_profiles: true,
        partner_venue_images: { orderBy: { sort_order: 'asc' } },
        partner_venue_services: {
          include: { partner_service_categories: true },
        },
        partner_venue_answers: {
          include: { partner_service_questions: { include: { partner_service_categories: true } } },
        },
      },
    });

    if (!venue) {
      throw new NotFoundException(`Venue with id ${id} not found`);
    }

    const metadata = this.asRecord(venue.metadata);
    const profile = venue.partner_venue_profiles;
    const businessProfile = venue.partners.partner_business_profiles;
    const owner = venue.partners.partner_users[0]?.users;
    const ownerNames = (owner?.name || '').trim().split(/\s+/);

    return {
      id: venue.id,
      partnerId: venue.partner_id,
      partner: {
        id: venue.partner_id,
        firstName: ownerNames[0] || null,
        lastName: ownerNames.slice(1).join(' ') || null,
        email: owner?.email ?? businessProfile?.email ?? null,
        phone: owner?.phone_e164 ?? businessProfile?.phone_e164 ?? null,
        businessName: businessProfile?.business_name ?? venue.partners.legal_name,
      } as Partner,
      categories: venue.partner_venue_services.map((service) => ({
        id: service.partner_service_categories.id,
        name: service.partner_service_categories.name,
        description: service.partner_service_categories.description,
      })) as Category[],
      name: profile?.display_name || venue.name,
      description: profile?.description ?? null,
      address: profile?.address_line_1 ?? null,
      city: profile?.city || venue.city_code,
      state: profile?.state ?? null,
      country: 'India',
      zipCode: profile?.postal_code ?? null,
      latitude: Number(venue.latitude),
      longitude: Number(venue.longitude),
      openingTime: metadata.openingTime as string ?? null,
      closingTime: metadata.closingTime as string ?? null,
      availability: metadata.availability as Venue['availability'] ?? null,
      amenities: Array.isArray(profile?.amenities) ? profile.amenities as string[] : [],
      rules: metadata.rules as string ?? null,
      phone: metadata.ownerPhone as string ?? null,
      venuePhone: profile?.contact_phone_e164 ?? null,
      locationUrl: metadata.locationUrl as string ?? null,
      flatBuilding: profile?.address_line_2 ?? null,
      venueAddress: profile?.address_line_1 ?? null,
      termsAccepted: Boolean(profile?.terms_accepted_at),
      termsAcceptedAt: profile?.terms_accepted_at ?? null,
      electronicSignature: metadata.electronicSignature as string ?? null,
      status: venue.status === 'PUBLISHED'
        ? VenueStatus.APPROVED
        : venue.status === 'ARCHIVED' ? VenueStatus.REJECTED : VenueStatus.DRAFT,
      isActive: venue.status === 'PUBLISHED',
      bookingAccept: metadata.bookingAccept !== false,
      hasSeenWelcome: metadata.hasSeenWelcome === true,
      commission: Number(metadata.commission ?? 10),
      images: venue.partner_venue_images.map((image) => ({
        id: image.id,
        venueId: image.venue_id,
        imageUrl: image.url,
        isPrimary: image.is_primary,
        caption: image.caption,
        createdAt: image.created_at,
      })) as VenueImage[],
      services: venue.partner_venue_services.map((service) => ({
        id: service.id,
        venueId: service.venue_id,
        categoryId: service.service_category_id,
        name: service.title,
        description: service.description,
        pricePerHour: service.price_per_hour_paise == null
          ? null
          : Number(service.price_per_hour_paise) / 100,
        status: service.status.toLowerCase(),
      })) as VenueService[],
      answers: venue.partner_venue_answers.map((answer) => ({
        id: answer.id,
        venueId: answer.venue_id,
        venueServiceId: answer.venue_service_id,
        questionId: answer.question_id,
        answer: answer.answer,
        question: {
          id: answer.partner_service_questions.id,
          question: answer.partner_service_questions.question,
          categoryId: answer.partner_service_questions.service_category_id,
          category: answer.partner_service_questions.partner_service_categories
            ? { id: answer.partner_service_questions.partner_service_categories.id,
                name: answer.partner_service_questions.partner_service_categories.name }
            : null,
        },
        createdAt: answer.created_at,
        updatedAt: answer.updated_at,
      })) as unknown as VenueAnswer[],
      createdAt: profile?.created_at ?? new Date(0),
      updatedAt: profile?.updated_at ?? new Date(0),
    } as Venue;
  }

  private asRecord(value: unknown): Record<string, any> {
    return value && typeof value === 'object' && !Array.isArray(value)
      ? value as Record<string, any>
      : {};
  }

  async setAvailability(
    venueId: string,
    venueTiming: Record<string, Record<string, Array<{ open: string; close: string; capacity?: number; price?: number; discountedPrice?: number }>>>,
    partnerId: string,
  ): Promise<any> {
    const venue = await this.prisma.venues.findUnique({ where: { id: venueId } });
    if (!venue) throw new NotFoundException(`Venue with id ${venueId} not found`);

    if (venue.partner_id !== partnerId) {
      throw new ForbiddenException('You can only update your own venue');
    }

    if (!venueTiming) throw new BadRequestException('venue_timing is required');

    // Merge into the existing per-category map — a venue can have several
    // independently-managed activities (categories), each calling this endpoint
    // for just its own categoryId. Overwriting the whole object would wipe out
    // every other activity's slots.
    const metadata =
      venue.metadata && typeof venue.metadata === 'object' && !Array.isArray(venue.metadata)
        ? venue.metadata as Record<string, any>
        : {};
    const availability: Record<string, Array<{ day: string; slots: Array<{ openTime: string; closeTime: string; capacity: number; price: number; discountedPrice: number }> }>> =
      metadata.availability && typeof metadata.availability === 'object'
        ? { ...metadata.availability }
        : {};

    for (const [catId, dayMap] of Object.entries(venueTiming)) {
      const days = Object.entries(dayMap)
        .map(([day, slots]) => ({
          day: day.toLowerCase(),
          slots: slots
            .filter((s) => s.open !== '-' && s.close !== '-')
            .map((s) => ({
              openTime: s.open,
              closeTime: s.close,
              capacity: s.capacity ?? 0,
              price: s.price ?? 0,
              discountedPrice: s.discountedPrice ?? 0,
            })),
        }))
        .filter((d) => d.slots.length > 0);

      if (days.length > 0) {
        availability[catId] = days;
      } else {
        delete availability[catId];
      }
    }

    const updated = await this.prisma.venues.update({
      where: { id: venueId },
      data: { metadata: { ...metadata, availability } },
    });

    for (const [categoryId, categoryAvailability] of Object.entries(availability)) {
      const service = await this.prisma.partner_venue_services.findFirst({
        where: { venue_id: venueId, service_category_id: categoryId },
      });
      if (!service) continue;
      const onboardingData =
        service.onboarding_data &&
        typeof service.onboarding_data === 'object' &&
        !Array.isArray(service.onboarding_data)
          ? service.onboarding_data as Record<string, any>
          : {};
      await this.prisma.partner_venue_services.update({
        where: { id: service.id },
        data: {
          onboarding_data: { ...onboardingData, availability: categoryAvailability },
          updated_at: new Date(),
        },
      });
    }

    return {
      id: updated.id,
      partnerId: updated.partner_id,
      availability,
      status: updated.status.toLowerCase(),
    };
  }

  // Save / upsert answers for a venue's category questions
  async saveAnswers(
    venueId: string,
    answers: Array<{ questionId: string; answer: any }>,
    partnerId: string,
    venueServiceId?: string,
  ): Promise<any[]> {
    const venue = await this.prisma.venues.findUnique({ where: { id: venueId } });
    if (!venue) throw new NotFoundException(`Venue with id ${venueId} not found`);

    if (venue.partner_id !== partnerId) {
      throw new ForbiddenException('You can only save answers for your own venues');
    }

    const partnerUser = await this.prisma.partner_users.findFirst({
      where: { partner_id: partnerId },
      orderBy: { role: 'desc' },
    });
    const saved: any[] = [];

    for (const { questionId, answer } of answers) {
      const existing = await this.prisma.partner_venue_answers.findFirst({
        where: {
          venue_id: venueId,
          question_id: questionId,
          venue_service_id: venueServiceId ?? null,
        },
      });

      if (existing) {
        saved.push(await this.prisma.partner_venue_answers.update({
          where: { id: existing.id },
          data: {
            answer,
            answered_by_partner_user_id: partnerUser?.id ?? null,
            updated_at: new Date(),
          },
        }));
      } else {
        saved.push(await this.prisma.partner_venue_answers.create({
          data: {
            id: randomUUID(),
            venue_id: venueId,
            venue_service_id: venueServiceId ?? null,
            question_id: questionId,
            answered_by_partner_user_id: partnerUser?.id ?? null,
            answer,
            updated_at: new Date(),
          },
        }));
      }
    }

    return saved;
  }

  async update(id: string, updateVenueDto: UpdateVenueDto, currentUser: { id: string; role: string }): Promise<Venue> {
    const venue = await this.findOne(id);

    if (currentUser.role === UserRole.PARTNER && venue.partnerId !== currentUser.id) {
      throw new ForbiddenException('You can only update your own venues');
    }

    const { services, answers, categoryIds, ...venueData } = updateVenueDto;
    Object.assign(venue, venueData);

    if (categoryIds && categoryIds.length > 0) {
      venue.categories = await this.categoryRepository.findBy({ id: In(categoryIds) });
    }

    const saved = await this.venueRepository.save(venue);

    if (currentUser.role === UserRole.PARTNER) {
      await this.adminNotificationsService.notify(
        AdminNotificationType.VENUE_UPDATED,
        'Venue updated',
        `${venue.name} was updated by its partner`,
        { partnerId: venue.partnerId, venueId: venue.id, fields: Object.keys(venueData) },
      );
    }

    return saved;
  }

  async processApproval(id: string, approvalDto: VenueApprovalDto, adminId: string): Promise<Venue> {
    const venue = await this.prisma.venues.findUnique({ where: { id } });
    if (!venue) {
      throw new NotFoundException(`Venue with id ${id} not found`);
    }

    if (
      approvalDto.status === VenueStatus.REJECTED ||
      approvalDto.status === VenueStatus.SUSPENDED
    ) {
      if (!approvalDto.reason) {
        throw new BadRequestException('Reason is required when rejecting or suspending a venue');
      }
    }

    const now = new Date();
    const metadata = this.asRecord(venue.metadata);
    const approved = approvalDto.status === VenueStatus.APPROVED;
    const rejected = approvalDto.status === VenueStatus.REJECTED;

    await this.prisma.$transaction([
      this.prisma.venues.update({
        where: { id },
        data: {
          status: approved ? 'PUBLISHED' : 'ARCHIVED',
          metadata: {
            ...metadata,
            approvedAt: approved ? now.toISOString() : null,
            approvedBy: approved ? adminId : null,
            rejectionReason: approved ? null : approvalDto.reason,
            reviewStatus: approvalDto.status,
          },
        },
      }),
      this.prisma.partner_venue_services.updateMany({
        where: { venue_id: id, status: { in: ['DRAFT', 'PENDING'] } },
        data: approved
          ? {
              status: 'APPROVED', approved_at: now, approved_by: adminId,
              rejection_reason: null, updated_at: now,
            }
          : {
              status: 'REJECTED', rejection_reason: approvalDto.reason, updated_at: now,
            },
      }),
    ]);

    const updatedVenue = await this.findOne(id);
    if (approved) {
      await this.handlePartnerApproval(updatedVenue);
    } else if (rejected) {
      await this.handlePartnerRejection(updatedVenue, approvalDto.reason);
    }

    return this.findOne(id);
  }

  private async handlePartnerApproval(venue: Venue): Promise<void> {
    const partner = await this.prisma.partners.findUnique({
      where: { id: venue.partnerId },
      include: {
        partner_business_profiles: true,
        partner_users: { include: { users: true } },
      },
    });

    if (!partner) return;

    // Skip if email is not yet set (phone-only OTP registration not yet completed)
    const partnerUser = partner.partner_users.find(
      (link) => link.role === 'PARTNER_ADMIN',
    ) ?? partner.partner_users[0];
    if (!partnerUser?.users.email) return;

    // Generate a strong readable password
    const password = this.generatePassword();

    // Hash and save — also activate the partner account
    const hashedPassword = await bcrypt.hash(password, 10);
    const now = new Date();
    await this.prisma.$transaction([
      this.prisma.users.update({
        where: { id: partnerUser.user_id },
        data: { password_hash: hashedPassword, status: 'ACTIVE', updated_at: now },
      }),
      this.prisma.partners.update({
        where: { id: partner.id },
        data: { status: 'ACTIVE', updated_at: now },
      }),
    ]);

    // Send email with credentials
    await this.mailService.sendPartnerApprovalEmail({
      toEmail: partnerUser.users.email,
      partnerName: partnerUser.users.name
        || partner.partner_business_profiles?.owner_name
        || partner.partner_business_profiles?.business_name
        || partner.legal_name,
      venueName: venue.name,
      password,
    });

    await this.notificationsService.notify(
      partner.id,
      NotificationType.VENUE_APPROVED,
      'Venue approved',
      `${venue.name} has been approved and is now live on ACTIV`,
      { venueId: venue.id },
    );

    await this.pushNotificationsService.sendToPartner(
      partner.id,
      'Venue approved',
      `${venue.name} has been approved and is now live on ACTIV`,
      { type: 'venue_approved', venueId: venue.id },
    );
  }

  private async handlePartnerRejection(venue: Venue, reason: string): Promise<void> {
    const partner = await this.prisma.partners.findUnique({
      where: { id: venue.partnerId },
      include: {
        partner_business_profiles: true,
        partner_users: { include: { users: true } },
      },
    });
    const partnerUser = partner?.partner_users.find(
      (link) => link.role === 'PARTNER_ADMIN',
    ) ?? partner?.partner_users[0];
    if (!partner || !partnerUser?.users.email) return;

    const fullName = partnerUser.users.name
      || partner.partner_business_profiles?.owner_name
      || partner.partner_business_profiles?.business_name
      || partner.legal_name;
    const firstName = fullName.split(' ')[0];

    await this.mailService.sendPartnerRejectionEmail({
      toEmail: partnerUser.users.email,
      firstName,
      venueId: venue.id,
      rejectionReason: reason,
    });
  }

  private generatePassword(): string {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    const special = '@#$!';
    let password = '';
    for (let i = 0; i < 8; i++) {
      password += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    password += special.charAt(Math.floor(Math.random() * special.length));
    password += Math.floor(Math.random() * 90 + 10);
    return password;
  }

  async remove(id: string, currentUser: { id: string; role: string }): Promise<void> {
    const venue = await this.findOne(id);

    if (currentUser.role === UserRole.PARTNER && venue.partnerId !== currentUser.id) {
      throw new ForbiddenException('You can only delete your own venues');
    }

    await this.venueRepository.remove(venue);
  }

  // Service (Activity) Images
  async uploadServiceImages(
    venueId: string,
    serviceName: string,
    newUrls: string[],
    userId: string,
    userRole?: string,
    categoryId?: string,
    amenities?: string[],
  ): Promise<any> {
    const venue = await this.prisma.venues.findUnique({
      where: { id: venueId },
    });

    if (!venue) {
      throw new NotFoundException(`Venue with id ${venueId} not found`);
    }

    if (userRole !== UserRole.ADMIN && venue.partner_id !== userId) {
      throw new ForbiddenException('You can only update images for your own venue services');
    }

    let service = await this.prisma.partner_venue_services.findFirst({
      where: {
        venue_id: venueId,
        ...(categoryId
          ? { service_category_id: categoryId }
          : { title: { equals: serviceName, mode: 'insensitive' } }),
      },
    });

    if (!service) {
      const category = categoryId
        ? await this.prisma.partner_service_categories.findUnique({
            where: { id: categoryId },
          })
        : await this.prisma.partner_service_categories.findFirst({
            where: { name: { equals: serviceName, mode: 'insensitive' } },
          });
      if (!category) {
        throw new BadRequestException('A valid categoryId is required for this activity');
      }

      service = await this.prisma.partner_venue_services.create({
        data: {
          id: randomUUID(),
          venue_id: venueId,
          service_category_id: category.id,
          title: serviceName || category.name,
          status: 'DRAFT',
          onboarding_data: {},
          updated_at: new Date(),
        },
      });
    }

    const currentData =
      service.onboarding_data &&
      typeof service.onboarding_data === 'object' &&
      !Array.isArray(service.onboarding_data)
        ? service.onboarding_data as Record<string, any>
        : {};
    const existingUrls = Array.isArray(currentData.imageUrls)
      ? currentData.imageUrls.filter((url): url is string => typeof url === 'string')
      : [];
    const imageUrls = [...existingUrls, ...newUrls];
    const serviceAmenities = amenities?.length
      ? amenities
      : Array.isArray(currentData.amenities)
        ? currentData.amenities
        : [];

    service = await this.prisma.partner_venue_services.update({
      where: { id: service.id },
      data: {
        onboarding_data: {
          ...currentData,
          imageUrls,
          coverImageUrl: currentData.coverImageUrl || imageUrls[0] || null,
          amenities: serviceAmenities,
        },
        updated_at: new Date(),
      },
    });

    if (newUrls.length > 0) {
      const [imageCount, uploader] = await Promise.all([
        this.prisma.partner_venue_images.count({ where: { venue_id: venueId } }),
        this.prisma.partner_users.findFirst({
          where: { partner_id: venue.partner_id },
          orderBy: { role: 'desc' },
        }),
      ]);
      await this.prisma.partner_venue_images.createMany({
        data: newUrls.map((url, index) => ({
          id: randomUUID(),
          venue_id: venueId,
          uploaded_by_partner_user_id: uploader?.id ?? null,
          url,
          caption: serviceName,
          sort_order: imageCount + index,
          is_primary: imageCount === 0 && index === 0,
          metadata: {
            serviceId: service.id,
            serviceCategoryId: service.service_category_id,
          },
          updated_at: new Date(),
        })),
      });
    }

    return {
      id: service.id,
      venueId: service.venue_id,
      categoryId: service.service_category_id,
      name: service.title,
      description: service.description,
      imageUrl: imageUrls[0] ?? null,
      imageUrls,
      amenities: serviceAmenities,
      status: service.status.toLowerCase(),
    };
  }

  async setServiceCover(serviceId: string, coverUrl: string, partnerId: string): Promise<VenueService> {
    const service = await this.venueServiceRepository.findOne({
      where: { id: serviceId },
      relations: ['venue'],
    });

    if (!service) throw new NotFoundException('Service not found');
    if (service.venue.partnerId !== partnerId) {
      throw new ForbiddenException('You can only update images for your own venue services');
    }

    if (!(service.imageUrls || []).includes(coverUrl)) {
      throw new BadRequestException('Image must be one of the uploaded images for this service');
    }

    service.imageUrl = coverUrl;
    return this.venueServiceRepository.save(service);
  }

  async deleteServiceImage(serviceId: string, imageUrl: string, partnerId: string): Promise<VenueService> {
    const service = await this.venueServiceRepository.findOne({
      where: { id: serviceId },
      relations: ['venue'],
    });

    if (!service) throw new NotFoundException('Service not found');
    if (service.venue.partnerId !== partnerId) {
      throw new ForbiddenException('You can only update images for your own venue services');
    }

    service.imageUrls = (service.imageUrls || []).filter((url) => url !== imageUrl);
    return this.venueServiceRepository.save(service);
  }

  // Venue Images
  async addImages(venueId: string, imageUrls: string[], partnerId: string): Promise<VenueImage[]> {
    const venue = await this.findOne(venueId);

    if (venue.partnerId !== partnerId) {
      throw new ForbiddenException('You can only add images to your own venues');
    }

    const hasPrimary = await this.venueImageRepository.findOne({
      where: { venueId, isPrimary: true },
    });

    const images = imageUrls.map((url, index) =>
      this.venueImageRepository.create({
        venueId,
        imageUrl: url,
        isPrimary: !hasPrimary && index === 0,
      }),
    );

    return this.venueImageRepository.save(images);
  }

  async removeImage(imageId: string, partnerId: string): Promise<void> {
    const image = await this.venueImageRepository.findOne({
      where: { id: imageId },
      relations: ['venue'],
    });

    if (!image) throw new NotFoundException('Image not found');
    if (image.venue.partnerId !== partnerId) {
      throw new ForbiddenException('You can only delete images from your own venues');
    }

    await this.venueImageRepository.remove(image);
  }

  async setPrimaryImage(imageId: string, partnerId: string): Promise<VenueImage> {
    const image = await this.venueImageRepository.findOne({
      where: { id: imageId },
      relations: ['venue'],
    });

    if (!image) throw new NotFoundException('Image not found');
    if (image.venue.partnerId !== partnerId) {
      throw new ForbiddenException('Access denied');
    }

    await this.venueImageRepository.update({ venueId: image.venueId }, { isPrimary: false });

    image.isPrimary = true;
    return this.venueImageRepository.save(image);
  }

  // Venue Services
  async addService(venueId: string, serviceDto: AddVenueServiceDto, partnerId: string): Promise<VenueService> {
    const venue = await this.findOne(venueId);

    if (venue.partnerId !== partnerId) {
      throw new ForbiddenException('You can only add services to your own venues');
    }

    const service = this.venueServiceRepository.create({ ...serviceDto, venueId });
    const saved = await this.venueServiceRepository.save(service);

    await this.adminNotificationsService.notify(
      AdminNotificationType.ACTIVITY_ADDED,
      'Activity added',
      `"${saved.name}" was added to ${venue.name}`,
      { partnerId, venueId, serviceId: saved.id },
    );

    return saved;
  }

  async updateService(serviceId: string, serviceDto: Partial<AddVenueServiceDto>, partnerId: string): Promise<VenueService> {
    const service = await this.venueServiceRepository.findOne({
      where: { id: serviceId },
      relations: ['venue'],
    });

    if (!service) throw new NotFoundException('Service not found');
    if (service.venue.partnerId !== partnerId) {
      throw new ForbiddenException('Access denied');
    }

    Object.assign(service, serviceDto);
    return this.venueServiceRepository.save(service);
  }

  async removeService(serviceId: string, partnerId: string): Promise<void> {
    const service = await this.venueServiceRepository.findOne({
      where: { id: serviceId },
      relations: ['venue'],
    });

    if (!service) throw new NotFoundException('Service not found');
    if (service.venue.partnerId !== partnerId) {
      throw new ForbiddenException('Access denied');
    }

    const venueId = service.venue.id;
    const venueName = service.venue.name;
    const serviceName = service.name;
    await this.venueServiceRepository.remove(service);

    await this.adminNotificationsService.notify(
      AdminNotificationType.ACTIVITY_REMOVED,
      'Activity removed',
      `"${serviceName}" was removed from ${venueName}`,
      { partnerId, venueId, serviceId },
    );

    // Auto-deactivate the venue once it has no activities left — nothing left to book.
    // bookingAccept is what the partner app actually reads to show ACTIV/INACTIV.
    const remaining = await this.venueServiceRepository.count({ where: { venueId } });
    if (remaining === 0) {
      await this.venueRepository.update(venueId, { isActive: false, bookingAccept: false });

      await this.adminNotificationsService.notify(
        AdminNotificationType.VENUE_AUTO_DEACTIVATED,
        'Venue auto-deactivated',
        `${venueName} was automatically deactivated — the partner removed its last remaining activity`,
        { partnerId, venueId },
      );
    }
  }

  async getVenueStats() {
    const [total, draft, approved, rejected] = await Promise.all([
      this.prisma.venues.count(),
      this.prisma.venues.count({ where: { status: 'DRAFT' } }),
      this.prisma.venues.count({ where: { status: 'PUBLISHED' } }),
      this.prisma.venues.count({ where: { status: 'ARCHIVED' } }),
    ]);
    const pending = draft;

    return { total, draft, pending, approved, rejected };
  }

  // ─── Venue Update Requests ────────────────────────────────────────────────

  private mapVenueUpdateRequest(request: any): VenueUpdateRequest {
    const changes = this.asRecord(request.requested_changes);
    return {
      ...changes,
      id: request.id,
      venueId: request.venue_id,
      partnerId: request.partner_id,
      status: request.status.toLowerCase(),
      adminNotes: request.rejection_reason,
      createdAt: request.created_at,
      updatedAt: request.updated_at,
      requestedChanges: changes,
      reviewedAt: request.reviewed_at,
    } as unknown as VenueUpdateRequest;
  }

  async submitVenueUpdateRequest(
    venueId: string,
    partnerId: string,
    dto: SubmitVenueUpdateDto,
  ): Promise<VenueUpdateRequest> {
    const changes = Object.fromEntries(
      Object.entries(dto).filter(([key, value]) =>
        ['name', 'description', 'address', 'city', 'state', 'zipCode', 'flatBuilding',
          'latitude', 'longitude', 'locationUrl', 'venuePhone'].includes(key) && value != null),
    );
    if (Object.keys(changes).length === 0) {
      throw new BadRequestException('Submit at least one changed field');
    }
    if (dto.venuePhone != null) {
      const digits = dto.venuePhone.replace(/\D/g, '');
      if (digits.length < 10 || digits.length > 15) {
        throw new BadRequestException('Enter a valid phone number');
      }
    }
    const request = await this.prisma.$transaction(async (tx) => {
      // Serialize submissions for this venue so two devices cannot create pending duplicates.
      await tx.$queryRaw`SELECT id FROM venues WHERE id = ${venueId}::uuid FOR UPDATE`;
      const venue = await tx.venues.findUnique({ where: { id: venueId } });
      if (!venue) throw new NotFoundException('Venue not found');
      if (venue.partner_id !== partnerId) {
        throw new ForbiddenException('You can only submit update requests for your own venues');
      }
      if (venue.status !== 'PUBLISHED') {
        throw new BadRequestException('Only approved venues can submit update requests');
      }
      const existing = await tx.partner_venue_update_requests.findFirst({
        where: { venue_id: venueId, status: 'PENDING' },
      });
      if (existing) {
        throw new ConflictException(
          'A pending update request already exists for this venue. Please wait for admin review.',
        );
      }
      return tx.partner_venue_update_requests.create({
        data: {
          id: randomUUID(), partner_id: partnerId, venue_id: venueId,
          status: 'PENDING', requested_changes: changes, updated_at: new Date(),
        },
      });
    });
    return this.mapVenueUpdateRequest(request);
  }

  async findMyVenueUpdateRequests(partnerId: string): Promise<VenueUpdateRequest[]> {
    if (!partnerId) throw new ForbiddenException('Partner identity is required');
    const requests = await this.prisma.partner_venue_update_requests.findMany({
      where: { partner_id: partnerId }, orderBy: { created_at: 'desc' },
    });
    return requests.map((request) => this.mapVenueUpdateRequest(request));
  }

  async findAllVenueUpdateRequests(
    pagination: PaginationDto,
    status?: VenueUpdateRequestStatus,
  ): Promise<[VenueUpdateRequest[], number]> {
    const where: any = {};
    if (status) where.status = status.toUpperCase();
    if (pagination.search) {
      where.requested_changes = { path: ['name'], string_contains: pagination.search };
    }
    const [requests, total] = await Promise.all([
      this.prisma.partner_venue_update_requests.findMany({
        where, orderBy: { created_at: 'desc' }, skip: pagination.skip, take: pagination.limit,
      }),
      this.prisma.partner_venue_update_requests.count({ where }),
    ]);
    return [requests.map((request) => this.mapVenueUpdateRequest(request)), total];
  }

  async findOneVenueUpdateRequest(id: string): Promise<VenueUpdateRequest> {
    const request = await this.prisma.partner_venue_update_requests.findUnique({ where: { id } });
    if (!request) throw new NotFoundException('Venue update request not found');
    return this.mapVenueUpdateRequest(request);
  }

  async approveVenueUpdateRequest(id: string, adminId?: string): Promise<Venue> {
    const venueId = await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM partner_venue_update_requests WHERE id = ${id}::uuid FOR UPDATE`;
      const request = await tx.partner_venue_update_requests.findUnique({ where: { id } });
      if (!request) throw new NotFoundException('Venue update request not found');
      if (request.status !== 'PENDING') throw new BadRequestException('Only pending requests can be approved');
      const venue = await tx.venues.findUnique({ where: { id: request.venue_id } });
      if (!venue) throw new NotFoundException('Venue not found');
      const changes = this.asRecord(request.requested_changes);
      const metadata = { ...this.asRecord(venue.metadata) };
      if (changes.locationUrl !== undefined) metadata.locationUrl = changes.locationUrl;
      const now = new Date();
      await tx.venues.update({
        where: { id: venue.id },
        data: {
          ...(changes.name !== undefined ? { name: changes.name } : {}),
          ...(changes.city !== undefined ? { city_code: changes.city } : {}),
          ...(changes.latitude !== undefined ? { latitude: changes.latitude } : {}),
          ...(changes.longitude !== undefined ? { longitude: changes.longitude } : {}),
          metadata,
        },
      });
      const profileData: Record<string, any> = { updated_at: now };
      for (const [field, column] of Object.entries({
        name: 'display_name', description: 'description', address: 'address_line_1',
        flatBuilding: 'address_line_2', city: 'city', state: 'state',
        zipCode: 'postal_code', venuePhone: 'contact_phone_e164',
      })) {
        if (changes[field] !== undefined) profileData[column] = changes[field];
      }
      await tx.partner_venue_profiles.upsert({
        where: { venue_id: venue.id },
        create: {
          id: randomUUID(), venue_id: venue.id, partner_id: venue.partner_id,
          ...profileData, updated_at: now,
        },
        update: profileData,
      });
      await tx.partner_venue_update_requests.update({
        where: { id }, data: {
          status: 'APPROVED', reviewed_at: now, reviewed_by: adminId ?? null, updated_at: now,
        },
      });
      return venue.id;
    });
    const venue = await this.findOne(venueId);
    await this.notificationsService.notify(venue.partnerId, NotificationType.ADMIN_UPDATE,
      'Venue details approved', `${venue.name}: your updated venue details are now live.`,
      { venueId, requestId: id });
    return venue;
  }

  async rejectVenueUpdateRequest(
    id: string,
    dto: ReviewVenueUpdateDto,
    adminId?: string,
  ): Promise<VenueUpdateRequest> {
    const request = await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM partner_venue_update_requests WHERE id = ${id}::uuid FOR UPDATE`;
      const current = await tx.partner_venue_update_requests.findUnique({ where: { id } });
      if (!current) throw new NotFoundException('Venue update request not found');
      if (current.status !== 'PENDING') throw new BadRequestException('Only pending requests can be rejected');
      const now = new Date();
      return tx.partner_venue_update_requests.update({
        where: { id }, data: {
          status: 'REJECTED', rejection_reason: dto.adminNotes ?? null,
          reviewed_at: now, reviewed_by: adminId ?? null, updated_at: now,
        },
      });
    });
    await this.notificationsService.notify(request.partner_id, NotificationType.ADMIN_UPDATE,
      'Venue changes need attention', dto.adminNotes || 'Your venue changes were not approved. Please review and submit again.',
      { venueId: request.venue_id, requestId: id });
    return this.mapVenueUpdateRequest(request);
  }

  // ─── Venue Activities (per-category VenueService lifecycle) ───────────────
  // A Venue is approved once at onboarding. Each Activity added afterward is
  // a VenueService scoped to one Category, with its own draft -> pending ->
  // approved/rejected review — independent of the parent Venue's status.

  private async findOwnedActivity(serviceId: string, partnerId: string): Promise<VenueService> {
    const service = await this.venueServiceRepository.findOne({
      where: { id: serviceId },
      relations: ['venue'],
    });

    if (!service) throw new NotFoundException('Activity not found');
    if (service.venue.partnerId !== partnerId) {
      throw new ForbiddenException('You can only manage activities on your own venues');
    }

    return service;
  }

  // Step 1 — Select activity: create a draft, or resume an in-progress one
  async createActivity(venueId: string, partnerId: string, dto: CreateVenueActivityDto): Promise<VenueService> {
    const venue = await this.findOne(venueId);

    if (venue.partnerId !== partnerId) {
      throw new ForbiddenException('You can only add activities to your own venues');
    }

    if (venue.status !== VenueStatus.APPROVED) {
      throw new BadRequestException('Activities can only be added to an approved venue');
    }

    const category = await this.categoryRepository.findOne({ where: { id: dto.categoryId } });
    if (!category) throw new NotFoundException('Category not found');

    const existing = await this.venueServiceRepository.findOne({
      where: { venueId, categoryId: dto.categoryId },
    });

    if (existing) {
      if (existing.status === VenueServiceStatus.REJECTED) {
        // Let the partner restart a rejected activity from scratch
        existing.status = VenueServiceStatus.DRAFT;
        existing.rejectionReason = null;
        return this.venueServiceRepository.save(existing);
      }
      // Resume the in-progress (or already approved) activity instead of duplicating
      return existing;
    }

    const service = this.venueServiceRepository.create({
      venueId,
      categoryId: dto.categoryId,
      name: category.name,
      pricePerHour: 0,
      imageUrls: [],
      amenities: [],
      status: VenueServiceStatus.DRAFT,
    });

    return this.venueServiceRepository.save(service);
  }

  // Steps 2/3 — Upload images directly to a known activity (by id, not name lookup)
  async uploadActivityImages(serviceId: string, newUrls: string[], partnerId: string): Promise<VenueService> {
    const service = await this.findOwnedActivity(serviceId, partnerId);

    service.imageUrls = [...(service.imageUrls || []), ...newUrls];

    if (!service.imageUrl && newUrls.length > 0) {
      service.imageUrl = newUrls[0];
    }

    return this.venueServiceRepository.save(service);
  }

  // Step 4 — Question set for the activity's category + any answers already saved
  async getActivityQuestions(serviceId: string, partnerId: string) {
    const service = await this.findOwnedActivity(serviceId, partnerId);

    const [questions, answers] = await Promise.all([
      service.categoryId ? this.questionsService.findByCategoryId(service.categoryId) : Promise.resolve([]),
      this.venueAnswerRepository.find({ where: { venueServiceId: serviceId } }),
    ]);

    const answerMap = new Map(answers.map((a) => [a.questionId, a.answer]));

    return questions.map((q) => ({
      ...q,
      answer: answerMap.has(q.id) ? answerMap.get(q.id) : null,
    }));
  }

  // Step 4 — Save / upsert answers scoped to this specific activity
  async saveActivityAnswers(
    serviceId: string,
    answers: Array<{ questionId: string; answer: any }>,
    partnerId: string,
  ): Promise<VenueAnswer[]> {
    const service = await this.findOwnedActivity(serviceId, partnerId);

    const saved: VenueAnswer[] = [];

    for (const { questionId, answer } of answers) {
      const existing = await this.venueAnswerRepository.findOne({
        where: { venueServiceId: serviceId, questionId },
      });

      if (existing) {
        existing.answer = answer;
        saved.push(await this.venueAnswerRepository.save(existing));
      } else {
        const newAnswer = this.venueAnswerRepository.create({
          venueId: service.venueId,
          venueServiceId: serviceId,
          questionId,
          answer,
        });
        saved.push(await this.venueAnswerRepository.save(newAnswer));
      }
    }

    return saved;
  }

  // Step 5 — Amenities for this specific activity
  async setActivityAmenities(serviceId: string, dto: SetActivityAmenitiesDto, partnerId: string): Promise<VenueService> {
    const service = await this.findOwnedActivity(serviceId, partnerId);
    service.amenities = dto.amenities;
    return this.venueServiceRepository.save(service);
  }

  // "Save as Draft" — explicit confirmation call; functionally a no-op state-wise
  // unless the activity was previously REJECTED, in which case it resets to DRAFT.
  async saveActivityDraft(serviceId: string, partnerId: string): Promise<VenueService> {
    const service = await this.findOwnedActivity(serviceId, partnerId);

    if (service.status !== VenueServiceStatus.DRAFT && service.status !== VenueServiceStatus.REJECTED) {
      throw new BadRequestException('Only draft or rejected activities can be saved as draft');
    }

    service.status = VenueServiceStatus.DRAFT;
    return this.venueServiceRepository.save(service);
  }

  // "Submit for review" — draft/rejected -> pending. Validates the minimums
  // that the wizard screens advertise (4+ images, 1+ amenity, required answers).
  async submitActivityForReview(serviceId: string, partnerId: string): Promise<VenueService> {
    const service = await this.findOwnedActivity(serviceId, partnerId);

    if (service.status !== VenueServiceStatus.DRAFT && service.status !== VenueServiceStatus.REJECTED) {
      throw new BadRequestException('Only draft or rejected activities can be submitted for review');
    }

    if ((service.imageUrls || []).length < 4) {
      throw new BadRequestException('Please upload at least 4 images before submitting');
    }

    if (!service.amenities || service.amenities.length < 1) {
      throw new BadRequestException('Please select at least one amenity before submitting');
    }

    if (service.categoryId) {
      const questions = await this.questionsService.findByCategoryId(service.categoryId);
      const requiredIds = questions.filter((q) => q.isRequired).map((q) => q.id);

      if (requiredIds.length > 0) {
        const answers = await this.venueAnswerRepository.find({ where: { venueServiceId: serviceId } });
        const answeredIds = new Set(answers.map((a) => a.questionId));
        const missing = requiredIds.some((id) => !answeredIds.has(id));

        if (missing) {
          throw new BadRequestException('Please answer all required activity-specific questions before submitting');
        }
      }
    }

    service.status = VenueServiceStatus.PENDING;
    service.submittedAt = new Date();
    service.rejectionReason = null;
    const saved = await this.venueServiceRepository.save(service);

    await this.notificationsService.notify(
      partnerId,
      NotificationType.ACTIVITY_UNDER_REVIEW,
      'Activity under review',
      `${saved.name} has been submitted and is being reviewed by ACTIV`,
      { serviceId: saved.id },
    );

    return saved;
  }

  // Step 8 — combined review payload: images + amenities + answers + slots
  async getActivityDetail(serviceId: string, partnerId: string) {
    const service = await this.findOwnedActivity(serviceId, partnerId);

    const [answers, venue] = await Promise.all([
      this.venueAnswerRepository.find({ where: { venueServiceId: serviceId }, relations: ['question'] }),
      this.venueRepository.findOne({ where: { id: service.venueId } }),
    ]);

    const slots = service.categoryId ? venue?.availability?.[service.categoryId] ?? [] : [];

    return { ...service, answers, slots };
  }

  // Full activity list — all activities for a venue with category info + images + description
  async findVenueActivitiesFull(venueId: string, partnerId: string) {
    const venue = await this.findOne(venueId);
    if (venue.partnerId !== partnerId) {
      throw new ForbiddenException('You can only view activities for your own venues');
    }

    const services = await this.venueServiceRepository.find({
      where: { venueId },
      relations: ['category'],
      order: { createdAt: 'DESC' },
    });

    if (services.length === 0) return [];

    const serviceIds = services.map((s) => s.id);

    const rows = await this.bookingRepository
      .createQueryBuilder('booking')
      .select('booking.serviceId', 'serviceId')
      .addSelect('COUNT(*)', 'bookingCount')
      .addSelect(
        'SUM(CASE WHEN booking.status IN (:...earningStatuses) THEN booking.totalAmount ELSE 0 END)',
        'earnings',
      )
      .where('booking.serviceId IN (:...serviceIds)', { serviceIds })
      .setParameter('earningStatuses', [BookingStatus.CONFIRMED, BookingStatus.COMPLETED])
      .groupBy('booking.serviceId')
      .getRawMany();

    const statsByService = new Map(
      rows.map((r) => [r.serviceId, { bookingCount: Number(r.bookingCount), earnings: Number(r.earnings) || 0 }]),
    );

    return services.map((s) => ({
      id: s.id,
      venueId: s.venueId,
      name: s.name,
      description: s.description ?? null,
      pricePerHour: s.pricePerHour,
      minDuration: s.minDuration,
      maxDuration: s.maxDuration ?? null,
      capacity: s.capacity ?? null,
      imageUrl: s.imageUrl ?? null,
      imageUrls: s.imageUrls ?? [],
      isActive: s.isActive,
      status: s.status,
      amenities: s.amenities ?? [],
      courts: s.courts ?? [],
      rejectionReason: s.rejectionReason ?? null,
      submittedAt: s.submittedAt ?? null,
      approvedAt: s.approvedAt ?? null,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
      category: s.category
        ? {
            id: s.category.id,
            name: s.category.name,
            icon: s.category.icon ?? null,
            description: s.category.description ?? null,
            imageUrl: s.category.imageUrl ?? null,
          }
        : null,
      categoryId: s.categoryId ?? null,
      bookingCount: statsByService.get(s.id)?.bookingCount ?? 0,
      earnings: statsByService.get(s.id)?.earnings ?? 0,
    }));
  }

  // Screen 9 — Activity Management list with booking count + earnings per activity
  async findVenueActivities(
    venueId: string,
    partnerId: string,
    statusFilter?: 'active' | 'in_review' | 'draft' | 'inactive',
  ) {
    const venue = await this.findOne(venueId);
    if (venue.partnerId !== partnerId) {
      throw new ForbiddenException('You can only view activities for your own venues');
    }

    let services = await this.venueServiceRepository.find({
      where: { venueId },
      relations: ['category'],
      order: { createdAt: 'DESC' },
    });

    if (statusFilter === 'active') {
      services = services.filter((s) => s.status === VenueServiceStatus.APPROVED && s.isActive);
    } else if (statusFilter === 'inactive') {
      services = services.filter((s) => s.status === VenueServiceStatus.APPROVED && !s.isActive);
    } else if (statusFilter === 'in_review') {
      services = services.filter((s) => s.status === VenueServiceStatus.PENDING);
    } else if (statusFilter === 'draft') {
      services = services.filter((s) => s.status === VenueServiceStatus.DRAFT);
    }

    if (services.length === 0) return [];

    const serviceIds = services.map((s) => s.id);

    const rows = await this.bookingRepository
      .createQueryBuilder('booking')
      .select('booking.serviceId', 'serviceId')
      .addSelect('COUNT(*)', 'bookingCount')
      .addSelect(
        'SUM(CASE WHEN booking.status IN (:...earningStatuses) THEN booking.totalAmount ELSE 0 END)',
        'earnings',
      )
      .where('booking.serviceId IN (:...serviceIds)', { serviceIds })
      .setParameter('earningStatuses', [BookingStatus.CONFIRMED, BookingStatus.COMPLETED])
      .groupBy('booking.serviceId')
      .getRawMany();

    const statsByService = new Map(
      rows.map((r) => [r.serviceId, { bookingCount: Number(r.bookingCount), earnings: Number(r.earnings) || 0 }]),
    );

    return services.map((s) => ({
      ...s,
      bookingCount: statsByService.get(s.id)?.bookingCount ?? 0,
      earnings: statsByService.get(s.id)?.earnings ?? 0,
    }));
  }

  // Partner pause/resume an approved activity (Active <-> Inactive)
  async toggleActivityActive(serviceId: string, partnerId: string, isActive: boolean, reason?: string): Promise<VenueService> {
    const service = await this.findOwnedActivity(serviceId, partnerId);

    if (service.status !== VenueServiceStatus.APPROVED) {
      throw new BadRequestException('Only approved activities can be activated or paused');
    }

    service.isActive = isActive;
    service.pauseReason = isActive ? null : (reason ?? null);
    return this.venueServiceRepository.save(service);
  }

  // "Add New Activity" mobile wizard — the app collects everything locally
  // (category, photos, answers, amenities, timing) across 5 screens and fires
  // ONE combined call at the end. This composes the granular methods above
  // instead of duplicating their logic.
  async submitFullActivity(
    venueId: string,
    partnerId: string,
    options: { categoryId: string; action: 'draft' | 'submit' },
    imageUrls: string[],
    answers: Array<{ questionId: string; answer: any }>,
    amenities: string[],
    timing: Record<string, Array<{ open_time?: string; close_time?: string; slot_price?: string; discounted_price?: string; max_members?: string }>>,
  ): Promise<VenueService> {
    const service = await this.createActivity(venueId, partnerId, { categoryId: options.categoryId });

    if (imageUrls.length > 0) {
      await this.uploadActivityImages(service.id, imageUrls, partnerId);
    }

    if (answers.length > 0) {
      await this.saveActivityAnswers(service.id, answers, partnerId);
    }

    if (amenities.length > 0) {
      await this.setActivityAmenities(service.id, { amenities }, partnerId);
    }

    if (timing && Object.keys(timing).length > 0) {
      const venueTiming: Record<
        string,
        Record<string, Array<{ open: string; close: string; capacity?: number; price?: number; discountedPrice?: number }>>
      > = { [options.categoryId]: {} };

      for (const [day, slots] of Object.entries(timing)) {
        venueTiming[options.categoryId][day] = (slots || []).map((s) => ({
          open: s.open_time ?? '-',
          close: s.close_time ?? '-',
          capacity: s.max_members ? parseInt(s.max_members, 10) : undefined,
          price: s.slot_price ? parseFloat(s.slot_price) : undefined,
          discountedPrice: s.discounted_price ? parseFloat(s.discounted_price) : undefined,
        }));
      }

      await this.setAvailability(venueId, venueTiming, partnerId);
    }

    return options.action === 'submit'
      ? this.submitActivityForReview(service.id, partnerId)
      : this.saveActivityDraft(service.id, partnerId);
  }

  // ─── Admin: Activity Approval ──────────────────────────────────────────────

  async findPendingActivities(pagination: PaginationDto): Promise<[VenueService[], number]> {
    const qb = this.venueServiceRepository
      .createQueryBuilder('service')
      .leftJoinAndSelect('service.venue', 'venue')
      .leftJoinAndSelect('service.category', 'category')
      .where('service.status = :status', { status: VenueServiceStatus.PENDING })
      .orderBy('service.submittedAt', 'ASC')
      .skip(pagination.skip)
      .take(pagination.limit);

    return qb.getManyAndCount();
  }

  async processActivityApproval(serviceId: string, dto: ActivityApprovalDto, adminId: string): Promise<VenueService> {
    const service = await this.venueServiceRepository.findOne({ where: { id: serviceId } });
    if (!service) throw new NotFoundException('Activity not found');

    if (service.status !== VenueServiceStatus.PENDING) {
      throw new BadRequestException('Only activities pending review can be approved or rejected');
    }

    if (dto.status === VenueServiceStatus.REJECTED && !dto.reason) {
      throw new BadRequestException('Reason is required when rejecting an activity');
    }

    if (dto.status === VenueServiceStatus.APPROVED) {
      service.status = VenueServiceStatus.APPROVED;
      service.isActive = true;
      service.approvedAt = new Date();
      service.approvedBy = adminId;
      service.rejectionReason = null;
    } else {
      service.status = VenueServiceStatus.REJECTED;
      service.rejectionReason = dto.reason;
    }

    const saved = await this.venueServiceRepository.save(service);

    // Notify the venue partner of the admin decision
    const venue = await this.venueRepository.findOne({ where: { id: saved.venueId } });
    if (venue?.partnerId) {
      if (saved.status === VenueServiceStatus.APPROVED) {
        // Re-activate the venue if this is its first approved activity —
        // mirrors the auto-deactivation in removeService() when the last one is deleted
        const approvedCount = await this.venueServiceRepository.count({
          where: { venueId: venue.id, status: VenueServiceStatus.APPROVED },
        });
        if (approvedCount === 1 && (!venue.isActive || !venue.bookingAccept)) {
          await this.venueRepository.update(venue.id, { isActive: true, bookingAccept: true });
        }

        await this.notificationsService.notify(
          venue.partnerId,
          NotificationType.ACTIVITY_APPROVED,
          'Activity approved',
          `${saved.name} is now live`,
          { serviceId: saved.id },
        );
      } else {
        await this.notificationsService.notify(
          venue.partnerId,
          NotificationType.ACTIVITY_REJECTED,
          'Activity rejected',
          `${saved.name} was rejected: ${saved.rejectionReason ?? 'See details'}`,
          { serviceId: saved.id, reason: saved.rejectionReason },
        );
      }
    }

    return saved;
  }

  // ─── Walk-In Slot Booking ──────────────────────────────────────────────────

  private timeToMinutes(time: string): number {
    if (!time) return 0;
    const t = time.trim();
    const hasAmPm = /[AP]M$/i.test(t);
    if (hasAmPm) {
      const parts = t.split(/\s+/);
      let [h, m] = parts[0].split(':').map(Number);
      const mer = parts[1].toUpperCase();
      if (mer === 'PM' && h !== 12) h += 12;
      if (mer === 'AM' && h === 12) h = 0;
      return h * 60 + (m || 0);
    }
    const [h, m] = t.split(':').map(Number);
    return h * 60 + (m || 0);
  }

  private minutesToTime(minutes: number): string {
    const h = Math.floor(minutes / 60) % 24;
    const m = minutes % 60;
    return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;
  }

  async getActivitySlots(
    venueId: string,
    serviceId: string,
    partnerId: string,
    date: string,
    court?: string,
  ) {
    const service = await this.venueServiceRepository.findOne({
      where: { id: serviceId, venueId },
      relations: ['venue'],
    });
    if (!service) throw new NotFoundException('Activity not found');
    if (service.venue.partnerId !== partnerId) throw new ForbiddenException('Access denied');
    if (service.status !== VenueServiceStatus.APPROVED)
      throw new BadRequestException('Activity must be approved to manage walk-in slots');

    const slotDurationMinutes = service.minDuration || 60;
    const venue = service.venue;

    // Get operational windows for the date's day of week
    const dayName = new Date(date + 'T00:00:00')
      .toLocaleDateString('en-US', { weekday: 'long' })
      .toLowerCase();
    const categorySchedule: any[] = venue.availability?.[service.categoryId] || [];
    const dayEntry = categorySchedule.find((d: any) => d.day?.toLowerCase() === dayName);

    const operationalWindows: Array<{ open: number; close: number }> = [];
    if (dayEntry?.slots?.length) {
      for (const slot of dayEntry.slots) {
        const openStr = slot.open ?? slot.openTime;
        const closeStr = slot.close ?? slot.closeTime;
        if (openStr && closeStr) {
          operationalWindows.push({
            open: this.timeToMinutes(openStr),
            close: this.timeToMinutes(closeStr),
          });
        }
      }
    }

    // ACTIV bookings for this service+date
    const activBookings = await this.bookingRepository
      .createQueryBuilder('b')
      .select(['b.startTime', 'b.endTime'])
      .where('b.serviceId = :serviceId', { serviceId })
      .andWhere('b.bookingDate = :date', { date })
      .andWhere("b.status != 'cancelled'")
      .getMany();

    // Walk-in reservations for this service+date+court
    const walkIns = await this.walkInRepository.find({
      where: {
        venueServiceId: serviceId,
        date,
        status: 'reserved' as const,
        court: court ?? IsNull(),
      },
    });

    // Generate full-day slot grid
    const totalSlots = Math.floor(1440 / slotDurationMinutes);
    const slots: Array<{
      startTime: string;
      endTime: string;
      status: string;
      reservationId?: string;
    }> = [];

    for (let i = 0; i < totalSlots; i++) {
      const startMin = i * slotDurationMinutes;
      const endMin = startMin + slotDurationMinutes;
      const startTime = this.minutesToTime(startMin);
      const endTime = this.minutesToTime(endMin >= 1440 ? endMin - 1440 : endMin);

      const isOperational =
        operationalWindows.length > 0 &&
        operationalWindows.some((w) => startMin >= w.open && endMin <= w.close);

      if (!isOperational) {
        slots.push({ startTime, endTime, status: 'not_operational' });
        continue;
      }

      const hasActivBooking = activBookings.some((b) => {
        const bStart = this.timeToMinutes(b.startTime);
        const bEnd = this.timeToMinutes(b.endTime);
        return startMin < bEnd && endMin > bStart;
      });
      if (hasActivBooking) {
        slots.push({ startTime, endTime, status: 'activ_booking' });
        continue;
      }

      const matchedWalkIn = walkIns.find((w) =>
        w.slots.some((s) => {
          const wStart = this.timeToMinutes(s.startTime);
          const wEnd = this.timeToMinutes(s.endTime);
          return startMin < wEnd && endMin > wStart;
        }),
      );
      if (matchedWalkIn) {
        slots.push({ startTime, endTime, status: 'walk_in_reserved', reservationId: matchedWalkIn.id });
        continue;
      }

      slots.push({ startTime, endTime, status: 'available' });
    }

    return {
      serviceId,
      date,
      court: court ?? null,
      slotDurationMinutes,
      courts: service.courts ?? [],
      slots,
    };
  }

  async createWalkIn(
    venueId: string,
    serviceId: string,
    partnerId: string,
    dto: CreateWalkInReservationDto,
  ): Promise<WalkInReservation> {
    const service = await this.venueServiceRepository.findOne({
      where: { id: serviceId, venueId },
      relations: ['venue'],
    });
    if (!service) throw new NotFoundException('Activity not found');
    if (service.venue.partnerId !== partnerId) throw new ForbiddenException('Access denied');
    if (service.status !== VenueServiceStatus.APPROVED)
      throw new BadRequestException('Activity must be approved');

    // Conflict check against existing reserved walk-ins for same court+date
    const existing = await this.walkInRepository.find({
      where: {
        venueServiceId: serviceId,
        date: dto.date,
        status: 'reserved' as const,
        court: dto.court ?? IsNull(),
      },
    });

    for (const res of existing) {
      for (const newSlot of dto.slots) {
        const nStart = this.timeToMinutes(newSlot.startTime);
        const nEnd = this.timeToMinutes(newSlot.endTime);
        const conflict = res.slots.some((s) => {
          const eStart = this.timeToMinutes(s.startTime);
          const eEnd = this.timeToMinutes(s.endTime);
          return nStart < eEnd && nEnd > eStart;
        });
        if (conflict)
          throw new ConflictException('One or more selected slots are already walk-in reserved');
      }
    }

    const reservation = this.walkInRepository.create({
      venueServiceId: serviceId,
      venueId,
      partnerId,
      court: dto.court ?? null,
      date: dto.date,
      slots: dto.slots,
      participantName: dto.participantName,
      participantPhone: dto.participantPhone,
      participantEmail: dto.participantEmail ?? null,
      status: 'reserved',
    });

    return this.walkInRepository.save(reservation);
  }

  async getWalkIns(
    venueId: string,
    serviceId: string,
    partnerId: string,
    date?: string,
  ): Promise<WalkInReservation[]> {
    const service = await this.venueServiceRepository.findOne({
      where: { id: serviceId, venueId },
      relations: ['venue'],
    });
    if (!service) throw new NotFoundException('Activity not found');
    if (service.venue.partnerId !== partnerId) throw new ForbiddenException('Access denied');

    const where: any = { venueServiceId: serviceId, status: 'reserved' };
    if (date) where.date = date;

    return this.walkInRepository.find({ where, order: { date: 'ASC', createdAt: 'ASC' } });
  }

  async getWalkIn(
    venueId: string,
    serviceId: string,
    reservationId: string,
    partnerId: string,
  ): Promise<WalkInReservation> {
    const service = await this.venueServiceRepository.findOne({
      where: { id: serviceId, venueId },
      relations: ['venue'],
    });
    if (!service) throw new NotFoundException('Activity not found');
    if (service.venue.partnerId !== partnerId) throw new ForbiddenException('Access denied');

    const reservation = await this.walkInRepository.findOne({
      where: { id: reservationId, venueServiceId: serviceId },
    });
    if (!reservation) throw new NotFoundException('Reservation not found');
    return reservation;
  }

  async releaseWalkIn(
    venueId: string,
    serviceId: string,
    reservationId: string,
    partnerId: string,
  ): Promise<WalkInReservation> {
    const service = await this.venueServiceRepository.findOne({
      where: { id: serviceId, venueId },
      relations: ['venue'],
    });
    if (!service) throw new NotFoundException('Activity not found');
    if (service.venue.partnerId !== partnerId) throw new ForbiddenException('Access denied');

    const reservation = await this.walkInRepository.findOne({
      where: { id: reservationId, venueServiceId: serviceId },
    });
    if (!reservation) throw new NotFoundException('Reservation not found');
    if (reservation.status === 'released')
      throw new BadRequestException('Reservation is already released');

    reservation.status = 'released';
    return this.walkInRepository.save(reservation);
  }
}
