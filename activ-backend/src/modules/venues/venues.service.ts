import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  Logger,
} from "@nestjs/common";
import type { Category } from "../categories/entities/category.entity";
import * as bcrypt from "bcryptjs";
import * as fs from "fs";
import * as path from "path";
import { randomUUID } from "crypto";
import type * as runtime from "@prisma/client/runtime/client";
import { PDFDocument, StandardFonts, rgb } from "pdf-lib";
import type { Venue } from "./entities/venue.entity";
import type { VenueImage } from "./entities/venue-image.entity";
import type { VenueService } from "./entities/venue-service.entity";
import type { VenueAnswer } from "./entities/venue-answer.entity";
import { CreateVenueDto } from "./dto/create-venue.dto";
import { UpdateVenueDto } from "./dto/update-venue.dto";
import { VenueApprovalDto } from "./dto/venue-approval.dto";
import { AddVenueServiceDto } from "./dto/add-venue-service.dto";
import { CreateVenueActivityDto } from "./dto/create-venue-activity.dto";
import { SetActivityAmenitiesDto } from "./dto/set-activity-amenities.dto";
import { ActivityApprovalDto } from "./dto/activity-approval.dto";
import { VenueStatus } from "../../common/enums/venue-status.enum";
import { VenueServiceStatus } from "../../common/enums/venue-service-status.enum";
import { UserRole } from "../../common/enums/user-role.enum";
import { BookingStatus } from "../../common/enums/booking-status.enum";
import { PaginationDto } from "../../common/dto/pagination.dto";
import type { Partner } from "../partners/entities/partner.entity";
import { MailService } from "../mail/mail.service";
import { QuestionsService } from "../questions/questions.service";
import { NotificationsService } from "../notifications/notifications.service";
import { NotificationType } from "../notifications/entities/notification.entity";
import { AdminNotificationsService } from "../admin-notifications/admin-notifications.service";
import { AdminNotificationType } from "../admin-notifications/entities/admin-notification.entity";
import { PushNotificationsService } from "../push-notifications/push-notifications.service";
import {
  VenueUpdateRequest,
  VenueUpdateRequestStatus,
} from "./entities/venue-update-request.entity";
import { SubmitVenueUpdateDto } from "./dto/submit-venue-update.dto";
import { ReviewVenueUpdateDto } from "./dto/review-venue-update.dto";
import { CreateWalkInReservationDto } from "./dto/create-walk-in-reservation.dto";
import { PrismaService } from "../../prisma/prisma.service";
import { ManageActivityDto } from "./dto/manage-activity.dto";
import { availabilityRows, mapVenueAvailability } from "./venue-table-data";
import { CommissionService } from "../commission/commission.service";
import { deleteVenue } from "./delete-venue";

@Injectable()
export class VenuesService {
  private readonly logger = new Logger(VenuesService.name);
  constructor(
    private readonly mailService: MailService,
    private readonly questionsService: QuestionsService,
    private readonly notificationsService: NotificationsService,
    private readonly adminNotificationsService: AdminNotificationsService,
    private readonly pushNotificationsService: PushNotificationsService,
    private readonly prisma: PrismaService,
    private readonly commissionService: CommissionService,
  ) {}

  async create(
    createVenueDto: CreateVenueDto,
    partnerId: string,
  ): Promise<any> {
    const { services, answers, categoryIds, ...venueData } = createVenueDto;

    if (!categoryIds || categoryIds.length === 0) {
      throw new BadRequestException("At least one categoryId is required");
    }

    const [partner, categories] = await Promise.all([
      this.prisma.partners.findUnique({ where: { id: partnerId } }),
      this.prisma.partner_service_categories.findMany({
        where: { id: { in: categoryIds }, status: "APPROVED" },
        orderBy: { sort_order: "asc" },
      }),
    ]);

    if (!partner) throw new NotFoundException("Partner not found");

    const validCategoryIds = new Set(categories.map((category) => category.id));
    const invalidCategoryIds = categoryIds.filter(
      (id) => !validCategoryIds.has(id),
    );
    if (invalidCategoryIds.length > 0) {
      throw new BadRequestException(
        `Invalid or inactive categoryIds: ${invalidCategoryIds.join(", ")}`,
      );
    }

    if (venueData.latitude == null || venueData.longitude == null) {
      throw new BadRequestException(
        "Venue latitude and longitude are required",
      );
    }

    const categorySlugs = categories.map((category) => category.slug);
    const [activities, { commissionPercentage }] = await Promise.all([
      this.prisma.activities.findMany({
        where: { sport_code: { in: categorySlugs }, status: "PUBLISHED" },
      }),
      this.commissionService.getCommissionByCity(
        venueData.city ?? "",
        venueData.state,
      ),
    ]);
    const now = new Date();
    const venueId = randomUUID();
    const contactPhone = venueData.venuePhone || venueData.phone || null;

    const existingVenue = await this.prisma.$transaction(async (tx) => {
      // Serialize creation per partner so simultaneous retries cannot both insert.
      await tx.$queryRaw`SELECT id FROM partners WHERE id = ${partnerId}::uuid FOR UPDATE`;
      const matches = await tx.venues.findMany({
        where: {
          partner_id: partnerId,
          name: { equals: venueData.name.trim(), mode: "insensitive" },
          city_code: { equals: venueData.city?.trim() || "UNKNOWN", mode: "insensitive" },
          partner_venue_profiles: {
            address_line_1: venueData.venueAddress || venueData.address || null,
          },
        },
        select: { id: true, status: true },
        orderBy: { submitted_at: { sort: "desc", nulls: "last" } },
      });
      const existing = matches.find((venue) => venue.status === "PUBLISHED")
        ?? matches.find((venue) => venue.status === "DRAFT") ?? matches[0] ?? null;
      if (existing) return existing;
      await tx.venues.create({
        data: {
          id: venueId,
          partner_id: partnerId,
          name: venueData.name,
          city_code: venueData.city?.trim() || "UNKNOWN",
          latitude: venueData.latitude,
          longitude: venueData.longitude,
          status: "DRAFT",
          policy_version: "v1",
          commission_percent: commissionPercentage,
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
          opening_time: venueData.openingTime ?? null,
          closing_time: venueData.closingTime ?? null,
          rules: venueData.rules ?? null,
          location_url: venueData.locationUrl ?? null,
          owner_phone_e164: venueData.phone ?? null,
          updated_at: now,
        },
      });

      if (venueData.amenities?.length) {
        await tx.partner_venue_amenities.createMany({
          data: [...new Set(venueData.amenities)].map((title, sort_order) => ({
            venue_id: venueId,
            title,
            sort_order,
          })),
        });
      }
      for (const category of categories) {
        const input =
          services?.find(
            (service) =>
              service.name.toLowerCase() === category.name.toLowerCase(),
          ) ??
          (services?.length === categoryIds.length
            ? services[categoryIds.indexOf(category.id)]
            : undefined);
        await tx.partner_venue_services.create({
          data: {
            id: randomUUID(),
            venue_id: venueId,
            service_category_id: category.id,
            title: input?.name ?? category.name,
            description: input?.description ?? category.description,
            price_per_hour_paise: input
              ? BigInt(Math.round(input.pricePerHour * 100))
              : null,
            min_duration_minutes: input?.minDuration ?? null,
            max_duration_minutes: input?.maxDuration ?? null,
            capacity: input?.capacity ?? null,
            status: "DRAFT",
            updated_at: now,
            partner_service_amenities: {
              create: [...new Set(venueData.amenities ?? [])].map(
                (title, sort_order) => ({ title, sort_order }),
              ),
            },
            ...(input?.imageUrl
              ? {
                  partner_venue_images: {
                    create: {
                      id: randomUUID(),
                      venue_id: venueId,
                      url: input.imageUrl,
                      is_cover: true,
                      updated_at: now,
                    },
                  },
                }
              : {}),
          },
        });
      }

      if (activities.length > 0) {
        await tx.venue_activities.createMany({
          data: activities.map((activity) => ({
            venue_id: venueId,
            activity_id: activity.id,
            status: "PENDING",
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
      return null;
    });

    if (existingVenue) {
      const existing = existingVenue;
      if (existing.status === "PUBLISHED") return this.findOne(existing.id);
      const saved = await this.update(existing.id, createVenueDto as UpdateVenueDto,
        { id: partnerId, role: UserRole.PARTNER });
      if (existing.status === "ARCHIVED") {
        await this.prisma.$transaction([
          this.prisma.venues.update({ where: { id: existing.id },
            data: { status: "DRAFT", review_status: null, rejection_reason: null } }),
          this.prisma.partner_venue_services.updateMany({
            where: { venue_id: existing.id, status: "REJECTED" },
            data: { status: "DRAFT", rejection_reason: null, updated_at: new Date() },
          }),
        ]);
        return this.findOne(existing.id);
      }
      return saved;
    }

    return {
      id: venueId,
      partnerId,
      categoryIds,
      categories: categories.map(({ id, name, slug }) => ({ id, name, slug })),
      ...venueData,
      commission: commissionPercentage,
      status: VenueStatus.DRAFT,
      createdAt: now,
      updatedAt: now,
    };
  }

  // Partner submits venue for admin review (draft → pending)
  async submitForReview(venueId: string, partnerId: string): Promise<any> {
    const venue = await this.prisma.venues.findUnique({
      where: { id: venueId },
    });

    if (!venue) {
      throw new NotFoundException(`Venue with id ${venueId} not found`);
    }

    if (venue.partner_id !== partnerId) {
      throw new ForbiddenException("You can only submit your own venues");
    }

    const signedVenue = await this.findOne(venueId);
    if (!signedVenue.termsAcceptedAt || !signedVenue.electronicSignature?.trim()) {
      throw new BadRequestException("Please sign the partnership agreement before finishing");
    }
    if (venue.status !== "DRAFT") {
      if (venue.submitted_at) {
        const emailResult = await this.sendSignedAgreementIfNeeded(venueId, partnerId, signedVenue);
        return {
          ...signedVenue,
          agreementEmailSent: emailResult.sent,
          agreementEmailError: emailResult.error,
        };
      }
      throw new BadRequestException("Only draft venues can be submitted for review");
    }
    const emailResult = await this.sendSignedAgreementIfNeeded(venueId, partnerId, signedVenue);

    await this.prisma.$transaction([
      this.prisma.venues.update({
        where: { id: venueId },
        data: {
          submitted_at: new Date(),
        },
      }),
      this.prisma.partner_venue_services.updateMany({
        where: { venue_id: venueId, status: "DRAFT" },
        data: { status: "PENDING", updated_at: new Date() },
      }),
    ]);

    return {
      ...(await this.findOne(venueId)),
      agreementEmailSent: emailResult.sent,
      agreementEmailError: emailResult.error,
    };
  }

  private async sendSignedAgreementIfNeeded(
    venueId: string,
    partnerId: string,
    signedVenue: any,
  ): Promise<{ sent: boolean; error?: string }> {
    const recipient = signedVenue.partner?.email?.trim();
    if (!recipient) {
      return { sent: false, error: 'Registration succeeded, but no registered email address is available.' };
    }
    const signedAt = new Date(signedVenue.termsAcceptedAt);
    const signedAtIso = signedAt.toISOString();
    const receipt = await this.prisma.audit_events.findFirst({
      where: {
        action: 'partner_agreement.emailed', entity_type: 'venues', entity_id: venueId,
        after_json: { path: ['signedAt'], equals: signedAtIso },
      },
    });
    if (receipt) return { sent: true };

    const agreement = await this.generatePartnerAgreementPdf(venueId, {
      id: partnerId, role: UserRole.PARTNER,
    });
    const partnerName = [signedVenue.partner?.firstName, signedVenue.partner?.lastName]
      .filter(Boolean)
      .join(' ')
      .trim() || signedVenue.electronicSignature.trim();
    try {
      await this.mailService.sendSignedAgreementEmailViaGmail({
        toEmail: recipient,
        partnerName,
        venueName: signedVenue.name,
        signedAt,
        pdfBuffer: Buffer.from(agreement.base64, 'base64'),
        filename: agreement.filename,
      });
    } catch (error) {
      this.logger.error(
        `Signed agreement email failed: code=${error?.code || 'UNKNOWN'} status=${error?.responseCode || 'unknown'}`,
      );
      return {
        sent: false,
        error: 'Registration succeeded, but the agreement email could not be sent. You can retry it from this screen.',
      };
    }

    await this.prisma.audit_events.create({ data: {
      id: randomUUID(),
      action: 'partner_agreement.emailed', entity_type: 'venues', entity_id: venueId,
      after_json: { email: recipient, signedAt: signedAtIso },
    } });
    return { sent: true };
  }

  async retrySignedAgreementEmail(venueId: string, partnerId: string): Promise<{ sent: boolean; error?: string }> {
    const signedVenue = await this.findOne(venueId);
    if (signedVenue.partnerId !== partnerId && signedVenue.partner?.id !== partnerId) {
      throw new ForbiddenException('You can only retry your own agreement email');
    }
    if (!signedVenue.termsAcceptedAt || !signedVenue.electronicSignature?.trim()) {
      throw new BadRequestException('Please sign the partnership agreement before retrying the email');
    }
    return this.sendSignedAgreementIfNeeded(venueId, partnerId, signedVenue);
  }

  // Partner saves legal info with uploaded document URLs
  async getLegalInfo(venueId: string, callerId: string): Promise<any> {
    const venue = await this.prisma.venues.findUnique({
      where: { id: venueId },
      select: { partner_id: true, partner_venue_legal_documents: true },
    });

    if (!venue) throw new NotFoundException(`Venue with id ${venueId} not found`);
    if (venue.partner_id !== callerId) throw new ForbiddenException('Access denied');

    const legal = venue.partner_venue_legal_documents;
    return {
      aadhaarName: legal?.aadhaar_name ?? null,
      aadhaarNumber: legal?.aadhaar_number ?? null,
      aadhaarCardUrl: legal?.aadhaar_card_url ?? null,
      panNumber: legal?.pan_number ?? null,
      panCardUrl: legal?.pan_card_url ?? null,
      gstNumber: legal?.gst_number ?? null,
      gstName: legal?.gst_name ?? null,
      gstinDocUrl: legal?.gstin_doc_url ?? null,
    };
  }

  async saveLegalInfo(
    venueId: string,
    callerId: string,
    legalData: {
      aadhaarName?: string;
      aadhaarNumber?: string;
      panNumber?: string;
      panCardUrl?: string | null;
      aadhaarCardUrl?: string | null;
      gstNumber?: string;
      gstName?: string;
      gstinDocUrl?: string | null;
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
      throw new ForbiddenException("Access denied");
    }

    const partnerId = venue.partner_id;
    const now = new Date();
    const profileData = {
      ...(legalData.panNumber !== undefined && {
        pan_number: legalData.panNumber,
      }),
      ...(legalData.gstNumber !== undefined && {
        gst_number: legalData.gstNumber,
      }),
      ...(legalData.panCardUrl !== undefined && {
        pan_document_url: legalData.panCardUrl,
      }),
      ...(legalData.gstinDocUrl !== undefined && {
        gst_document_url: legalData.gstinDocUrl,
      }),
      updated_at: now,
    };

    const [, profile] = await this.prisma.$transaction([
      this.prisma.partner_venue_legal_documents.upsert({
        where: { venue_id: venueId },
        create: {
          venue_id: venueId,
          ...this.legalDocumentFields(legalData),
          updated_at: now,
        },
        update: { ...this.legalDocumentFields(legalData), updated_at: now },
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
      throw new ForbiddenException(
        "You can only sign your own venue agreements",
      );
    }

    if (!electronicSignature?.trim()) {
      throw new BadRequestException("Electronic signature is required");
    }
    if (venue.partner_venue_profiles?.terms_accepted_at &&
        venue.partner_venue_profiles.electronic_signature === electronicSignature.trim()) {
      return this.findOne(venueId);
    }

    const acceptedAt = new Date();
    await this.prisma.$transaction([
      this.prisma.partner_venue_profiles.update({
        where: { venue_id: venueId },
        data: {
          terms_accepted_at: acceptedAt,
          electronic_signature: electronicSignature.trim(),
          updated_at: acceptedAt,
        },
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
    signatureOverride?: string,
  ): Promise<{ base64: string; filename: string; mimeType: string }> {
    const venue = await this.findOne(venueId);

    if (
      currentUser.role === UserRole.PARTNER &&
      venue.partnerId !== currentUser.id
    ) {
      throw new ForbiddenException(
        "You can only download your own venue agreement",
      );
    }

    const templatePath = path.join(
      __dirname,
      "..",
      "legal",
      "templates",
      "partner-agreement-template.pdf",
    );
    const templateBytes = fs.readFileSync(templatePath);
    const templateDoc = await PDFDocument.load(templateBytes);

    const outDoc = await PDFDocument.create();
    const copiedPages = await outDoc.copyPages(templateDoc, [0, 1, 2]);
    copiedPages.forEach((p) => outDoc.addPage(p));

    const page3 = outDoc.getPage(2);
    const font = await outDoc.embedFont(StandardFonts.Helvetica);

    const partnerName = venue.partner
      ? `${venue.partner.firstName || ""} ${venue.partner.lastName || ""}`.trim()
      : "";
    const hasSignature = signatureOverride !== undefined
      ? signatureOverride.trim().length > 0
      : Boolean(venue.electronicSignature?.trim());
    const signature = signatureOverride !== undefined
      ? signatureOverride.trim()
      : venue.electronicSignature?.trim() ?? '';
    const acceptanceDate = hasSignature ? venue.termsAcceptedAt : null;
    const isAccepted = hasSignature && Boolean(venue.termsAcceptedAt);
    const acceptedAt = acceptanceDate
      ? new Date(acceptanceDate).toLocaleString("en-IN", {
          timeZone: "Asia/Kolkata",
          day: "2-digit",
          month: "long",
          year: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        })
      : "";

    // Row top-Y positions (PDF points, bottom-up) measured from the
    // template's Agreement Acceptance table on page 3.
    const rows: Array<{ top: number; value: string }> = [
      { top: 603.14, value: partnerName }, // Partner Name
      { top: 564.88, value: venue.name || "" }, // Venue Name
      { top: 526.63, value: venue.partner?.email || "" }, // Registered Email
      { top: 488.38, value: venue.partner?.phone || "" }, // Registered Mobile
      { top: 450.06, value: acceptedAt }, // Date & Time of Acceptance
      {
        top: 411.72,
        value: isAccepted
            ? "Electronic Acceptance via ACTIV Venue Partner App"
            : "",
      }, // Acceptance Method
      { top: 357.33, value: signature }, // Electronic Signature
    ];

    for (const row of rows) {
      // Cover the {{placeholder}} text with white, then draw the real value
      // in roughly the same spot — keeps the table borders/graphics intact.
      page3.drawRectangle({
        x: 328,
        y: row.top - 16,
        width: 405,
        height: 32,
        color: rgb(1, 1, 1),
      });
      page3.drawText(row.value, {
        x: 333,
        y: row.top - 10,
        size: 11,
        font,
        color: rgb(0.12, 0.12, 0.12),
      });
    }

    const pdfBytes = await outDoc.save();
    return {
      base64: Buffer.from(pdfBytes).toString("base64"),
      filename: `activ-partner-agreement-${venue.id}.pdf`,
      mimeType: "application/pdf",
    };
  }

  async findAll(
    pagination: PaginationDto,
    status?: VenueStatus,
    categoryId?: string,
    partnerId?: string,
    filters: { city?: string; state?: string; sort?: 'newest' | 'oldest' | 'updated' } = {},
  ) {
    const statusMap: Record<string, "DRAFT" | "PUBLISHED" | "ARCHIVED"> = {
      draft: "DRAFT",
      pending: "DRAFT",
      approved: "PUBLISHED",
      rejected: "ARCHIVED",
      suspended: "ARCHIVED",
    };
    const where: any = {};
    if (status) where.status = statusMap[status] || undefined;
    if (partnerId) where.partner_id = partnerId;
    const conditions: any[] = [];
    if (status === VenueStatus.SUSPENDED) where.review_status = VenueStatus.SUSPENDED;
    if (status === VenueStatus.REJECTED) conditions.push({
      OR: [{ review_status: null }, { review_status: { not: VenueStatus.SUSPENDED } }],
    });
    if (filters.city?.trim()) conditions.push({ OR: [
      { city_code: { contains: filters.city.trim(), mode: 'insensitive' } },
      { partner_venue_profiles: { city: { contains: filters.city.trim(), mode: 'insensitive' } } },
    ] });
    if (filters.state?.trim()) conditions.push({
      partner_venue_profiles: { state: { contains: filters.state.trim(), mode: 'insensitive' } },
    });
    if (conditions.length) where.AND = conditions;
    if (pagination.search) {
      where.OR = [
        { name: { contains: pagination.search, mode: "insensitive" } },
        { city_code: { contains: pagination.search, mode: "insensitive" } },
      ];
    }
    if (categoryId) {
      where.partner_venue_services = {
        some: { service_category_id: categoryId, status: { not: "ARCHIVED" } },
      };
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
          partner_venue_images: { orderBy: { sort_order: "asc" } },
          partner_venue_services: {
            where: { status: { not: "ARCHIVED" } },
            include: { partner_service_categories: true },
          },
        },
        skip: pagination.skip,
        take: pagination.limit,
        orderBy: [
          { partner_venue_profiles: filters.sort === 'updated'
            ? { updated_at: 'desc' } : { created_at: filters.sort === 'oldest' ? 'asc' : 'desc' } },
          { id: filters.sort === 'oldest' ? 'asc' : 'desc' },
        ],
      }),
      this.prisma.venues.count({ where }),
    ]);

    const items = venues.map((venue) => {
      const profile = venue.partner_venue_profiles;
      const owner = venue.partners.partner_users[0]?.users;
      const ownerNames = (owner?.name || "").trim().split(/\s+/);
      const serviceCategory =
        venue.partner_venue_services[0]?.partner_service_categories;
      const mappedStatus =
        venue.status === "PUBLISHED"
          ? "approved"
          : venue.status === "ARCHIVED"
            ? venue.review_status === VenueStatus.SUSPENDED ? "suspended" : "rejected"
            : "pending";
      return {
        id: venue.id,
        partnerId: venue.partner_id,
        partner: {
          id: venue.partner_id,
          firstName: ownerNames[0] || null,
          lastName: ownerNames.slice(1).join(" ") || null,
          email: owner?.email ?? null,
          businessName:
            venue.partners.partner_business_profiles?.business_name ??
            venue.partners.legal_name,
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
        isActive: venue.status === "PUBLISHED",
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
    if (!partnerId)
      throw new ForbiddenException("Partner identity is required");
    const where = { partner_id: partnerId };
    const [records, total] = await Promise.all([
      this.prisma.venues.findMany({
        where,
        select: { id: true },
        orderBy: { name: "asc" },
        skip: pagination.skip,
        take: pagination.limit,
      }),
      this.prisma.venues.count({ where }),
    ]);
    return [
      await Promise.all(records.map((record) => this.findOne(record.id))),
      total,
    ] as const;
  }

  async pauseBookings(
    id: string,
    partnerId: string,
    bookingAccept: boolean,
  ): Promise<Venue> {
    const venue = await this.findOne(id);
    if (venue.partnerId !== partnerId) {
      throw new ForbiddenException(
        "You can only manage bookings for your own venues",
      );
    }
    await this.prisma.venues.update({
      where: { id },
      data: { booking_accept: bookingAccept },
    });
    const saved = await this.findOne(id);

    const partner = await this.prisma.partners.findUnique({
      where: { id: partnerId },
    });
    const partnerName = partner?.legal_name || "A partner";

    if (bookingAccept === false) {
      await this.adminNotificationsService.notify(
        AdminNotificationType.VENUE_BOOKINGS_PAUSED,
        "Bookings paused",
        `${partnerName} paused bookings for ${venue.name} — follow up to find out why`,
        { partnerId, venueId: id },
      );
    } else {
      await this.adminNotificationsService.notify(
        AdminNotificationType.VENUE_BOOKINGS_RESUMED,
        "Bookings resumed",
        `${partnerName} resumed bookings for ${venue.name}`,
        { partnerId, venueId: id },
      );
    }

    return saved;
  }

  async markWelcomeSeen(venueId: string, partnerId: string): Promise<Venue> {
    const venue = await this.findOne(venueId);
    if (venue.partnerId !== partnerId) {
      throw new ForbiddenException("You can only update your own venues");
    }
    await this.prisma.venues.update({
      where: { id: venueId },
      data: { has_seen_welcome: true },
    });
    return this.findOne(venueId);
  }

  async findApprovedByPartner(partnerId: string): Promise<any[]> {
    if (!partnerId)
      throw new ForbiddenException("Partner identity is required");
    const records = await this.prisma.venues.findMany({
      where: { partner_id: partnerId, status: "PUBLISHED" },
      select: { id: true },
      orderBy: [
        { partner_venue_profiles: { created_at: "desc" } },
        { id: "asc" },
      ],
    });
    const venues = await Promise.all(
      records.map((record) => this.findOne(record.id)),
    );

    // Match by IDs: activity titles can be customized independently of categories.
    return Promise.all(
      venues.map(async (venue) => ({
        ...venue,
        services: await Promise.all(
          (venue.services || []).map(async (service) => {
            // Some lightweight public-venue tests provide only the venue
            // projection; production Prisma clients always expose this model.
            const stats = this.prisma.partner_venue_services
              ? await this.getActivityManagement(service.id, partnerId)
              : null;
            return {
              ...service,
              ...(stats
                ? { bookingCount: stats.bookingCount, earnings: stats.earnings }
                : {}),
              answers: (venue.answers || []).filter(
                (a) =>
                  a.venueServiceId === service.id ||
                  (!a.venueServiceId &&
                    a.question?.categoryId === service.categoryId),
              ),
            };
          }),
        ),
      })),
    );
  }

  async findApproved(pagination: PaginationDto, categoryId?: string) {
    const where: any = {
      status: "PUBLISHED",
      booking_accept: true,
      partner_venue_services: {
        some: {
          status: "APPROVED",
          is_active: true,
          ...(categoryId ? { service_category_id: categoryId } : {}),
        },
      },
    };
    if (pagination.search)
      where.OR = [
        { name: { contains: pagination.search, mode: "insensitive" } },
        { city_code: { contains: pagination.search, mode: "insensitive" } },
      ];
    const [records, total] = await Promise.all([
      this.prisma.venues.findMany({
        where,
        select: { id: true },
        skip: pagination.skip,
        take: pagination.limit,
        orderBy: { name: "asc" },
      }),
      this.prisma.venues.count({ where }),
    ]);
    return [
      await Promise.all(
        records.map((record) => this.findPublicVenue(record.id)),
      ),
      total,
    ] as const;
  }

  async findAdminVenue(id: string) {
    const venue = await this.findOne(id);
    const review = await this.prisma.venues.findUnique({
      where: { id },
      select: {
        status: true,
        submitted_at: true,
        approved_at: true,
        approved_by: true,
        review_status: true,
        rejection_reason: true,
        partner_venue_legal_documents: true,
      },
    });
    if (!review) throw new NotFoundException(`Venue with id ${id} not found`);
    const approver = review.approved_by
      ? await this.prisma.users.findUnique({
          where: { id: review.approved_by },
          select: { name: true },
        })
      : null;
    const legal = review.partner_venue_legal_documents;
    return {
      ...venue,
      status:
        review.status === "DRAFT" && review.submitted_at
          ? VenueStatus.PENDING
          : review.status === "ARCHIVED" &&
              review.review_status === VenueStatus.SUSPENDED
            ? VenueStatus.SUSPENDED
            : venue.status,
      submittedAt: review.submitted_at,
      approvedAt: review.approved_at,
      approvedBy: review.approved_by,
      approvedByName: approver?.name?.trim() || null,
      rejectionReason: review.rejection_reason,
      partner: {
        ...venue.partner,
        aadhaarName: legal?.aadhaar_name ?? null,
        aadhaarNumber: legal?.aadhaar_number ?? null,
        aadhaarCardUrl: legal?.aadhaar_card_url ?? null,
        panNumber: legal?.pan_number ?? null,
        panCardUrl: legal?.pan_card_url ?? null,
        gstNumber: legal?.gst_number ?? null,
        gstName: legal?.gst_name ?? null,
        gstinDocUrl: legal?.gstin_doc_url ?? null,
      },
    };
  }

  async findPublicVenue(id: string) {
    const venue = await this.findOne(id);
    if (venue.status !== VenueStatus.APPROVED || !venue.bookingAccept)
      throw new NotFoundException("Venue not available");
    const services = venue.services.filter(
      (service) =>
        service.status === VenueServiceStatus.APPROVED && service.isActive,
    );
    const publicServices = services.map((service) => {
      const serviceAvailability = (service as any).availability ?? [];
      const timing = Object.fromEntries(
        serviceAvailability.map((day: any) => [
          day.day[0].toUpperCase() + day.day.slice(1).toLowerCase(),
          day.slots.map((slot) => ({
            open: slot.openTime,
            close: slot.closeTime,
            openTime: slot.openTime,
            closeTime: slot.closeTime,
            capacity: slot.capacity,
            price: slot.price,
            discountedPrice: slot.discountedPrice,
          })),
        ]),
      );
      return {
        ...service,
        // Backward-compatible names used by the existing consumer app.
        activity_id: service.id,
        activityName: service.name,
        operate_value: {
          id: service.categoryId,
          title: service.name,
          categoryName: service.category?.name ?? service.name,
        },
        venue_timing: timing,
        venue_amenities: { place_offer: service.amenities ?? [] },
        // Keep the normalized availability while also exposing the day-keyed
        // shape used by the user app's current slot picker.
        venueTiming: timing,
        timing,
      };
    });
    // The user app needs activity content, not partner identity or legal documents.
    return {
      id: venue.id,
      name: venue.name,
      description: venue.description,
      address: venue.address,
      flatBuilding: venue.flatBuilding,
      city: venue.city,
      state: venue.state,
      zipCode: venue.zipCode,
      country: venue.country,
      latitude: venue.latitude,
      longitude: venue.longitude,
      venuePhone: venue.venuePhone,
      locationUrl: venue.locationUrl,
      rules: venue.rules,
      amenities: venue.amenities,
      status: venue.status,
      isActive: true,
      bookingAccept: true,
      openingTime: venue.openingTime,
      closingTime: venue.closingTime,
      services: publicServices,
      // The consumer app historically reads activities rather than services.
      activities: publicServices,
      categories: venue.categories.filter((category) =>
        services.some((service) => service.categoryId === category.id),
      ),
      images: venue.images.filter(
        (image: any) =>
          !image.venueServiceId ||
          services.some((service) => service.id === image.venueServiceId),
      ),
      availability: Object.fromEntries(
        Object.entries(venue.availability ?? {}).filter(([categoryId]) =>
          services.some((service) => service.categoryId === categoryId),
        ),
      ),
    };
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
        partner_venue_amenities: { orderBy: { sort_order: "asc" } },
        partner_venue_availability: {
          orderBy: [{ day: "asc" }, { sort_order: "asc" }],
        },
        partner_venue_images: { orderBy: { sort_order: "asc" } },
        partner_venue_services: {
          include: {
            partner_service_categories: true,
            partner_venue_images: { orderBy: { sort_order: "asc" } },
            partner_service_amenities: { orderBy: { sort_order: "asc" } },
          },
        },
        partner_venue_answers: {
          include: {
            partner_service_questions: {
              include: { partner_service_categories: true },
            },
          },
        },
      },
    });

    if (!venue) {
      throw new NotFoundException(`Venue with id ${id} not found`);
    }

    const profile = venue.partner_venue_profiles;
    const availability = mapVenueAvailability(venue.partner_venue_availability);
    const businessProfile = venue.partners.partner_business_profiles;
    const owner = venue.partners.partner_users[0]?.users;
    const ownerNames = (owner?.name || "").trim().split(/\s+/);

    return {
      id: venue.id,
      partnerId: venue.partner_id,
      partner: {
        id: venue.partner_id,
        firstName: ownerNames[0] || null,
        lastName: ownerNames.slice(1).join(" ") || null,
        email: owner?.email ?? businessProfile?.email ?? null,
        phone: owner?.phone_e164 ?? businessProfile?.phone_e164 ?? null,
        businessName:
          businessProfile?.business_name ?? venue.partners.legal_name,
      } as Partner,
      categories: venue.partner_venue_services.filter((service) => service.status !== "ARCHIVED").map((service) => ({
        id: service.partner_service_categories.id,
        name: service.partner_service_categories.name,
        description: service.partner_service_categories.description,
      })) as Category[],
      name: profile?.display_name || venue.name,
      description: profile?.description ?? null,
      address: profile?.address_line_1 ?? null,
      city: profile?.city || venue.city_code,
      state: profile?.state ?? null,
      country: "India",
      zipCode: profile?.postal_code ?? null,
      latitude: Number(venue.latitude),
      longitude: Number(venue.longitude),
      openingTime: profile?.opening_time ?? null,
      closingTime: profile?.closing_time ?? null,
      availability: availability,
      amenities: venue.partner_venue_amenities.map((a) => a.title),
      rules: profile?.rules ?? null,
      phone: profile?.owner_phone_e164 ?? null,
      venuePhone: profile?.contact_phone_e164 ?? null,
      locationUrl: profile?.location_url ?? null,
      flatBuilding: profile?.address_line_2 ?? null,
      venueAddress: profile?.address_line_1 ?? null,
      termsAccepted: Boolean(profile?.terms_accepted_at),
      termsAcceptedAt: profile?.terms_accepted_at ?? null,
      electronicSignature: profile?.electronic_signature ?? null,
      status:
        venue.status === "PUBLISHED"
          ? VenueStatus.APPROVED
          : venue.status === "ARCHIVED"
            ? VenueStatus.REJECTED
            : VenueStatus.DRAFT,
      isActive: venue.status === "PUBLISHED",
      bookingAccept: venue.booking_accept,
      canPermanentlyDelete: venue.status === "ARCHIVED" && !venue.booking_accept,
      hasSeenWelcome: venue.has_seen_welcome,
      commission: Number(venue.commission_percent ?? 10),
      images: venue.partner_venue_images.map((image) => ({
        id: image.id,
        venueId: image.venue_id,
        venueServiceId: image.venue_service_id,
        imageUrl: image.url,
        isPrimary: image.is_primary,
        caption: image.caption,
        createdAt: image.created_at,
      })) as unknown as VenueImage[],
      services: venue.partner_venue_services
        .filter((service) => service.status !== "ARCHIVED")
        .map((service) => ({
          id: service.id,
          venueId: service.venue_id,
          categoryId: service.service_category_id,
          category: service.partner_service_categories
            ? {
                id: service.partner_service_categories.id,
                name: service.partner_service_categories.name,
                description: service.partner_service_categories.description,
              }
            : null,
          name: service.title,
          createdAt: service.created_at,
          updatedAt: service.updated_at,
          submittedAt: service.submitted_at ?? service.updated_at ?? service.created_at,
          approvedAt: service.approved_at,
          rejectionReason: service.rejection_reason,
          description: service.description,
          minDuration: service.min_duration_minutes,
          maxDuration: service.max_duration_minutes,
          capacity: service.capacity,
          pricePerHour:
            service.price_per_hour_paise == null
              ? null
              : Number(service.price_per_hour_paise) / 100,
          status: service.status.toLowerCase() as VenueServiceStatus,
          isActive: service.is_active,
          imageUrls: service.partner_venue_images.map((image) => image.url),
          coverImageUrl:
            service.partner_venue_images.find((image) => image.is_cover)?.url ??
            service.partner_venue_images[0]?.url ??
            null,
          amenities: service.partner_service_amenities.map((a) => a.title),
          availability: availability[service.service_category_id] ?? [],
        })) as unknown as VenueService[],
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
            ? {
                id: answer.partner_service_questions.partner_service_categories
                  .id,
                name: answer.partner_service_questions
                  .partner_service_categories.name,
              }
            : null,
        },
        createdAt: answer.created_at,
        updatedAt: answer.updated_at,
      })) as unknown as VenueAnswer[],
      createdAt: profile?.created_at ?? new Date(0),
      updatedAt: profile?.updated_at ?? new Date(0),
    } as Venue;
  }

  private legalDocumentFields(input: Record<string, any>) {
    const fields: Record<string, string> = {
      aadhaarName: "aadhaar_name",
      aadhaarNumber: "aadhaar_number",
      aadhaarCardUrl: "aadhaar_card_url",
      panNumber: "pan_number",
      panCardUrl: "pan_card_url",
      gstNumber: "gst_number",
      gstName: "gst_name",
      gstinDocUrl: "gstin_doc_url",
    };
    return Object.fromEntries(
      Object.entries(fields)
        .filter(([key]) => input[key] !== undefined)
        .map(([key, column]) => [column, input[key]]),
    );
  }

  private asRecord(value: unknown): Record<string, any> {
    return value && typeof value === "object" && !Array.isArray(value)
      ? (value as Record<string, any>)
      : {};
  }

  async setAvailability(
    venueId: string,
    venueTiming: Record<
      string,
      Record<
        string,
        Array<{
          open: string;
          close: string;
          capacity?: number;
          price?: number;
          discountedPrice?: number;
        }>
      >
    >,
    partnerId: string,
  ): Promise<any> {
    const venue = await this.prisma.venues.findUnique({
      where: { id: venueId },
    });
    if (!venue)
      throw new NotFoundException(`Venue with id ${venueId} not found`);

    if (venue.partner_id !== partnerId) {
      throw new ForbiddenException("You can only update your own venue");
    }

    if (!venueTiming) throw new BadRequestException("venue_timing is required");

    const categories = Object.keys(venueTiming);
    const owned = await this.prisma.partner_venue_services.findMany({
      where: {
        venue_id: venueId,
        service_category_id: { in: categories },
        status: { not: "ARCHIVED" },
      },
      select: { service_category_id: true },
    });
    if (
      categories.some(
        (id) => !owned.some((service) => service.service_category_id === id),
      )
    ) {
      throw new BadRequestException(
        "Schedule category does not belong to this venue",
      );
    }
    const rows = categories.flatMap((id) => availabilityRows(venueId, id, venueTiming[id]));
    const durations = categories.map((id) => {
      const values = [...new Set(Object.values(venueTiming[id]).flat()
        .filter((slot: any) => slot.open !== '-' && slot.close !== '-' && slot.slotDurationMinutes !== undefined)
        .map((slot: any) => Number(slot.slotDurationMinutes)))];
      if (values.length > 1) throw new BadRequestException('Use the same slot size for all time ranges of an activity');
      return { id, minutes: values[0] };
    });
    await this.prisma.$transaction(async (tx) => {
      await tx.partner_venue_availability.deleteMany({ where: {
        venue_id: venueId, service_category_id: { in: categories },
      } });
      if (rows.length) await tx.partner_venue_availability.createMany({ data: rows });
      for (const duration of durations) {
        if (duration.minutes !== undefined) await tx.partner_venue_services.updateMany({
          where: { venue_id: venueId, service_category_id: duration.id, status: { not: 'ARCHIVED' } },
          data: { min_duration_minutes: duration.minutes },
        });
      }
    });
    const availability = mapVenueAvailability(
      await this.prisma.partner_venue_availability.findMany({
        where: { venue_id: venueId },
        orderBy: [{ day: "asc" }, { sort_order: "asc" }],
      }),
    );
    return {
      id: venue.id,
      partnerId: venue.partner_id,
      availability,
      status: venue.status.toLowerCase(),
    };
  }

  // Save / upsert answers for a venue's category questions
  async saveAnswers(
    venueId: string,
    answers: Array<{ questionId: string; answer: any }>,
    partnerId: string,
    venueServiceId?: string,
  ): Promise<any[]> {
    const venue = await this.prisma.venues.findUnique({
      where: { id: venueId },
    });
    if (!venue)
      throw new NotFoundException(`Venue with id ${venueId} not found`);

    if (venue.partner_id !== partnerId) {
      throw new ForbiddenException(
        "You can only save answers for your own venues",
      );
    }

    const partnerUser = await this.prisma.partner_users.findFirst({
      where: { partner_id: partnerId },
      orderBy: { role: "desc" },
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
        saved.push(
          await this.prisma.partner_venue_answers.update({
            where: { id: existing.id },
            data: {
              answer,
              answered_by_partner_user_id: partnerUser?.id ?? null,
              updated_at: new Date(),
            },
          }),
        );
      } else {
        saved.push(
          await this.prisma.partner_venue_answers.create({
            data: {
              id: randomUUID(),
              venue_id: venueId,
              venue_service_id: venueServiceId ?? null,
              question_id: questionId,
              answered_by_partner_user_id: partnerUser?.id ?? null,
              answer,
              updated_at: new Date(),
            },
          }),
        );
      }
    }

    return saved;
  }

  async update(
    id: string,
    updateVenueDto: UpdateVenueDto,
    currentUser: { id: string; role: string },
  ): Promise<Venue> {
    const venue = await this.findOne(id);

    if (
      currentUser.role === UserRole.PARTNER &&
      venue.partnerId !== currentUser.id
    ) {
      throw new ForbiddenException("You can only update your own venues");
    }

    const { services, answers, categoryIds, ...venueData } = updateVenueDto;
    const locationChanged = venueData.city !== undefined || venueData.state !== undefined;
    const commission = currentUser.role === UserRole.PARTNER
      ? (locationChanged || venueData.commission !== undefined)
        ? (await this.commissionService.getCommissionByCity(
            venueData.city ?? venue.city ?? '', venueData.state ?? venue.state,
          )).commissionPercentage
        : undefined
      : venueData.commission;
    const columns: Record<string, string> = {
      name: "display_name",
      description: "description",
      address: "address_line_1",
      venueAddress: "address_line_1",
      flatBuilding: "address_line_2",
      city: "city",
      state: "state",
      zipCode: "postal_code",
      venuePhone: "contact_phone_e164",
      phone: "owner_phone_e164",
      openingTime: "opening_time",
      closingTime: "closing_time",
      locationUrl: "location_url",
      rules: "rules",
    };
    const profile = Object.fromEntries(
      Object.entries(columns)
        .filter(([key]) => venueData[key] !== undefined)
        .map(([key, column]) => [column, venueData[key]]),
    );
    await this.prisma.$transaction(async (tx) => {
      await tx.venues.update({
        where: { id },
        data: {
          ...(venueData.name !== undefined ? { name: venueData.name } : {}),
          ...(venueData.city !== undefined
            ? { city_code: venueData.city }
            : {}),
          ...(venueData.latitude !== undefined
            ? { latitude: venueData.latitude }
            : {}),
          ...(venueData.longitude !== undefined
            ? { longitude: venueData.longitude }
            : {}),
          ...(commission !== undefined
            ? { commission_percent: commission }
            : {}),
        },
      });
      await tx.partner_venue_profiles.upsert({
        where: { venue_id: id },
        create: {
          id: randomUUID(),
          venue_id: id,
          partner_id: venue.partnerId,
          ...profile,
          updated_at: new Date(),
        },
        update: { ...profile, updated_at: new Date() },
      });
      if (venueData.amenities !== undefined) {
        await tx.partner_venue_amenities.deleteMany({
          where: { venue_id: id },
        });
        if (venueData.amenities.length)
          await tx.partner_venue_amenities.createMany({
            data: [...new Set(venueData.amenities)].map(
              (title, sort_order) => ({ venue_id: id, title, sort_order }),
            ),
          });
      }
      if (categoryIds !== undefined) {
        if (categoryIds.length === 0) {
          throw new BadRequestException("At least one categoryId is required");
        }
        const categories = await tx.partner_service_categories.findMany({
          where: { id: { in: categoryIds }, status: "APPROVED" },
        });
        if (categories.length !== new Set(categoryIds).size)
          throw new BadRequestException("Invalid categories");
        await tx.partner_venue_services.updateMany({
          where: {
            venue_id: id,
            service_category_id: { notIn: categoryIds },
            status: { not: "ARCHIVED" },
          },
          data: { status: "ARCHIVED", is_active: false, updated_at: new Date() },
        });
        for (const category of categories) {
          const existing = await tx.partner_venue_services.findFirst({
            where: {
              venue_id: id,
              service_category_id: category.id,
              status: { not: "ARCHIVED" },
            },
          });
          if (!existing)
            await tx.partner_venue_services.create({
              data: {
                id: randomUUID(),
                venue_id: id,
                service_category_id: category.id,
                title: category.name,
                status: "DRAFT",
                updated_at: new Date(),
              },
            });
        }
      }
    });
    if (answers?.length) await this.saveAnswers(id, answers, venue.partnerId);
    if (services?.length) {
      const current = await this.findOne(id);
      for (const input of services) {
        const activity = current.services.find(
          (item) => item.name.toLowerCase() === input.name.toLowerCase(),
        );
        if (!activity)
          throw new BadRequestException(
            "Select an activity category before updating its details",
          );
        await this.updateService(activity.id, input, venue.partnerId);
      }
    }
    const saved = await this.findOne(id);

    if (currentUser.role === UserRole.PARTNER) {
      await this.adminNotificationsService.notify(
        AdminNotificationType.VENUE_UPDATED,
        "Venue updated",
        `${venue.name} was updated by its partner`,
        {
          partnerId: venue.partnerId,
          venueId: venue.id,
          fields: Object.keys(venueData),
        },
      );
    }

    return saved;
  }

  async processApproval(
    id: string,
    approvalDto: VenueApprovalDto,
    adminId: string,
  ): Promise<Venue> {
    const venue = await this.prisma.venues.findUnique({ where: { id } });
    if (!venue) {
      throw new NotFoundException(`Venue with id ${id} not found`);
    }

    if (
      approvalDto.status === VenueStatus.REJECTED ||
      approvalDto.status === VenueStatus.SUSPENDED
    ) {
      if (!approvalDto.reason) {
        throw new BadRequestException(
          "Reason is required when rejecting or suspending a venue",
        );
      }
    }

    const now = new Date();
    const approved = approvalDto.status === VenueStatus.APPROVED;
    const rejected = approvalDto.status === VenueStatus.REJECTED;

    await this.prisma.$transaction([
      this.prisma.venues.update({
        where: { id },
        data: {
          status: approved ? "PUBLISHED" : "ARCHIVED",
          approved_at: approved ? now : null,
          approved_by: approved ? adminId : null,
          rejection_reason: approved ? null : approvalDto.reason,
          review_status: approvalDto.status,
        },
      }),
      this.prisma.partner_venue_services.updateMany({
        where: { venue_id: id, status: { in: ["DRAFT", "PENDING"] } },
        data: approved
          ? {
              status: "APPROVED",
              approved_at: now,
              approved_by: adminId,
              rejection_reason: null,
              updated_at: now,
            }
          : {
              status: "REJECTED",
              rejection_reason: approvalDto.reason,
              updated_at: now,
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
    const partnerUser =
      partner.partner_users.find((link) => link.role === "PARTNER_ADMIN") ??
      partner.partner_users[0];
    if (!partnerUser?.users.email) return;

    // Approval endpoints can be retried by an admin or client. Only send the
    // welcome/login message once after MSG91 has accepted it.
    const approvalEmailReceipt = await this.prisma.audit_events.findFirst({
      where: {
        action: "partner_approval.email_sent",
        entity_type: "venues",
        entity_id: venue.id,
      },
    });
    if (!approvalEmailReceipt) {
      // Generate a strong readable password
      const password = this.generatePassword();

      // Hash and save — also activate the partner account
      const hashedPassword = await bcrypt.hash(password, 10);
      const now = new Date();
      await this.prisma.$transaction([
        this.prisma.users.update({
          where: { id: partnerUser.user_id },
          data: {
            password_hash: hashedPassword,
            status: "ACTIVE",
            updated_at: now,
          },
        }),
        this.prisma.partners.update({
          where: { id: partner.id },
          data: { status: "ACTIVE", updated_at: now },
        }),
      ]);

      // Send email with credentials
      const emailSent = await this.mailService.sendPartnerApprovalEmail({
        toEmail: partnerUser.users.email,
        partnerName:
          partnerUser.users.name ||
          partner.partner_business_profiles?.owner_name ||
          partner.partner_business_profiles?.business_name ||
          partner.legal_name,
        venueName: venue.name,
        password,
      });

      if (emailSent) {
        await this.prisma.audit_events.create({
          data: {
            id: randomUUID(),
            action: "partner_approval.email_sent",
            entity_type: "venues",
            entity_id: venue.id,
            actor_id: null,
            after_json: {
              templateId: "MSG91_APPROVAL_TEMPLATE_ID",
              recipient: partnerUser.users.email,
            },
          },
        });
      }
    }

    await this.notificationsService.notify(
      partner.id,
      NotificationType.VENUE_APPROVED,
      "Venue approved",
      `${venue.name} has been approved and is now live on ACTIV`,
      { venueId: venue.id },
    );

    await this.pushNotificationsService.sendToPartner(
      partner.id,
      "Venue approved",
      `${venue.name} has been approved and is now live on ACTIV`,
      { type: "venue_approved", venueId: venue.id },
    );
  }

  private async handlePartnerRejection(
    venue: Venue,
    reason: string,
  ): Promise<void> {
    const partner = await this.prisma.partners.findUnique({
      where: { id: venue.partnerId },
      include: {
        partner_business_profiles: true,
        partner_users: { include: { users: true } },
      },
    });
    const partnerUser =
      partner?.partner_users.find((link) => link.role === "PARTNER_ADMIN") ??
      partner?.partner_users[0];
    if (!partner || !partnerUser?.users.email) return;

    const fullName =
      partnerUser.users.name ||
      partner.partner_business_profiles?.owner_name ||
      partner.partner_business_profiles?.business_name ||
      partner.legal_name;
    const firstName = fullName.split(" ")[0];

    await this.mailService.sendPartnerRejectionEmail({
      toEmail: partnerUser.users.email,
      firstName,
      venueId: venue.id,
      rejectionReason: reason,
    });
  }

  private generatePassword(): string {
    const chars = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
    const special = "@#$!";
    let password = "";
    for (let i = 0; i < 8; i++) {
      password += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    password += special.charAt(Math.floor(Math.random() * special.length));
    password += Math.floor(Math.random() * 90 + 10);
    return password;
  }

  async remove(
    id: string,
    currentUser: { id: string; role: string },
  ): Promise<{ permanentlyDeleted: boolean }> {
    return this.prisma.$transaction(async (tx) => {
      const [venue] = await tx.$queryRawUnsafe<Array<{
        id: string; partner_id: string; status: string; booking_accept: boolean;
      }>>('SELECT id, partner_id, status, booking_accept FROM venues WHERE id = $1::uuid FOR UPDATE', id);
      if (!venue) throw new NotFoundException(`Venue with id ${id} not found`);
      if (currentUser.role !== UserRole.ADMIN &&
          (currentUser.role !== UserRole.PARTNER || venue.partner_id !== currentUser.id)) {
        throw new ForbiddenException("You can only delete your own venues");
      }
      if (currentUser.role === UserRole.ADMIN && venue.status === "ARCHIVED" && !venue.booking_accept) {
        await deleteVenue(tx, id);
        return { permanentlyDeleted: true };
      }
      await tx.venues.update({ where: { id }, data: { status: "ARCHIVED", booking_accept: false } });
      return { permanentlyDeleted: false };
    }, { maxWait: 10000, timeout: 60000, isolationLevel: 'Serializable' });
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
    replaceImages = false,
  ): Promise<any> {
    const venue = await this.prisma.venues.findUnique({
      where: { id: venueId },
    });

    if (!venue) {
      throw new NotFoundException(`Venue with id ${venueId} not found`);
    }

    if (userRole !== UserRole.ADMIN && venue.partner_id !== userId) {
      throw new ForbiddenException(
        "You can only update images for your own venue services",
      );
    }

    let service = await this.prisma.partner_venue_services.findFirst({
      where: {
        venue_id: venueId,
        ...(categoryId
          ? { service_category_id: categoryId }
          : { title: { equals: serviceName, mode: "insensitive" } }),
      },
    });

    if (!service) {
      const category = categoryId
        ? await this.prisma.partner_service_categories.findUnique({
            where: { id: categoryId },
          })
        : await this.prisma.partner_service_categories.findFirst({
            where: { name: { equals: serviceName, mode: "insensitive" } },
          });
      if (!category) {
        throw new BadRequestException(
          "A valid categoryId is required for this activity",
        );
      }

      service = await this.prisma.partner_venue_services.create({
        data: {
          id: randomUUID(),
          venue_id: venueId,
          service_category_id: category.id,
          title: serviceName || category.name,
          status: "DRAFT",
          updated_at: new Date(),
        },
      });
    }

    if (amenities !== undefined) {
      await this.prisma.partner_venue_services.update({
        where: { id: service.id },
        data: {
          partner_service_amenities: {
            deleteMany: {},
            create: [...new Set(amenities)].map((title, sort_order) => ({
              title,
              sort_order,
            })),
          },
          updated_at: new Date(),
        },
      });
    }
    return this.uploadActivityImages(
      service.id,
      newUrls,
      venue.partner_id,
      replaceImages,
    );
  }

  async setServiceCover(
    serviceId: string,
    coverUrl: string,
    partnerId: string,
  ): Promise<any> {
    await this.findManagedActivity(serviceId, partnerId);
    await this.prisma.$transaction(async (tx) => {
      const image = await tx.partner_venue_images.findFirst({
        where: { venue_service_id: serviceId, url: coverUrl },
      });
      if (!image)
        throw new BadRequestException(
          "Cover image must belong to this activity",
        );
      await tx.partner_venue_images.updateMany({
        where: { venue_service_id: serviceId },
        data: { is_cover: false },
      });
      await tx.partner_venue_images.update({
        where: { id: image.id },
        data: { is_cover: true, updated_at: new Date() },
      });
    });
    return { id: serviceId, imageUrl: coverUrl };
  }

  async deleteServiceImage(
    serviceId: string,
    imageUrl: string,
    partnerId: string,
  ): Promise<any> {
    await this.findManagedActivity(serviceId, partnerId);
    return this.prisma.$transaction(async (tx) => {
      await tx.partner_venue_images.deleteMany({
        where: { venue_service_id: serviceId, url: imageUrl },
      });
      const images = await tx.partner_venue_images.findMany({
        where: { venue_service_id: serviceId },
        orderBy: { sort_order: "asc" },
      });
      if (images.length && !images.some((image) => image.is_cover)) {
        await tx.partner_venue_images.update({
          where: { id: images[0].id },
          data: { is_cover: true, updated_at: new Date() },
        });
      }
      return { id: serviceId, imageUrls: images.map((image) => image.url) };
    });
  }

  // Venue and activity photos share a table with explicit activity foreign keys.
  async addImages(
    venueId: string,
    imageUrls: string[],
    partnerId: string,
  ): Promise<any[]> {
    const venue = await this.findOne(venueId);
    if (venue.partnerId !== partnerId)
      throw new ForbiddenException(
        "You can only add images to your own venues",
      );
    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.partner_venue_images.findMany({
        where: { venue_id: venueId },
        orderBy: { sort_order: "asc" },
      });
      const rows = imageUrls.map((url, index) => ({
        id: randomUUID(),
        venue_id: venueId,
        url,
        sort_order: (existing.at(-1)?.sort_order ?? -1) + index + 1,
        is_primary: !existing.some((image) => image.is_primary) && index === 0,
        updated_at: new Date(),
      }));
      if (rows.length) await tx.partner_venue_images.createMany({ data: rows });
      return rows.map((row) => ({
        id: row.id,
        venueId,
        imageUrl: row.url,
        isPrimary: row.is_primary,
      }));
    });
  }

  async removeImage(imageId: string, partnerId: string): Promise<void> {
    const image = await this.prisma.partner_venue_images.findUnique({
      where: { id: imageId },
      include: { venues: true },
    });
    if (!image) throw new NotFoundException("Image not found");
    if (image.venues.partner_id !== partnerId)
      throw new ForbiddenException("Access denied");
    if (image.venue_service_id)
      await this.deleteServiceImage(
        image.venue_service_id,
        image.url,
        partnerId,
      );
    else
      await this.prisma.partner_venue_images.delete({ where: { id: imageId } });
  }

  async setPrimaryImage(imageId: string, partnerId: string): Promise<any> {
    const image = await this.prisma.partner_venue_images.findUnique({
      where: { id: imageId },
      include: { venues: true },
    });
    if (!image) throw new NotFoundException("Image not found");
    if (image.venues.partner_id !== partnerId)
      throw new ForbiddenException("Access denied");
    await this.prisma.$transaction([
      this.prisma.partner_venue_images.updateMany({
        where: { venue_id: image.venue_id },
        data: { is_primary: false },
      }),
      this.prisma.partner_venue_images.update({
        where: { id: imageId },
        data: { is_primary: true, updated_at: new Date() },
      }),
    ]);
    return {
      id: imageId,
      venueId: image.venue_id,
      imageUrl: image.url,
      isPrimary: true,
    };
  }

  async addService(
    venueId: string,
    serviceDto: AddVenueServiceDto,
    partnerId: string,
  ): Promise<VenueService> {
    const venue = await this.findOne(venueId);
    if (venue.partnerId !== partnerId)
      throw new ForbiddenException(
        "You can only add services to your own venues",
      );
    const category = await this.prisma.partner_service_categories.findFirst({
      where: {
        ...(serviceDto.categoryId
          ? { id: serviceDto.categoryId }
          : { name: { equals: serviceDto.name, mode: "insensitive" } }),
        status: "APPROVED",
      },
    });
    if (!category)
      throw new BadRequestException("Select a valid activity category");
    const record = await this.prisma.partner_venue_services.create({
      data: {
        id: randomUUID(),
        venue_id: venueId,
        service_category_id: category.id,
        title: serviceDto.name,
        status: "DRAFT",
        updated_at: new Date(),
      },
    });
    await this.updateService(
      record.id,
      { ...serviceDto, isActive: undefined },
      partnerId,
    );
    const saved = await this.findOwnedActivity(record.id, partnerId);
    await this.adminNotificationsService.notify(
      AdminNotificationType.ACTIVITY_ADDED,
      "Activity added",
      `"${saved.name}" was added to ${venue.name}`,
      { partnerId, venueId, serviceId: saved.id },
    );
    return saved;
  }

  async updateService(
    serviceId: string,
    serviceDto: Partial<AddVenueServiceDto>,
    partnerId: string,
  ): Promise<VenueService> {
    const service = await this.findManagedActivity(serviceId, partnerId);
    await this.prisma.partner_venue_services.update({
      where: { id: serviceId },
      data: {
        ...(serviceDto.name !== undefined ? { title: serviceDto.name } : {}),
        ...(serviceDto.description !== undefined
          ? { description: serviceDto.description }
          : {}),
        ...(serviceDto.pricePerHour !== undefined
          ? {
              price_per_hour_paise: BigInt(
                Math.round(serviceDto.pricePerHour * 100),
              ),
            }
          : {}),
        ...(serviceDto.minDuration !== undefined
          ? { min_duration_minutes: serviceDto.minDuration }
          : {}),
        ...(serviceDto.maxDuration !== undefined
          ? { max_duration_minutes: serviceDto.maxDuration }
          : {}),
        ...(serviceDto.capacity !== undefined
          ? { capacity: serviceDto.capacity }
          : {}),
        updated_at: new Date(),
      },
    });
    if (serviceDto.isActive !== undefined)
      await this.updateActivityManagement(serviceId, partnerId, {
        isActive: serviceDto.isActive,
        reason: serviceDto.isActive ? undefined : "Partner paused activity",
      });
    if (
      serviceDto.imageUrl &&
      !service.partner_venue_images.some(
        (image) => image.url === serviceDto.imageUrl,
      )
    ) {
      await this.uploadActivityImages(
        serviceId,
        [serviceDto.imageUrl],
        partnerId,
      );
    }
    if (serviceDto.imageUrl)
      await this.setServiceCover(serviceId, serviceDto.imageUrl, partnerId);
    return this.findOwnedActivity(serviceId, partnerId);
  }

  async removeService(serviceId: string, partnerId: string): Promise<void> {
    const service = await this.findManagedActivity(serviceId, partnerId);
    await this.updateActivityManagement(serviceId, partnerId, {}, true);
    await this.adminNotificationsService.notify(
      AdminNotificationType.ACTIVITY_REMOVED,
      "Activity removed",
      `"${service.title}" was removed from ${service.venues.name}`,
      { partnerId, venueId: service.venue_id, serviceId },
    );
    const remaining = await this.prisma.partner_venue_services.count({
      where: { venue_id: service.venue_id, status: { not: "ARCHIVED" } },
    });
    if (remaining === 0)
      await this.prisma.venues.update({
        where: { id: service.venue_id },
        data: { booking_accept: false },
      });
  }

  async getVenueStats() {
    const [total, draft, approved, rejected] = await Promise.all([
      this.prisma.venues.count(),
      this.prisma.venues.count({ where: { status: "DRAFT" } }),
      this.prisma.venues.count({ where: { status: "PUBLISHED" } }),
      this.prisma.venues.count({ where: { status: "ARCHIVED" } }),
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
      Object.entries(dto).filter(
        ([key, value]) =>
          [
            "name",
            "description",
            "address",
            "city",
            "state",
            "zipCode",
            "flatBuilding",
            "latitude",
            "longitude",
            "locationUrl",
            "venuePhone",
          ].includes(key) && value != null,
      ),
    );
    if (Object.keys(changes).length === 0) {
      throw new BadRequestException("Submit at least one changed field");
    }
    if (dto.venuePhone != null) {
      const digits = dto.venuePhone.replace(/\D/g, "");
      if (digits.length < 10 || digits.length > 15) {
        throw new BadRequestException("Enter a valid phone number");
      }
    }
    const request = await this.prisma.$transaction(async (tx) => {
      // Serialize submissions for this venue so two devices cannot create pending duplicates.
      await tx.$queryRaw`SELECT id FROM venues WHERE id = ${venueId}::uuid FOR UPDATE`;
      const venue = await tx.venues.findUnique({ where: { id: venueId } });
      if (!venue) throw new NotFoundException("Venue not found");
      if (venue.partner_id !== partnerId) {
        throw new ForbiddenException(
          "You can only submit update requests for your own venues",
        );
      }
      if (venue.status !== "PUBLISHED") {
        throw new BadRequestException(
          "Only approved venues can submit update requests",
        );
      }
      const existing = await tx.partner_venue_update_requests.findFirst({
        where: { venue_id: venueId, status: "PENDING" },
      });
      if (existing) {
        throw new ConflictException(
          "A pending update request already exists for this venue. Please wait for admin review.",
        );
      }
      return tx.partner_venue_update_requests.create({
        data: {
          id: randomUUID(),
          partner_id: partnerId,
          venue_id: venueId,
          status: "PENDING",
          requested_changes: changes,
          updated_at: new Date(),
        },
      });
    });
    return this.mapVenueUpdateRequest(request);
  }

  async findMyVenueUpdateRequests(
    partnerId: string,
  ): Promise<VenueUpdateRequest[]> {
    if (!partnerId)
      throw new ForbiddenException("Partner identity is required");
    const requests = await this.prisma.partner_venue_update_requests.findMany({
      where: { partner_id: partnerId },
      orderBy: { created_at: "desc" },
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
      where.requested_changes = {
        path: ["name"],
        string_contains: pagination.search,
      };
    }
    const [requests, total] = await Promise.all([
      this.prisma.partner_venue_update_requests.findMany({
        where,
        orderBy: { created_at: "desc" },
        skip: pagination.skip,
        take: pagination.limit,
      }),
      this.prisma.partner_venue_update_requests.count({ where }),
    ]);
    return [
      requests.map((request) => this.mapVenueUpdateRequest(request)),
      total,
    ];
  }

  async findOneVenueUpdateRequest(id: string): Promise<VenueUpdateRequest> {
    const request = await this.prisma.partner_venue_update_requests.findUnique({
      where: { id },
    });
    if (!request) throw new NotFoundException("Venue update request not found");
    return this.mapVenueUpdateRequest(request);
  }

  async approveVenueUpdateRequest(
    id: string,
    adminId?: string,
  ): Promise<Venue> {
    const venueId = await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM partner_venue_update_requests WHERE id = ${id}::uuid FOR UPDATE`;
      const request = await tx.partner_venue_update_requests.findUnique({
        where: { id },
      });
      if (!request)
        throw new NotFoundException("Venue update request not found");
      if (request.status !== "PENDING")
        throw new BadRequestException("Only pending requests can be approved");
      const venue = await tx.venues.findUnique({
        where: { id: request.venue_id },
      });
      if (!venue) throw new NotFoundException("Venue not found");
      const changes = this.asRecord(request.requested_changes);

      const now = new Date();
      await tx.venues.update({
        where: { id: venue.id },
        data: {
          ...(changes.name !== undefined ? { name: changes.name } : {}),
          ...(changes.city !== undefined ? { city_code: changes.city } : {}),
          ...(changes.latitude !== undefined
            ? { latitude: changes.latitude }
            : {}),
          ...(changes.longitude !== undefined
            ? { longitude: changes.longitude }
            : {}),
        },
      });
      const profileData: Record<string, any> = { updated_at: now };
      for (const [field, column] of Object.entries({
        name: "display_name",
        description: "description",
        address: "address_line_1",
        flatBuilding: "address_line_2",
        city: "city",
        state: "state",
        zipCode: "postal_code",
        venuePhone: "contact_phone_e164",
        locationUrl: "location_url",
      })) {
        if (changes[field] !== undefined) profileData[column] = changes[field];
      }
      await tx.partner_venue_profiles.upsert({
        where: { venue_id: venue.id },
        create: {
          id: randomUUID(),
          venue_id: venue.id,
          partner_id: venue.partner_id,
          ...profileData,
          updated_at: now,
        },
        update: profileData,
      });
      await tx.partner_venue_update_requests.update({
        where: { id },
        data: {
          status: "APPROVED",
          reviewed_at: now,
          reviewed_by: adminId ?? null,
          updated_at: now,
        },
      });
      return venue.id;
    });
    const venue = await this.findOne(venueId);
    await this.notificationsService.notify(
      venue.partnerId,
      NotificationType.ADMIN_UPDATE,
      "Venue details approved",
      `${venue.name}: your updated venue details are now live.`,
      { venueId, requestId: id },
    );
    return venue;
  }

  async rejectVenueUpdateRequest(
    id: string,
    dto: ReviewVenueUpdateDto,
    adminId?: string,
  ): Promise<VenueUpdateRequest> {
    const request = await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM partner_venue_update_requests WHERE id = ${id}::uuid FOR UPDATE`;
      const current = await tx.partner_venue_update_requests.findUnique({
        where: { id },
      });
      if (!current)
        throw new NotFoundException("Venue update request not found");
      if (current.status !== "PENDING")
        throw new BadRequestException("Only pending requests can be rejected");
      const now = new Date();
      return tx.partner_venue_update_requests.update({
        where: { id },
        data: {
          status: "REJECTED",
          rejection_reason: dto.adminNotes ?? null,
          reviewed_at: now,
          reviewed_by: adminId ?? null,
          updated_at: now,
        },
      });
    });
    await this.notificationsService.notify(
      request.partner_id,
      NotificationType.ADMIN_UPDATE,
      "Venue changes need attention",
      dto.adminNotes ||
        "Your venue changes were not approved. Please review and submit again.",
      { venueId: request.venue_id, requestId: id },
    );
    return this.mapVenueUpdateRequest(request);
  }

  // ─── Venue Activities (per-category VenueService lifecycle) ───────────────
  // A Venue is approved once at onboarding. Each Activity added afterward is
  // a VenueService scoped to one Category, with its own draft -> pending ->
  // approved/rejected review — independent of the parent Venue's status.

  private async findManagedActivity(serviceId: string, partnerId: string) {
    const service = await this.prisma.partner_venue_services.findUnique({
      where: { id: serviceId },
      include: {
        venues: true,
        partner_venue_images: { orderBy: { sort_order: "asc" } },
        partner_service_amenities: { orderBy: { sort_order: "asc" } },
      },
    });
    if (!service) throw new NotFoundException("Activity not found");
    if (!partnerId || service.venues.partner_id !== partnerId) {
      throw new ForbiddenException(
        "You can only manage activities on your own venues",
      );
    }
    return service;
  }

  private normalizeQuestionLabel(value: unknown): string {
    return String(value ?? "")
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, " ")
      .trim();
  }

  private answerAsText(value: unknown): string {
    if (Array.isArray(value)) return value.map(String).join(", ");
    if (value == null) return "";
    return String(value);
  }

  private answerAsList(value: unknown): string[] {
    if (Array.isArray(value)) return value.map(String).filter(Boolean);
    if (typeof value === "string") {
      return value
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean);
    }
    return value == null ? [] : [String(value)];
  }

  private valueOrFallback<T>(value: unknown, fallback: T): unknown | T {
    if (Array.isArray(value)) return value.length > 0 ? value : fallback;
    if (typeof value === "string") return value.trim() ? value : fallback;
    return value ?? fallback;
  }

  async getActivityManagement(serviceId: string, partnerId: string) {
    const service = await this.findManagedActivity(serviceId, partnerId);
    const activityDetails =
      service.onboarding_data &&
      typeof service.onboarding_data === "object" &&
      !Array.isArray(service.onboarding_data)
        ? (service.onboarding_data as Record<string, unknown>)
        : {};
    const savedAnswers = await this.prisma.partner_venue_answers.findMany({
      where: {
        venue_id: service.venue_id,
        OR: [
          { venue_service_id: service.id },
          {
            venue_service_id: null,
            partner_service_questions: {
              service_category_id: service.service_category_id,
            },
          },
        ],
      },
      include: { partner_service_questions: true },
      orderBy: { updated_at: "asc" },
    });
    const answersByLabel = new Map<string, unknown>();
    for (const answer of savedAnswers) {
      const label = this.normalizeQuestionLabel(
        answer.partner_service_questions?.question,
      );
      if (label) answersByLabel.set(label, answer.answer);
    }
    const answerFor = (labels: string[]) => {
      for (const label of labels) {
        if (answersByLabel.has(this.normalizeQuestionLabel(label))) {
          return answersByLabel.get(this.normalizeQuestionLabel(label));
        }
      }
      return undefined;
    };
    const activityDescription = answerFor(["Activity Description"]);
    const activityCount = answerFor([
      "Total Courts",
      "Total Turfs",
      "Total Nets",
      "Total Arenas",
      "Total Tables",
      "Total Fields",
      "Number of Courts",
    ]);
    const activityType = answerFor([
      "Court Type",
      "Court Surface",
      "Pitch Type",
      "Pitch Surface",
      "Turf Type",
      "Field Type",
      "Table Type",
      "Lane Type",
      "Range Type",
      "Arena Type",
      "Activity Type",
    ]);
    const playingEnvironment = answerFor([
      "Playing Environment",
      "Environment",
    ]);
    const equipmentAvailable = answerFor(["Equipment Available", "Equipment"]);
    const coachingAvailable = answerFor(["Coaching Available", "Coaching"]);
    const recommendedFor = answerFor(["Recommended For"]);
    const facilityId = service.facility_id;
    const where = { slots: { facility_id: facilityId! } };
    const [count, revenue, bookings, reviews, occupancy] = facilityId
      ? await Promise.all([
          this.prisma.bookings.count({ where }),
          this.prisma.bookings.aggregate({
            where: { ...where, status: { in: ["CONFIRMED", "COMPLETED"] } },
            _sum: { total_paise: true },
          }),
          this.prisma.bookings.findMany({
            where,
            orderBy: { starts_at: "desc" },
            take: 100,
            include: {
              users: { select: { name: true } },
              slots: true,
              booking_attempts: { select: { quantity: true } },
            },
          }),
          this.prisma.reviews.findMany({
            where: { bookings: where, status: "PUBLISHED" },
            orderBy: { created_at: "desc" },
            take: 100,
            include: { users: { select: { name: true } } },
          }),
          this.prisma.slots.aggregate({
            where: {
              facility_id: facilityId,
              starts_at: {
                gte: new Date(),
                lte: new Date(Date.now() + 7 * 86400000),
              },
            },
            _sum: { capacity: true, booked_quantity: true },
          }),
        ])
      : ([0, null, [], [], null] as const);
    const [walkIns, walkInAvailability] = await Promise.all([
      this.prisma.partner_walk_in_reservations.findMany({
      where: {
        venue_service_id: service.id,
        status: { not: "CANCELLED" },
      },
      orderBy: { starts_at: "desc" },
      }),
      this.prisma.partner_venue_availability.findMany({
        where: {
          venue_id: service.venue_id,
          service_category_id: service.service_category_id,
        },
      }),
    ]);
    const fallbackWalkInAmount = (reservation: (typeof walkIns)[number]) => {
      if (Number(reservation.amount_paise ?? 0) > 0) {
        return Number(reservation.amount_paise);
      }
      const day = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"][reservation.starts_at.getUTCDay()];
      const start = reservation.starts_at.getUTCHours() * 60 + reservation.starts_at.getUTCMinutes();
      const end = reservation.ends_at.getUTCHours() * 60 + reservation.ends_at.getUTCMinutes();
      const window = walkInAvailability.find((candidate) =>
        candidate.day === day &&
        start >= this.timeToMinutes(candidate.open_time) &&
        end <= this.timeToMinutes(candidate.close_time),
      );
      if (!window) return 0;
      const discounted = Number(window.discounted_price_paise ?? 0);
      return discounted > 0 ? discounted : Number(window.price_paise ?? 0);
    };
    const walkInRevenuePaise = walkIns.reduce(
      (sum, reservation) => sum + fallbackWalkInAmount(reservation),
      0,
    );
    const walkInBookings = walkIns.map((reservation) => ({
      id: reservation.id,
      customerName: reservation.participant_name ?? "Walk-in Customer",
      activity: service.title,
      startsAt: reservation.starts_at,
      endsAt: reservation.ends_at,
      status:
        reservation.status === "COMPLETED"
          ? "Completed"
          : reservation.status === "NO_SHOW"
            ? "No Show"
            : reservation.starts_at <= new Date() && reservation.ends_at > new Date()
              ? "Ongoing"
              : "Upcoming",
      amount: fallbackWalkInAmount(reservation) / 100,
      participants: reservation.participant_count ?? 1,
      source: "WALK_IN",
      phone: reservation.participant_phone_e164,
    }));
    return {
      id: service.id,
      venueId: service.venue_id,
      venueName: service.venues.name,
      categoryId: service.service_category_id,
      name: service.title,
      description: this.answerAsText(
        this.valueOrFallback(
          activityDetails.description,
          activityDescription ?? service.description,
        ),
      ),
      status: service.status.toLowerCase(),
      isActive: service.is_active,
      imageUrls: service.partner_venue_images.map((image) => image.url),
      coverImageUrl:
        service.partner_venue_images.find((image) => image.is_cover)?.url ??
        service.partner_venue_images[0]?.url ??
        null,
      amenities: service.partner_service_amenities.map(
        (amenity) => amenity.title,
      ),
      numberOfCourt: this.answerAsText(
        this.valueOrFallback(activityDetails.numberOfCourt, activityCount),
      ),
      courtType: this.answerAsText(
        this.valueOrFallback(activityDetails.courtType, activityType),
      ),
      playingEnvironment: this.answerAsList(
        this.valueOrFallback(
          activityDetails.playingEnvironment,
          playingEnvironment,
        ),
      ),
      equipmentAvailable: this.answerAsList(
        this.valueOrFallback(
          activityDetails.equipmentAvailable,
          equipmentAvailable,
        ),
      ),
      coachingAvailable: this.answerAsList(
        this.valueOrFallback(
          activityDetails.coachingAvailable,
          coachingAvailable,
        ),
      ),
      recommendedFor: this.answerAsList(
        this.valueOrFallback(activityDetails.recommendedFor, recommendedFor),
      ),
      bookingCount: (facilityId ? count : 0) + walkIns.length,
      earnings: facilityId
        ? Number(revenue?._sum.total_paise ?? 0) / 100 + walkInRevenuePaise / 100
        : walkInRevenuePaise / 100,
      occupancy: occupancy?._sum.capacity
        ? Math.round(
            (Number(occupancy._sum.booked_quantity ?? 0) /
              occupancy._sum.capacity) *
              100,
          )
        : null,
      bookings: [
        ...bookings.map((b) => ({
        id: b.id,
        customerName: b.users.name ?? "Customer",
        activity: service.title,
        startsAt: b.starts_at,
        endsAt: b.slots.ends_at,
        status:
          b.status === "CONFIRMED"
            ? b.starts_at <= new Date() && b.slots.ends_at > new Date()
              ? "Ongoing"
              : "Upcoming"
            : b.status === "COMPLETED"
              ? "Completed"
              : b.status === "CANCELLED"
                ? "Canceled"
                : b.status === "RESCHEDULED"
                  ? "Rescheduled"
                  : "Pending Payment",
        amount: Number(b.total_paise) / 100,
        participants: b.booking_attempts?.quantity ?? 1,
        source: "ACTIV",
      })),
        ...walkInBookings,
      ].sort((a, b) => new Date(b.startsAt).getTime() - new Date(a.startsAt).getTime()),
      reviews: reviews.map((r) => ({
        id: r.id,
        name: r.users.name ?? "Customer",
        rating: r.rating,
        body: r.body ?? "",
        createdAt: r.created_at,
      })),
    };
  }

  async updateActivityManagement(
    serviceId: string,
    partnerId: string,
    dto: ManageActivityDto,
    archive = false,
  ) {
    await this.findManagedActivity(serviceId, partnerId);
    if (dto.name !== undefined && !dto.name.trim())
      throw new BadRequestException("Activity name is required");
    if (dto.isActive === false && !dto.reason?.trim())
      throw new BadRequestException("Choose a reason to pause bookings");
    return this.prisma.$transaction(async (tx) => {
      const service = await tx.partner_venue_services.findUniqueOrThrow({
        where: { id: serviceId },
      });
      const data: Record<string, unknown> = {};
      if (dto.isActive !== undefined && service.status !== "APPROVED") {
        throw new BadRequestException(
          "Only approved activities can be paused or resumed",
        );
      }
      if (service.status === "ARCHIVED")
        throw new BadRequestException("This activity has been deleted");
      if (archive || dto.isActive === false) {
        // Preserve bookings and track exactly which slots this action blocks.
        if (service.facility_id) {
          const slots = await tx.slots.findMany({
            where: {
              facility_id: service.facility_id,
              status: "AVAILABLE",
              starts_at: { gt: new Date() },
            },
            select: { id: true },
          });
          if (slots.length)
            await tx.partner_service_paused_slots.createMany({
              data: slots.map((slot) => ({
                venue_service_id: serviceId,
                slot_id: slot.id,
              })),
              skipDuplicates: true,
            });
          await tx.slots.updateMany({
            where: { id: { in: slots.map((s) => s.id) }, status: "AVAILABLE" },
            data: { status: "BLOCKED" },
          });
        }
        data.is_active = false;
        data.pause_reason = archive ? "Activity deleted" : dto.reason?.trim();
      } else if (dto.isActive === true) {
        if (service.facility_id) {
          const paused = await tx.partner_service_paused_slots.findMany({
            where: { venue_service_id: serviceId },
          });
          await tx.slots.updateMany({
            where: {
              facility_id: service.facility_id,
              id: { in: paused.map((link) => link.slot_id) },
              status: "BLOCKED",
              starts_at: { gt: new Date() },
            },
            data: { status: "AVAILABLE" },
          });
        }
        await tx.partner_service_paused_slots.deleteMany({
          where: { venue_service_id: serviceId },
        });
        data.is_active = true;
        data.pause_reason = null;
      }
      const amenities = dto.amenities?.map((a) => a.trim()).filter(Boolean);
      const onboardingUpdates: Record<string, unknown> = {};
      if (dto.numberOfCourt !== undefined)
        onboardingUpdates.numberOfCourt = dto.numberOfCourt.trim();
      if (dto.courtType !== undefined)
        onboardingUpdates.courtType = dto.courtType.trim();
      if (dto.playingEnvironment !== undefined)
        onboardingUpdates.playingEnvironment = dto.playingEnvironment
          .map((item) => item.trim())
          .filter(Boolean);
      if (dto.equipmentAvailable !== undefined)
        onboardingUpdates.equipmentAvailable = dto.equipmentAvailable
          .map((item) => item.trim())
          .filter(Boolean);
      if (dto.coachingAvailable !== undefined)
        onboardingUpdates.coachingAvailable = dto.coachingAvailable
          .map((item) => item.trim())
          .filter(Boolean);
      if (dto.recommendedFor !== undefined)
        onboardingUpdates.recommendedFor = dto.recommendedFor
          .map((item) => item.trim())
          .filter(Boolean);
      const currentDetails =
        service.onboarding_data &&
        typeof service.onboarding_data === "object" &&
        !Array.isArray(service.onboarding_data)
          ? (service.onboarding_data as Record<string, unknown>)
          : {};
      return tx.partner_venue_services.update({
        where: { id: serviceId },
        data: {
          ...(archive ? { status: "ARCHIVED" } : {}),
          ...(dto.name !== undefined ? { title: dto.name.trim() } : {}),
          ...(dto.description !== undefined
            ? { description: dto.description.trim() }
            : {}),
          ...data,
          ...(Object.keys(onboardingUpdates).length
            ? {
                onboarding_data: {
                  ...currentDetails,
                  ...onboardingUpdates,
                } as runtime.InputJsonValue,
              }
            : {}),
          ...(amenities !== undefined
            ? {
                partner_service_amenities: {
                  deleteMany: {},
                  create: [...new Set(amenities)].map((title, sort_order) => ({
                    title,
                    sort_order,
                  })),
                },
              }
            : {}),
          updated_at: new Date(),
        },
      });
    });
  }

  private async findOwnedActivity(
    serviceId: string,
    partnerId: string,
  ): Promise<VenueService> {
    const record = await this.findManagedActivity(serviceId, partnerId);
    const venue = await this.findOne(record.venue_id);
    const activity = venue.services.find((service) => service.id === serviceId);
    if (!activity) throw new NotFoundException("Activity not found");
    return { ...activity, venue } as VenueService;
  }

  async createActivity(
    venueId: string,
    partnerId: string,
    dto: CreateVenueActivityDto,
  ): Promise<VenueService> {
    const venue = await this.findOne(venueId);
    if (venue.partnerId !== partnerId)
      throw new ForbiddenException(
        "You can only add activities to your own venues",
      );
    if (venue.status !== VenueStatus.APPROVED)
      throw new BadRequestException(
        "Activities can only be added to an approved venue",
      );
    const category = await this.prisma.partner_service_categories.findFirst({
      where: { id: dto.categoryId, status: "APPROVED" },
    });
    if (!category) throw new NotFoundException("Category not found");
    let record = await this.prisma.partner_venue_services.findFirst({
      where: {
        venue_id: venueId,
        service_category_id: dto.categoryId,
        status: { not: "ARCHIVED" },
      },
    });
    if (!record)
      record = await this.prisma.partner_venue_services.create({
        data: {
          id: randomUUID(),
          venue_id: venueId,
          service_category_id: dto.categoryId,
          title: category.name,
          status: "DRAFT",
          updated_at: new Date(),
        },
      });
    else if (record.status === "REJECTED")
      await this.prisma.partner_venue_services.update({
        where: { id: record.id },
        data: {
          status: "DRAFT",
          rejection_reason: null,
          updated_at: new Date(),
        },
      });
    return this.findOwnedActivity(record.id, partnerId);
  }

  // Steps 2/3 — Upload images directly to a known activity (by id, not name lookup)
  async uploadActivityImages(
    serviceId: string,
    newUrls: string[],
    partnerId: string,
    replaceImages = false,
  ): Promise<any> {
    const service = await this.findManagedActivity(serviceId, partnerId);
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM partner_venue_services WHERE id = ${serviceId}::uuid FOR UPDATE`;
      if (replaceImages) {
        await tx.partner_venue_images.deleteMany({
          where: { venue_service_id: serviceId },
        });
      }
      const images = await tx.partner_venue_images.findMany({
        where: { venue_service_id: serviceId },
        orderBy: { sort_order: "asc" },
      });
      const nextOrder = (images.at(-1)?.sort_order ?? -1) + 1;
      if (newUrls.length) {
        await tx.partner_venue_images.createMany({
          data: newUrls.map((url, index) => ({
            id: randomUUID(),
            venue_id: service.venue_id,
            venue_service_id: serviceId,
            url,
            caption: service.title,
            sort_order: nextOrder + index,
            is_cover: images.length === 0 && index === 0,
            updated_at: new Date(),
          })),
        });
      }
      const amenities = service.partner_service_amenities.map((a) => a.title);
      return {
        id: serviceId,
        venueId: service.venue_id,
        categoryId: service.service_category_id,
        name: service.title,
        description: service.description,
        status: service.status.toLowerCase(),
        imageUrls: [...images.map((image) => image.url), ...newUrls],
        imageUrl:
          images.find((image) => image.is_cover)?.url ??
          images[0]?.url ??
          newUrls[0] ??
          null,
        amenities,
      };
    });
  }

  // Step 4 — Question set for the activity's category + any answers already saved
  async getActivityQuestions(serviceId: string, partnerId: string) {
    const service = await this.findOwnedActivity(serviceId, partnerId);

    const [questions, answers] = await Promise.all([
      service.categoryId
        ? this.questionsService.findByCategoryId(service.categoryId)
        : Promise.resolve([]),
      this.prisma.partner_venue_answers.findMany({
        where: { venue_service_id: serviceId },
      }),
    ]);

    const answerMap = new Map(answers.map((a) => [a.question_id, a.answer]));

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
  ): Promise<any[]> {
    const service = await this.findManagedActivity(serviceId, partnerId);
    return this.saveAnswers(service.venue_id, answers, partnerId, serviceId);
  }

  async setActivityAmenities(
    serviceId: string,
    dto: SetActivityAmenitiesDto,
    partnerId: string,
  ): Promise<VenueService> {
    await this.updateActivityManagement(serviceId, partnerId, {
      amenities: dto.amenities,
    });
    return this.findOwnedActivity(serviceId, partnerId);
  }

  async saveActivityDraft(
    serviceId: string,
    partnerId: string,
  ): Promise<VenueService> {
    const service = await this.findManagedActivity(serviceId, partnerId);
    if (!["DRAFT", "REJECTED"].includes(service.status))
      throw new BadRequestException(
        "Only draft or rejected activities can be saved as draft",
      );
    await this.prisma.partner_venue_services.update({
      where: { id: serviceId },
      data: { status: "DRAFT", updated_at: new Date() },
    });
    return this.findOwnedActivity(serviceId, partnerId);
  }

  // "Submit for review" — draft/rejected -> pending. Validates the minimums
  // that the wizard screens advertise (4+ images, 1+ amenity, required answers).
  async submitActivityForReview(
    serviceId: string,
    partnerId: string,
  ): Promise<VenueService> {
    const service = await this.findOwnedActivity(serviceId, partnerId);

    if (
      service.status !== VenueServiceStatus.DRAFT &&
      service.status !== VenueServiceStatus.REJECTED
    ) {
      throw new BadRequestException(
        "Only draft or rejected activities can be submitted for review",
      );
    }

    if ((service.imageUrls || []).length < 4) {
      throw new BadRequestException(
        "Please upload at least 4 images before submitting",
      );
    }

    if (!service.amenities || service.amenities.length < 1) {
      throw new BadRequestException(
        "Please select at least one amenity before submitting",
      );
    }

    if (service.categoryId) {
      const questions = await this.questionsService.findByCategoryId(
        service.categoryId,
      );
      const requiredIds = questions
        .filter((q) => q.isRequired)
        .map((q) => q.id);

      if (requiredIds.length > 0) {
        const answers = await this.prisma.partner_venue_answers.findMany({
          where: { venue_service_id: serviceId },
        });
        const answeredIds = new Set(answers.map((a) => a.question_id));
        const missing = requiredIds.some((id) => !answeredIds.has(id));

        if (missing) {
          throw new BadRequestException(
            "Please answer all required activity-specific questions before submitting",
          );
        }
      }
    }

    await this.prisma.partner_venue_services.update({
      where: { id: serviceId },
      data: {
        status: "PENDING",
        submitted_at: new Date(),
        rejection_reason: null,
        updated_at: new Date(),
      },
    });
    const saved = await this.findOwnedActivity(serviceId, partnerId);

    await this.notificationsService.notify(
      partnerId,
      NotificationType.ACTIVITY_UNDER_REVIEW,
      "Activity under review",
      `${saved.name} has been submitted and is being reviewed by ACTIV`,
      { serviceId: saved.id },
    );

    return saved;
  }

  // Step 8 — combined review payload: images + amenities + answers + slots
  async getActivityDetail(serviceId: string, partnerId: string) {
    const service = await this.findOwnedActivity(serviceId, partnerId);
    const venue = await this.findOne(service.venueId);
    return {
      ...service,
      venue: undefined,
      answers: venue.answers.filter(
        (answer) => answer.venueServiceId === serviceId,
      ),
      slots: venue.availability?.[service.categoryId] ?? [],
    };
  }

  async findVenueActivitiesFull(venueId: string, partnerId: string) {
    const venue = await this.findOne(venueId);
    if (venue.partnerId !== partnerId)
      throw new ForbiddenException(
        "You can only view activities for your own venues",
      );
    return Promise.all(
      venue.services.map(async (service) => {
        const stats = await this.getActivityManagement(service.id, partnerId);
        return {
          ...service,
          bookingCount: stats.bookingCount,
          earnings: stats.earnings,
        };
      }),
    );
  }

  async findVenueActivities(
    venueId: string,
    partnerId: string,
    statusFilter?: "active" | "in_review" | "draft" | "inactive",
  ) {
    const activities = await this.findVenueActivitiesFull(venueId, partnerId);
    return activities.filter((service) =>
      statusFilter === "active"
        ? service.status === VenueServiceStatus.APPROVED && service.isActive
        : statusFilter === "inactive"
          ? service.status === VenueServiceStatus.APPROVED && !service.isActive
          : statusFilter === "in_review"
            ? service.status === VenueServiceStatus.PENDING
            : statusFilter === "draft"
              ? service.status === VenueServiceStatus.DRAFT
              : true,
    );
  }

  async toggleActivityActive(
    serviceId: string,
    partnerId: string,
    isActive: boolean,
    reason?: string,
  ): Promise<VenueService> {
    await this.updateActivityManagement(serviceId, partnerId, {
      isActive,
      reason,
    });
    return this.findOwnedActivity(serviceId, partnerId);
  }

  // "Add New Activity" mobile wizard — the app collects everything locally
  // (category, photos, answers, amenities, timing) across 5 screens and fires
  // ONE combined call at the end. This composes the granular methods above
  // instead of duplicating their logic.
  async submitFullActivity(
    venueId: string,
    partnerId: string,
    options: { categoryId: string; action: "draft" | "submit" },
    imageUrls: string[],
    answers: Array<{ questionId: string; answer: any }>,
    amenities: string[],
    timing: Record<
      string,
      Array<{
        open_time?: string;
        close_time?: string;
        slot_price?: string;
        discounted_price?: string;
        max_members?: string;
      }>
    >,
  ): Promise<VenueService> {
    const service = await this.createActivity(venueId, partnerId, {
      categoryId: options.categoryId,
    });

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
        Record<
          string,
          Array<{
            open: string;
            close: string;
            capacity?: number;
            price?: number;
            discountedPrice?: number;
          }>
        >
      > = { [options.categoryId]: {} };

      for (const [day, slots] of Object.entries(timing)) {
        venueTiming[options.categoryId][day] = (slots || []).map((s) => ({
          open: s.open_time ?? "-",
          close: s.close_time ?? "-",
          capacity: s.max_members ? parseInt(s.max_members, 10) : undefined,
          price: s.slot_price ? parseFloat(s.slot_price) : undefined,
          discountedPrice: s.discounted_price
            ? parseFloat(s.discounted_price)
            : undefined,
        }));
      }

      await this.setAvailability(venueId, venueTiming, partnerId);
    }

    return options.action === "submit"
      ? this.submitActivityForReview(service.id, partnerId)
      : this.saveActivityDraft(service.id, partnerId);
  }

  // ─── Admin: Activity Approval ──────────────────────────────────────────────

  async findPendingActivities(
    pagination: PaginationDto,
  ): Promise<[VenueService[], number]> {
    const where = { status: "PENDING" as const };
    const [records, total] = await Promise.all([
      this.prisma.partner_venue_services.findMany({
        where,
        include: { venues: true },
        orderBy: { submitted_at: "asc" },
        skip: pagination.skip,
        take: pagination.limit,
      }),
      this.prisma.partner_venue_services.count({ where }),
    ]);
    return [
      await Promise.all(
        records.map((record) =>
          this.findOwnedActivity(record.id, record.venues.partner_id),
        ),
      ),
      total,
    ];
  }

  async processActivityApproval(
    serviceId: string,
    dto: ActivityApprovalDto,
    adminId: string,
  ): Promise<VenueService> {
    const record = await this.prisma.partner_venue_services.findUnique({
      where: { id: serviceId },
      include: { venues: true },
    });
    if (!record) throw new NotFoundException("Activity not found");
    if (record.status !== "PENDING")
      throw new BadRequestException(
        "Only activities pending review can be approved or rejected",
      );
    if (
      ![VenueServiceStatus.APPROVED, VenueServiceStatus.REJECTED].includes(
        dto.status,
      )
    ) {
      throw new BadRequestException("Select approved or rejected");
    }
    const approved = dto.status === VenueServiceStatus.APPROVED;
    if (!approved && !dto.reason?.trim())
      throw new BadRequestException(
        "Reason is required when rejecting an activity",
      );
    await this.prisma.partner_venue_services.update({
      where: { id: serviceId },
      data: {
        status: approved ? "APPROVED" : "REJECTED",
        reviewed_by: adminId,
        approved_by: approved ? adminId : null,
        approved_at: approved ? new Date() : null,
        rejection_reason: approved ? null : dto.reason,
        ...(approved ? { is_active: true } : {}),
        updated_at: new Date(),
      },
    });
    const saved = await this.findOwnedActivity(
      serviceId,
      record.venues.partner_id,
    );
    await this.notificationsService.notify(
      record.venues.partner_id,
      approved
        ? NotificationType.ACTIVITY_APPROVED
        : NotificationType.ACTIVITY_REJECTED,
      approved ? "Activity approved" : "Activity rejected",
      approved
        ? `${saved.name} is now live`
        : `${saved.name} was rejected: ${dto.reason}`,
      { serviceId, ...(!approved ? { reason: dto.reason } : {}) },
    );
    return saved;
  }

  // ─── Walk-In Slot Booking ──────────────────────────────────────────────────

  private timeToMinutes(time: string): number {
    if (!time) return 0;
    const t = time.trim();
    const hasAmPm = /[AP]M$/i.test(t);
    if (hasAmPm) {
      const parts = t.split(/\s+/);
      let [h, m] = parts[0].split(":").map(Number);
      const mer = parts[1].toUpperCase();
      if (mer === "PM" && h !== 12) h += 12;
      if (mer === "AM" && h === 12) h = 0;
      return h * 60 + (m || 0);
    }
    const [h, m] = t.split(":").map(Number);
    return h * 60 + (m || 0);
  }

  private minutesToTime(minutes: number): string {
    const h = Math.floor(minutes / 60) % 24;
    const m = minutes % 60;
    return `${h.toString().padStart(2, "0")}:${m.toString().padStart(2, "0")}`;
  }

  async getActivitySlots(
    venueId: string,
    serviceId: string,
    partnerId: string,
    date: string,
    court?: string,
  ) {
    const service = await this.prisma.partner_venue_services.findFirst({
      where: { id: serviceId, venue_id: venueId },
      include: { venues: true },
    });
    if (!service) throw new NotFoundException("Activity not found");
    if (service.venues.partner_id !== partnerId)
      throw new ForbiddenException("Access denied");
    if (service.status !== "APPROVED")
      throw new BadRequestException(
        "Activity must be approved to manage walk-in slots",
      );

    const slotDurationMinutes = service.min_duration_minutes || 60;

    // Get operational windows for the date's day of week
    const dayName = new Date(date + "T00:00:00")
      .toLocaleDateString("en-US", { weekday: "long" })
      .toLowerCase();
    const availability = await this.prisma.partner_venue_availability.findMany({
      where: {
        venue_id: venueId,
        service_category_id: service.service_category_id,
        day: dayName,
      },
      orderBy: { sort_order: "asc" },
    });

    const operationalWindows: Array<{ open: number; close: number }> = [];
    for (const slot of availability) {
      operationalWindows.push({
        open: this.timeToMinutes(slot.open_time),
        close: this.timeToMinutes(slot.close_time),
      });
    }

    // ACTIV bookings for this service+date
    const dayStart = new Date(`${date}T00:00:00.000Z`);
    const dayEnd = new Date(`${date}T23:59:59.999Z`);
    const activBookings = service.facility_id
      ? await this.prisma.bookings.findMany({
          where: {
            status: { not: "CANCELLED" },
            starts_at: { lt: dayEnd },
            slots: {
              facility_id: service.facility_id,
              ends_at: { gt: dayStart },
            },
          },
          include: { slots: true },
        })
      : [];

    // Walk-in reservations for this service+date+court
    const walkIns = await this.prisma.partner_walk_in_reservations.findMany({
      where: {
        venue_service_id: serviceId,
        status: "RESERVED",
        starts_at: { lt: dayEnd },
        ends_at: { gt: dayStart },
        notes: court ? { contains: `Court: ${court}` } : undefined,
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
      const endTime = this.minutesToTime(
        endMin >= 1440 ? endMin - 1440 : endMin,
      );

      const isOperational =
        operationalWindows.length > 0 &&
        operationalWindows.some((w) => startMin >= w.open && endMin <= w.close);

      if (!isOperational) {
        slots.push({ startTime, endTime, status: "not_operational" });
        continue;
      }

      const hasActivBooking = activBookings.some((b) => {
        const bStart = this.dateTimeToMinutes(b.slots.starts_at);
        const bEnd = this.dateTimeToMinutes(b.slots.ends_at);
        return startMin < bEnd && endMin > bStart;
      });
      if (hasActivBooking) {
        slots.push({ startTime, endTime, status: "activ_booking" });
        continue;
      }

      const matchedWalkIn = walkIns.find((w) =>
        startMin < this.dateTimeToMinutes(w.ends_at) &&
        endMin > this.dateTimeToMinutes(w.starts_at),
      );
      if (matchedWalkIn) {
        slots.push({
          startTime,
          endTime,
          status: "walk_in_reserved",
          reservationId: matchedWalkIn.id,
        });
        continue;
      }

      slots.push({ startTime, endTime, status: "available" });
    }

    return {
      serviceId,
      date,
      court: court ?? null,
      slotDurationMinutes,
      courts: this.courtsFromOnboardingData(service.onboarding_data),
      slots,
    };
  }

  private dateTimeToMinutes(value: Date): number {
    return value.getUTCHours() * 60 + value.getUTCMinutes();
  }

  private courtsFromOnboardingData(value: unknown): string[] {
    if (!value || typeof value !== "object" || Array.isArray(value)) return [];
    const data = value as Record<string, unknown>;
    const courts = data.courts;
    if (Array.isArray(courts)) return courts.map(String);
    const totalCourts = Number(data.numberOfCourt ?? data.totalCourts ?? 0);
    if (!Number.isFinite(totalCourts) || totalCourts <= 0) return [];
    return Array.from(
      { length: totalCourts },
      (_, index) => `Court ${String(index + 1).padStart(2, "0")}`,
    );
  }

  async createWalkIn(
    venueId: string,
    serviceId: string,
    partnerId: string,
    dto: CreateWalkInReservationDto,
  ): Promise<any> {
    const service = await this.prisma.partner_venue_services.findFirst({
      where: { id: serviceId, venue_id: venueId },
      include: { venues: true },
    });
    if (!service) throw new NotFoundException("Activity not found");
    if (service.venues.partner_id !== partnerId)
      throw new ForbiddenException("Access denied");
    if (service.status !== "APPROVED")
      throw new BadRequestException("Activity must be approved");

    const requestedSlots = dto.slots.map((slot) => ({
      ...slot,
      startsAt: this.walkInDateTime(dto.date, slot.startTime),
      endsAt: this.walkInDateTime(dto.date, slot.endTime),
    }));
    if (!requestedSlots.length) {
      throw new BadRequestException("Select at least one slot");
    }
    for (const slot of requestedSlots) {
      if (slot.endsAt <= slot.startsAt) {
        throw new BadRequestException("Slot end time must be after start time");
      }
    }
    const dayStart = new Date(`${dto.date}T00:00:00.000Z`);
    const dayEnd = new Date(`${dto.date}T23:59:59.999Z`);
    const notes = [
      dto.court ? `Court: ${dto.court}` : null,
      dto.participantEmail ? `Email: ${dto.participantEmail}` : null,
      dto.paymentMethod ? `Payment method: ${dto.paymentMethod}` : null,
      dto.paymentStatus ? `Payment status: ${dto.paymentStatus}` : null,
      dto.notes?.trim() ? `Note: ${dto.notes.trim()}` : null,
      dto.idempotencyKey ? `Idempotency-Key: ${dto.idempotencyKey}` : null,
    ].filter((value): value is string => Boolean(value));

    const reservations = await this.prisma.$transaction(async (tx) => {
      // Serialize reservations for the same activity/date/court. This closes
      // the race between the conflict read and the inserts.
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${`${serviceId}:${dto.date}:${dto.court ?? "all"}`}))`;
      if (dto.idempotencyKey) {
        const previous = await tx.partner_walk_in_reservations.findFirst({
          where: {
            venue_service_id: serviceId,
            partner_id: partnerId,
            status: { not: "CANCELLED" },
            notes: { contains: `Idempotency-Key: ${dto.idempotencyKey}` },
          },
        });
        if (previous) {
          return [previous];
        }
      }
      const dayName = new Date(`${dto.date}T00:00:00Z`)
        .toLocaleDateString("en-US", { weekday: "long" })
        .toLowerCase();
      const windows = await tx.partner_venue_availability.findMany({
        where: {
          venue_id: venueId,
          service_category_id: service.service_category_id,
          day: dayName,
        },
      });
      if (!windows.length || requestedSlots.some((slot) => {
        const start = this.timeToMinutes(slot.startTime);
        const end = this.timeToMinutes(slot.endTime);
        return !windows.some((window) => start >= this.timeToMinutes(window.open_time) && end <= this.timeToMinutes(window.close_time));
      })) {
        throw new BadRequestException("One or more selected slots are outside operating hours");
      }
      const configuredAmountFor = (slot: { startTime: string; endTime: string }) => {
        const start = this.timeToMinutes(slot.startTime);
        const end = this.timeToMinutes(slot.endTime);
        const window = windows.find((candidate) =>
          start >= this.timeToMinutes(candidate.open_time) &&
          end <= this.timeToMinutes(candidate.close_time),
        );
        if (!window) return 0;
        const discounted = Number(window.discounted_price_paise ?? 0);
        return discounted > 0 ? discounted : Number(window.price_paise ?? 0);
      };
      if (service.facility_id) {
        const activBookings = await tx.bookings.findMany({
          where: {
            status: { not: "CANCELLED" },
            starts_at: { lt: dayEnd },
            slots: {
              facility_id: service.facility_id,
              ends_at: { gt: dayStart },
            },
          },
          include: { slots: true },
        });
        if (activBookings.some((booking) => requestedSlots.some((slot) =>
          slot.startsAt < booking.slots.ends_at && slot.endsAt > booking.slots.starts_at))) {
          throw new ConflictException("One or more selected slots are already booked by ACTIV");
        }
      }
      const existing = await tx.partner_walk_in_reservations.findMany({
        where: {
          venue_service_id: serviceId,
          status: "RESERVED",
          starts_at: { lt: dayEnd },
          ends_at: { gt: dayStart },
          notes: dto.court ? { contains: `Court: ${dto.court}` } : undefined,
        },
      });
      for (const res of existing) {
        for (const newSlot of requestedSlots) {
          if (newSlot.startsAt < res.ends_at && newSlot.endsAt > res.starts_at) {
            throw new ConflictException("One or more selected slots are already walk-in reserved");
          }
        }
      }
      return Promise.all(requestedSlots.map((slot) =>
        tx.partner_walk_in_reservations.create({
          data: {
            id: randomUUID(),
            partner_id: partnerId,
            venue_id: venueId,
            facility_id: service.facility_id,
            venue_service_id: serviceId,
            participant_name: dto.participantName,
            participant_phone_e164: dto.participantPhone,
            starts_at: slot.startsAt,
            ends_at: slot.endsAt,
            status: "RESERVED",
            amount_paise: dto.amountPaise == null
              ? BigInt(configuredAmountFor(slot))
              : BigInt(dto.amountPaise),
            notes: notes.join("\n") || null,
            updated_at: new Date(),
          },
        }),
      ));
    });

    return {
      id: reservations[0]?.id,
      venueServiceId: serviceId,
      venueId,
      partnerId,
      court: dto.court ?? null,
      date: dto.date,
      slots: dto.slots,
      participantName: dto.participantName,
      participantPhone: dto.participantPhone,
      participantEmail: dto.participantEmail ?? null,
      status: "reserved",
      reservations,
    };
  }

  private walkInDateTime(date: string, time: string): Date {
    return new Date(`${date}T${time}:00.000Z`);
  }

  async getWalkIns(
    venueId: string,
    serviceId: string,
    partnerId: string,
    date?: string,
  ): Promise<any[]> {
    await this.assertOwnedVenueService(venueId, serviceId, partnerId);
    const dayStart = date ? new Date(`${date}T00:00:00.000Z`) : undefined;
    const dayEnd = date ? new Date(`${date}T23:59:59.999Z`) : undefined;
    const reservations = await this.prisma.partner_walk_in_reservations.findMany({
      where: {
        venue_service_id: serviceId,
        status: "RESERVED",
        ...(dayStart && dayEnd
          ? { starts_at: { lt: dayEnd }, ends_at: { gt: dayStart } }
          : {}),
      },
      orderBy: [{ starts_at: "asc" }, { created_at: "asc" }],
    });
    return reservations.map((reservation) =>
      this.mapWalkInReservation(reservation),
    );
  }

  async getWalkIn(
    venueId: string,
    serviceId: string,
    reservationId: string,
    partnerId: string,
  ): Promise<any> {
    await this.assertOwnedVenueService(venueId, serviceId, partnerId);
    const reservation = await this.prisma.partner_walk_in_reservations.findFirst({
      where: { id: reservationId, venue_service_id: serviceId },
    });
    if (!reservation) throw new NotFoundException("Reservation not found");
    return this.mapWalkInReservation(reservation);
  }

  async releaseWalkIn(
    venueId: string,
    serviceId: string,
    reservationId: string,
    partnerId: string,
  ): Promise<any> {
    await this.assertOwnedVenueService(venueId, serviceId, partnerId);
    const reservation = await this.prisma.partner_walk_in_reservations.findFirst({
      where: { id: reservationId, venue_service_id: serviceId },
    });
    if (!reservation) throw new NotFoundException("Reservation not found");
    if (reservation.status !== "RESERVED")
      throw new BadRequestException("Reservation is already released");

    const released = await this.prisma.partner_walk_in_reservations.update({
      where: { id: reservation.id },
      data: { status: "CANCELLED", updated_at: new Date() },
    });
    return this.mapWalkInReservation(released);
  }

  private async assertOwnedVenueService(
    venueId: string,
    serviceId: string,
    partnerId: string,
  ) {
    const service = await this.prisma.partner_venue_services.findFirst({
      where: { id: serviceId, venue_id: venueId },
      include: { venues: true },
    });
    if (!service) throw new NotFoundException("Activity not found");
    if (service.venues.partner_id !== partnerId)
      throw new ForbiddenException("Access denied");
    return service;
  }

  private mapWalkInReservation(reservation: any) {
    const notes = String(reservation.notes ?? "");
    const courtMatch = notes.match(/^Court: (.+)$/m);
    const emailMatch = notes.match(/^Email: (.+)$/m);
    const paymentMethodMatch = notes.match(/^Payment method: (.+)$/m);
    const paymentStatusMatch = notes.match(/^Payment status: (.+)$/m);
    return {
      id: reservation.id,
      venueServiceId: reservation.venue_service_id,
      venueId: reservation.venue_id,
      partnerId: reservation.partner_id,
      court: courtMatch?.[1] ?? null,
      date: reservation.starts_at.toISOString().slice(0, 10),
      slots: [
        {
          startTime: this.minutesToTime(this.dateTimeToMinutes(reservation.starts_at)),
          endTime: this.minutesToTime(this.dateTimeToMinutes(reservation.ends_at)),
        },
      ],
      participantName: reservation.participant_name,
      participantPhone: reservation.participant_phone_e164,
      participantEmail: emailMatch?.[1] ?? null,
      paymentMethod: paymentMethodMatch?.[1] ?? null,
      paymentStatus: paymentStatusMatch?.[1] ?? null,
      amountPaise: reservation.amount_paise?.toString() ?? null,
      status: reservation.status.toLowerCase(),
      createdAt: reservation.created_at,
    };
  }
}
