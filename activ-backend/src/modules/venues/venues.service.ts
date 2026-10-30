import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  Logger,
} from "@nestjs/common";
import type { CategoryRecord as Category, VenueRecord as Venue, VenueImageRecord as VenueImage, VenueServiceRecord as VenueService, VenueAnswerRecord as VenueAnswer, PartnerRecord as Partner, VenueUpdateRequestRecord as VenueUpdateRequest } from '../../common/domain-types';
import * as bcrypt from "bcryptjs";
import * as fs from "fs";
import * as path from "path";
import { randomUUID, randomInt } from "crypto";
import type * as runtime from "@prisma/client/runtime/client";
import { PDFDocument, StandardFonts } from "pdf-lib";
import { fillAgreementAcceptance } from './agreement-pdf-layout';
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
import { MailService } from "../mail/mail.service";
import { PartnerEmailService } from '../mail/partner-email.service';
import { QuestionsService } from "../questions/questions.service";
import { NotificationsService } from "../notifications/notifications.service";
import { NotificationType } from '../../common/domain-types';
import { AdminNotificationsService } from "../admin-notifications/admin-notifications.service";
import { AdminNotificationType } from '../../common/domain-types';
import { PushNotificationsService } from "../push-notifications/push-notifications.service";
import { VenueUpdateRequestStatus } from '../../common/domain-types';
import { SubmitVenueUpdateDto } from "./dto/submit-venue-update.dto";
import { ReviewVenueUpdateDto } from "./dto/review-venue-update.dto";
import { CreateWalkInReservationDto } from "./dto/create-walk-in-reservation.dto";
import { PrismaService } from "../../prisma/prisma.service";
import { ManageActivityDto } from "./dto/manage-activity.dto";
import { availabilityRows, mapVenueAvailability } from "./venue-table-data";
import { CommissionService } from "../commission/commission.service";
import { deleteVenue } from "./delete-venue";
import { syncLegacyActivityVisibility } from './activity-visibility';
import { attendanceStatus, INDIA_OFFSET_MS } from '../bookings/booking-expiry';
import { paymentMethodLabel } from '../payments/payment-method';
import { lockSlotsForCapacity } from '../bookings/slot-capacity-coordinator';
import { effectiveSlotOccupancy } from '../bookings/slot-capacity';

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
    private readonly partnerEmailService?: PartnerEmailService,
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
            data: { status: "DRAFT", review_status: null, rejection_reason: null, submitted_at: null } }),
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
    if (venue.submitted_at) {
      const emailResult = await this.sendSignedAgreementIfNeeded(venueId, partnerId, signedVenue);
      return {
        ...signedVenue,
        agreementEmailSent: emailResult.sent,
        agreementEmailError: emailResult.error,
      };
    }
    if (venue.status !== "DRAFT") {
      throw new BadRequestException("Only draft venues can be submitted for review");
    }
    const emailResult = await this.sendSignedAgreementIfNeeded(venueId, partnerId, signedVenue);

    const [submission] = await this.prisma.$transaction([
      this.prisma.venues.updateMany({
        where: { id: venueId, submitted_at: null },
        data: {
          submitted_at: new Date(),
          review_status: VenueStatus.PENDING,
          rejection_reason: null,
        },
      }),
      this.prisma.partner_venue_services.updateMany({
        where: { venue_id: venueId, status: "DRAFT" },
        data: { status: "PENDING", updated_at: new Date() },
      }),
    ]);

    if (submission.count > 0) {
      await this.partnerEmailService?.send(partnerId, 'venue_under_review', { venueName: venue.name, reference: venueId, deliveryKey: `venue-submitted:${venueId}:${signedVenue.termsAcceptedAt}` });
      await this.adminNotificationsService.notify(
        AdminNotificationType.VENUE_SUBMITTED,
        'Venue submitted for review',
        `${venue.name} is ready for admin review.`,
        { partnerId, venueId },
      );
    }
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
        deliveryKey: `agreement:${venueId}:${signedAtIso}`,
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

    fillAgreementAcceptance(page3, font, [
      partnerName,
      venue.name || '',
      venue.partner?.email || '',
      venue.partner?.phone || '',
      acceptedAt,
      isAccepted ? 'Electronic Acceptance via ACTIV Venue Partner App' : '',
      signature,
    ]);

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
    await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM venues WHERE id = ${id}::uuid FOR UPDATE`;
      await tx.venues.update({ where: { id }, data: { booking_accept: bookingAccept } });
      await syncLegacyActivityVisibility(tx, id);
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
      changesRequested: review.status === 'DRAFT' && !review.submitted_at && review.review_status === VenueStatus.PENDING && !!review.rejection_reason,
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
      venueReference: venue.publicReference ?? null,
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
            : venue.submitted_at ? VenueStatus.PENDING : VenueStatus.DRAFT,
      rejectionReason: venue.rejection_reason,
      changesRequested: venue.status === 'DRAFT' && !venue.submitted_at && venue.review_status === VenueStatus.PENDING && !!venue.rejection_reason,
      isActive: venue.status === "PUBLISHED",
      bookingAccept: venue.booking_accept,
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
          activityReference: service.public_reference ?? null,
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

  /**
   * The user app still reads the legacy facilities/slots projection. Keep it
   * in sync with the partner scheduling tables whenever a partner saves a
   * schedule or an activity becomes approved. This is deliberately a data
   * sync, not a schema change.
   */
  private async syncLegacyActivitySlots(venueId: string): Promise<void> {
    const prisma = this.prisma as any;
    if (!prisma.facilities || !prisma.slots || !prisma.activities) return;

    await this.prisma.$transaction(async (tx) => {
      // Serialize generation with pause/resume so a concurrent schedule save
      // cannot recreate bookable slots or re-publish a paused activity.
      await tx.$queryRaw`SELECT id FROM venues WHERE id = ${venueId}::uuid FOR UPDATE`;
      await this.syncLegacyActivitySlotsInTransaction(tx, venueId);
      await syncLegacyActivityVisibility(tx, venueId);
    }, { maxWait: 10000, timeout: 60000 });
  }

  private async syncLegacyActivitySlotsInTransaction(prisma: any, venueId: string): Promise<void> {

    const services = await prisma.partner_venue_services.findMany({
      where: { venue_id: venueId, status: "APPROVED", is_active: true },
      include: { partner_service_categories: true },
    });

    for (const service of services) {
      const category = service.partner_service_categories;
      const activity = await prisma.activities.findFirst({
        where: {
          status: "PUBLISHED",
          OR: [
            { sport_code: category.slug },
            { name: { equals: service.title, mode: "insensitive" } },
            { name: { equals: category.name, mode: "insensitive" } },
          ],
        },
      });
      if (!activity) {
        this.logger.warn(
          `No published catalogue activity found for ${service.title} (${category.slug}); legacy slots were not generated`,
        );
        continue;
      }

      await prisma.venue_activities.upsert({
        where: { venue_id_activity_id: { venue_id: venueId, activity_id: activity.id } },
        create: { venue_id: venueId, activity_id: activity.id, status: "APPROVED" },
        update: { status: "APPROVED" },
      });

      let facility = service.facility_id
        ? await prisma.facilities.findUnique({ where: { id: service.facility_id } })
        : await prisma.facilities.findFirst({
            where: { venue_id: venueId, activity_id: activity.id },
          });
      if (!facility) {
        facility = await prisma.facilities.create({
          data: {
            id: randomUUID(),
            venue_id: venueId,
            activity_id: activity.id,
            name: service.title || activity.name,
            capacity: service.capacity ?? 1,
          },
        });
      }
      if (service.facility_id !== facility.id) {
        await prisma.partner_venue_services.update({
          where: { id: service.id },
          data: { facility_id: facility.id },
        });
      }

      const windows = await prisma.partner_venue_availability.findMany({
        where: { venue_id: venueId, service_category_id: service.service_category_id },
        orderBy: [{ day: "asc" }, { sort_order: "asc" }],
      });
      if (!windows.length) continue;

      // Availability is configured as venue-local wall time.  ACTIV venues
      // currently operate in India, so build the calendar in IST and only
      // then convert each slot to UTC for timestamptz storage.
      const horizonStart = this.istDateForOffset(new Date(), 0);
      const horizonEnd = new Date(horizonStart);
      horizonEnd.setUTCDate(horizonEnd.getUTCDate() + 14);
      const existing = await prisma.slots.findMany({
        where: {
          facility_id: facility.id,
          starts_at: { gte: this.istWallTimeToUtc(horizonStart, 0), lt: this.istWallTimeToUtc(horizonEnd, 0) },
        },
      });
      const existingKeys = new Set(
        existing.map((slot: any) => `${slot.starts_at.toISOString()}|${slot.ends_at.toISOString()}`),
      );
      const data: any[] = [];
      const dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
      const duration = Math.max(30, service.min_duration_minutes ?? 60);

      for (let date = new Date(horizonStart); date < horizonEnd; date.setUTCDate(date.getUTCDate() + 1)) {
        const day = dayNames[date.getUTCDay()];
        for (const window of windows.filter((entry: any) => entry.day.toLowerCase() === day)) {
          const open = this.timeToMinutes(window.open_time);
          const close = this.timeToMinutes(window.close_time);
          for (let start = open; start + duration <= close; start += duration) {
            const startsAt = this.istWallTimeToUtc(date, start);
            const endsAt = new Date(startsAt.getTime() + duration * 60_000);
            const key = `${startsAt.toISOString()}|${endsAt.toISOString()}`;
            if (existingKeys.has(key)) continue;
            existingKeys.add(key);
            const discounted = Number(window.discounted_price_paise ?? 0);
            data.push({
              id: randomUUID(),
              facility_id: facility.id,
              starts_at: startsAt,
              ends_at: endsAt,
              capacity: Number(window.capacity || service.capacity || 1),
              status: "AVAILABLE",
              price_paise: BigInt(discounted > 0 ? discounted : Number(window.price_paise ?? service.price_per_hour_paise ?? 0)),
            });
          }
        }
      }
      if (data.length) await prisma.slots.createMany({ data });

      // A schedule update can shorten a window (for example 23:00 → 20:00).
      // The old implementation only appended missing slots, leaving those
      // obsolete AVAILABLE slots bookable. Block only unbooked slots that are
      // no longer part of the desired schedule; booked/protected slots remain
      // untouched for reconciliation and audit purposes.
      const desiredKeys = new Set<string>();
      for (let date = new Date(horizonStart); date < horizonEnd; date.setUTCDate(date.getUTCDate() + 1)) {
        const day = dayNames[date.getUTCDay()];
        for (const window of windows.filter((entry: any) => entry.day.toLowerCase() === day)) {
          const open = this.timeToMinutes(window.open_time);
          const close = this.timeToMinutes(window.close_time);
          for (let start = open; start + duration <= close; start += duration) {
            const startsAt = this.istWallTimeToUtc(date, start);
            const endsAt = new Date(startsAt.getTime() + duration * 60_000);
            desiredKeys.add(`${startsAt.toISOString()}|${endsAt.toISOString()}`);
          }
        }
      }
      const existingFuture = await prisma.slots.findMany({
        where: { facility_id: facility.id, starts_at: { gte: horizonStart, lt: horizonEnd } },
        select: {
          id: true,
          starts_at: true,
          ends_at: true,
          booked_quantity: true,
          status: true,
          booking_attempts: {
            where: { status: { in: ["HELD", "PAYMENT_PROCESSING"] }, expires_at: { gt: new Date() } },
            select: { id: true },
          },
        },
      });
      const staleIds = existingFuture
        .filter((slot: any) =>
          slot.status === "AVAILABLE" &&
          slot.booked_quantity === 0 &&
          slot.booking_attempts.length === 0 &&
          !desiredKeys.has(`${slot.starts_at.toISOString()}|${slot.ends_at.toISOString()}`),
        )
        .map((slot: any) => slot.id);
      if (staleIds.length) {
        await prisma.slots.updateMany({
          where: { id: { in: staleIds }, status: "AVAILABLE", booked_quantity: 0 },
          data: { status: "BLOCKED" },
        });
      }
    }
  }

  private istDateForOffset(now: Date, offset: number) {
    const istNow = new Date(now.getTime() + 330 * 60_000);
    return new Date(Date.UTC(
      istNow.getUTCFullYear(),
      istNow.getUTCMonth(),
      istNow.getUTCDate() + offset,
    ));
  }

  private istWallTimeToUtc(day: Date, minutesFromMidnight: number) {
    return new Date(Date.UTC(
      day.getUTCFullYear(),
      day.getUTCMonth(),
      day.getUTCDate(),
      Math.floor(minutesFromMidnight / 60) - 5,
      minutesFromMidnight % 60 - 30,
    ));
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
    await this.syncLegacyActivitySlots(venueId);
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
    if (approvalDto.status === VenueStatus.APPROVED) return this.approveVenueAtomically(id, adminId);
    const venue = await this.prisma.venues.findUnique({ where: { id } });
    if (!venue) {
      throw new NotFoundException(`Venue with id ${id} not found`);
    }

    if (approvalDto.status === VenueStatus.PENDING) {
      const reason = approvalDto.reason?.trim();
      if (!reason) throw new BadRequestException('A reason is required when requesting changes');
      if (venue.status !== 'DRAFT') {
        throw new BadRequestException('Changes can only be requested before venue approval');
      }
      if (!venue.submitted_at && venue.review_status === VenueStatus.PENDING && venue.rejection_reason === reason) return this.findOne(id);
      await this.commitVenueReview(venue, {
        status: 'DRAFT', submitted_at: null, review_status: VenueStatus.PENDING,
        rejection_reason: reason, approved_at: null, approved_by: null,
      }, { status: 'DRAFT', submitted_at: null, updated_at: new Date() });
      const updated = await this.findOne(id);
      await this.notificationsService.notify(updated.partnerId, NotificationType.ADMIN_UPDATE,
        'Changes requested for your venue', `${updated.name}: ${reason}`, { venueId: id });
      await this.pushNotificationsService.sendToPartner(updated.partnerId,
        'Changes requested for your venue', `${updated.name}: ${reason}`,
        { type: 'venue_changes_requested', venueId: id });
      if (updated.partner?.email) {
        await this.mailService.sendVenueChangesRequestedEmail({
          toEmail: updated.partner.email, venueName: updated.name, reason, partnerName: [updated.partner?.firstName, updated.partner?.lastName].filter(Boolean).join(' '),
          deliveryKey: `venue-changes:${id}:${venue.submitted_at?.toISOString?.() || 'initial'}:${reason}`,
        });
      }
      return updated;
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
    const rejected = approvalDto.status === VenueStatus.REJECTED;

    await this.commitVenueReview(venue, {
      status: 'ARCHIVED', approved_at: null, approved_by: null,
      rejection_reason: approvalDto.reason, review_status: approvalDto.status,
    }, { status: 'REJECTED', rejection_reason: approvalDto.reason, updated_at: now });

    const updatedVenue = await this.findOne(id);
    if (rejected) {
      await this.handlePartnerRejection(updatedVenue, approvalDto.reason, `venue-rejected:${id}:${now.toISOString()}`);
    } else if (approvalDto.status === VenueStatus.SUSPENDED &&
        !(venue.status === 'ARCHIVED' && venue.review_status === VenueStatus.SUSPENDED)) {
      await this.mailService.sendSuspensionEmail({
        toEmail: updatedVenue.partner?.email,
        partnerName: [updatedVenue.partner?.firstName, updatedVenue.partner?.lastName].filter(Boolean).join(' '),
        venueName: updatedVenue.name,
        deliveryKey: `venue-suspended:${id}:${now.toISOString()}`,
        reason: approvalDto.reason,
      });
    }

    return this.findOne(id);
  }

  /** Serialize review decisions with publication and reject a stale admin action. */
  private async commitVenueReview(venue: any, venueData: any, activityData: any): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM venues WHERE id = ${venue.id}::uuid FOR UPDATE`;
      const current = await tx.venues.findUnique({ where: { id: venue.id } });
      if (!current) throw new NotFoundException('Venue not found');
      const version = (row: any) => JSON.stringify([row.status, row.review_status ?? null,
        row.submitted_at ?? null, row.approved_at ?? null, row.rejection_reason ?? null]);
      if (version(current) !== version(venue)) throw new ConflictException('Venue review changed; refresh before submitting another decision');
      await tx.venues.update({ where: { id: venue.id }, data: venueData });
      await tx.partner_venue_services.updateMany({
        where: { venue_id: venue.id, status: { in: ['DRAFT', 'PENDING'] } }, data: activityData,
      });
    }, { isolationLevel: 'ReadCommitted', maxWait: 10000, timeout: 60000 });
  }

  /** All approval database effects commit together; no transport runs in this transaction. */
  private async approveVenueAtomically(id: string, adminId: string): Promise<Venue> {
    const outcome = await this.prisma.$transaction(async (tx) => {
      const hint = await tx.venues.findUnique({ where: { id }, select: { partner_id: true } });
      if (!hint) throw new NotFoundException('Venue not found');
      // Shared partner lock serializes approvals for different venues of one owner.
      await tx.$queryRaw`SELECT id FROM partners WHERE id = ${hint.partner_id}::uuid FOR UPDATE`;
      await tx.$queryRaw`SELECT id FROM venues WHERE id = ${id}::uuid FOR UPDATE`;
      const venue = await tx.venues.findUnique({ where: { id }, include: { partner_venue_profiles: true } });
      if (!venue) throw new NotFoundException('Venue not found');
      if (venue.partner_id !== hint.partner_id) throw new ConflictException('Venue ownership changed; refresh before approving');
      const venueName = venue.partner_venue_profiles?.display_name || venue.name;
      if (venue.status === 'PUBLISHED') return { changed: false, partnerId: venue.partner_id, venueName, deliveryId: null };

      const partner = await tx.partners.findUnique({ where: { id: venue.partner_id }, include: {
        partner_business_profiles: true, partner_users: { where: { role: 'PARTNER_ADMIN' }, include: { users: true } },
      } });
      if (!partner) throw new NotFoundException('Partner not found');
      if (partner.status === 'SUSPENDED') throw new BadRequestException('Reactivate the partner account before approving its venue');
      const owner = partner.partner_users.find(link => link.role === 'PARTNER_ADMIN');
      if (!owner) throw new BadRequestException('A registered partner owner is required before approval');
      await tx.$queryRaw`SELECT id FROM users WHERE id = ${owner.user_id}::uuid FOR UPDATE`;
      const account = await tx.users.findUnique({ where: { id: owner.user_id } });
      if (!account || account.status === 'DELETED' || account.status === 'SUSPENDED') {
        throw new BadRequestException('An available partner owner account is required before approval');
      }
      if (!/^\S+@\S+\.\S+$/.test(account.email?.trim() || '')) {
        throw new BadRequestException('The partner owner must have a valid registered email before approval');
      }
      const previousDelivery = await this.mailService.findPartnerApprovalEmail(id, tx);
      const historicalReceipt = await tx.audit_events.findFirst({ where: {
        action: 'partner_approval.email_sent', entity_type: 'venues', entity_id: id,
      } });
      const password = !account.password_hash && !previousDelivery && !historicalReceipt ? this.generatePassword() : undefined;
      const now = new Date();
      await tx.users.update({ where: { id: account.id }, data: {
        ...(password ? { password_hash: await bcrypt.hash(password, 10) } : {}), status: 'ACTIVE', updated_at: now,
      } });
      await tx.partners.update({ where: { id: partner.id }, data: { status: 'ACTIVE', updated_at: now } });
      const deliveryId = await this.mailService.preparePartnerApprovalEmail({
        toEmail: account.email.trim(), partnerName: account.name || partner.partner_business_profiles?.owner_name || partner.legal_name,
        venueName, password, deliveryKey: `venue-approved:${id}`,
      }, tx, !!historicalReceipt);
      if (!deliveryId) throw new Error('Durable approval email preparation did not return a delivery record');
      await tx.venues.update({ where: { id }, data: {
        status: 'PUBLISHED', approved_at: now, approved_by: adminId, rejection_reason: null, review_status: VenueStatus.APPROVED,
      } });
      await tx.partner_venue_services.updateMany({ where: { venue_id: id, status: { in: ['DRAFT', 'PENDING'] } }, data: {
        status: 'APPROVED', approved_at: now, approved_by: adminId, rejection_reason: null, updated_at: now,
      } });
      await this.syncLegacyActivitySlotsInTransaction(tx, id);
      await syncLegacyActivityVisibility(tx, id);
      await tx.audit_events.create({ data: {
        id: randomUUID(), action: 'venue.approved', entity_type: 'venues', entity_id: id, actor_id: adminId,
        after_json: { deliveryId },
      } });
      return { changed: true, partnerId: partner.id, venueName, deliveryId };
    }, { isolationLevel: 'ReadCommitted', maxWait: 10000, timeout: 60000 });

    if (outcome.changed) {
      // Transport/notification failures must not turn a committed approval into an API failure.
      try { await this.mailService.deliverPreparedEmail(outcome.deliveryId); }
      catch { this.logger.warn('Approval committed; email delivery is pending recovery'); }
      try {
        await this.notificationsService.notify(outcome.partnerId, NotificationType.VENUE_APPROVED,
          'Venue approved', `${outcome.venueName} has been approved and is now live on ACTIV`, { venueId: id });
      } catch { this.logger.warn('Approval committed; in-app notification failed'); }
      try {
        await this.pushNotificationsService.sendToPartner(outcome.partnerId, 'Venue approved',
          `${outcome.venueName} has been approved and is now live on ACTIV`, { type: 'venue_approved', venueId: id });
      } catch { this.logger.warn('Approval committed; push notification failed'); }
    }
    return this.findOne(id);
  }

  private async handlePartnerRejection(
    venue: Venue,
    reason: string,
    deliveryKey?: string,
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
      venueId: venue.id, venueName: venue.name,
      deliveryKey: deliveryKey || `venue-rejected:${venue.id}:${reason}`,
      rejectionReason: reason,
    });
  }

  private generatePassword(): string {
    const chars = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
    const special = "@#$!";
    let password = "";
    for (let i = 0; i < 8; i++) {
      password += chars.charAt(randomInt(chars.length));
    }
    password += special.charAt(randomInt(special.length));
    password += randomInt(10, 100);
    return password;
  }

  async remove(
    id: string,
    currentUser: { id: string; role: string },
  ): Promise<{ permanentlyDeleted: boolean }> {
    let notice: { partnerId: string; venueName: string } | undefined;
    const result = await this.prisma.$transaction(async (tx) => {
      const [venue] = await tx.$queryRawUnsafe<Array<{
        id: string; name: string; partner_id: string; status: string; booking_accept: boolean;
      }>>('SELECT id, name, partner_id, status, booking_accept FROM venues WHERE id = $1::uuid FOR UPDATE', id);
      if (!venue) throw new NotFoundException(`Venue with id ${id} not found`);
      if (currentUser.role !== UserRole.ADMIN &&
          (currentUser.role !== UserRole.PARTNER || venue.partner_id !== currentUser.id)) {
        throw new ForbiddenException("You can only delete your own venues");
      }
      if (currentUser.role === UserRole.ADMIN) {
        await deleteVenue(tx, id);
        notice = { partnerId: venue.partner_id, venueName: venue.name };
        return { permanentlyDeleted: true };
      }
      await tx.venues.update({ where: { id }, data: { status: "ARCHIVED", booking_accept: false } });
      if (venue.status !== 'ARCHIVED') notice = { partnerId: venue.partner_id, venueName: venue.name };
      return { permanentlyDeleted: false };
    }, { maxWait: 10000, timeout: 60000, isolationLevel: 'Serializable' });
    if (notice) await this.partnerEmailService?.send(notice.partnerId, 'venue_deleted', { venueName: notice.venueName, reference: id });
    return result;
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
    await this.updateActivityManagement(serviceId, partnerId, {}, true);
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
    await this.adminNotificationsService.notify(
      AdminNotificationType.VENUE_REQUEST_SUBMITTED,
      'Venue change request submitted',
      'A partner submitted venue changes for review.',
      { partnerId, venueId, venueRequestId: request.id },
    );
    await this.partnerEmailService?.send(partnerId, 'venue_update_submitted', { reference: request.id, venueName: (await this.findOne(venueId)).name, deliveryKey: `venue-update-submitted:${request.id}` });
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
    await this.partnerEmailService?.send(venue.partnerId, 'venue_update_approved', { venueName: venue.name, reference: id });
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
    await this.partnerEmailService?.send(request.partner_id, 'venue_update_rejected', { reference: id, reason: dto.adminNotes, venueName: (await this.findOne(request.venue_id)).name, deliveryKey: `venue-update-rejected:${id}` });
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
    const coachingAvailable = answerFor(["Coaching Available", "Coaching"]);
    const recommendedFor = answerFor(["Recommended For"]);
    const facilityId = service.facility_id;
    const where = { slots: { facility_id: facilityId! } };
    const [count, revenue, bookings, reviews, occupancy] = facilityId
      ? await Promise.all([
          this.prisma.bookings.count({ where }),
          this.prisma.bookings.aggregate({
            where: { ...where, status: { in: ["CONFIRMED", "COMPLETED", "NO_SHOW"] } },
            _sum: { total_paise: true },
          }),
          this.prisma.bookings.findMany({
            where,
            orderBy: { starts_at: "desc" },
            take: 100,
            include: {
              users: { select: { name: true, phone_e164: true } },
              slots: true,
              booking_attempts: { select: { quantity: true } },
              booking_events: {
                where: { to_status: { in: ["CHECKED_IN", "NO_SHOW"] } },
                orderBy: { created_at: "desc" }, take: 1,
                select: { to_status: true },
              },
              payments: {
                where: { status: "CAPTURED" },
                orderBy: { created_at: "desc" },
                take: 1,
                select: { provider: true, provider_payment_id: true, provider_order_id: true, amount_paise: true },
              },
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
    const paymentModes = await Promise.all(bookings.map(b => paymentMethodLabel(b.payments?.[0])));
    const now = new Date();
    const displayDate = (value: Date) => new Intl.DateTimeFormat('en-IN', {
      timeZone: 'Asia/Kolkata', day: '2-digit', month: 'short', year: 'numeric',
    }).format(value);
    const displayTime = (value: Date) => new Intl.DateTimeFormat('en-IN', {
      timeZone: 'Asia/Kolkata', hour: '2-digit', minute: '2-digit', hour12: true,
    }).format(value);
    const walkInBookings = walkIns.map((reservation) => {
      const details = this.mapWalkInReservation(reservation);
      return {
        id: reservation.id,
        bookingReference: details.bookingReference,
        // Walk-in timestamps are legacy wall-clock values stored in UTC
        // columns; the explicit Asia/Kolkata formatter is the single API
        // presentation boundary for them.
        bookingDate: displayDate(reservation.starts_at),
        bookingTime: displayTime(reservation.starts_at),
        customerName: reservation.participant_name ?? "Walk-in Customer",
        activity: service.title,
        startsAt: new Date(reservation.starts_at.getTime() - INDIA_OFFSET_MS),
        endsAt: new Date(reservation.ends_at.getTime() - INDIA_OFFSET_MS),
        status: attendanceStatus({ status: reservation.status, startsAt: reservation.starts_at,
          endsAt: reservation.ends_at, walkIn: true,
          checkedIn: /^Checked-in: /m.test(reservation.notes ?? '') }, now),
        amount: fallbackWalkInAmount(reservation) / 100,
        participants: reservation.participant_count ?? 1,
        source: "WALK_IN",
        checkedIn: /^Checked-in: /m.test(reservation.notes ?? ''),
        phone: reservation.participant_phone_e164,
        email: details.participantEmail,
        bookedOn: reservation.created_at,
        paymentMode: details.paymentMethod?.trim().toUpperCase() || "Not available",
        paymentStatus: details.paymentStatus,
      };
    });
    return {
      id: service.id,
      activityReference: service.public_reference ?? null,
      venueId: service.venue_id,
      venueReference: service.venues.public_reference ?? null,
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
      bookingAccept: service.venues.booking_accept,
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
        ...bookings.map((b, index) => ({
        id: b.id,
        bookingReference: b.booking_reference,
        bookingDate: displayDate(b.starts_at),
        bookingTime: displayTime(b.starts_at),
        customerName: b.users.name ?? "Customer",
        phone: b.users.phone_e164,
        activity: service.title,
        startsAt: b.starts_at,
        endsAt: b.slots.ends_at,
        status: attendanceStatus({ status: b.status, startsAt: b.starts_at, endsAt: b.slots.ends_at,
          checkedIn: !!b.checked_in_at, attendance: b.booking_events?.[0]?.to_status }, now),
        amount: Number(b.total_paise) / 100,
        participants: b.booking_attempts?.quantity ?? 1,
        bookedOn: b.created_at,
        paymentMode: paymentModes[index],
        source: "ACTIV",
        checkedIn: !!b.checked_in_at || b.booking_events?.[0]?.to_status === 'CHECKED_IN',
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
    const managed = await this.findManagedActivity(serviceId, partnerId);
    if (dto.name !== undefined && !dto.name.trim())
      throw new BadRequestException("Activity name is required");
    if (dto.isActive === false && !dto.reason?.trim())
      throw new BadRequestException("Choose a reason to pause bookings");
    const result = await this.prisma.$transaction(async (tx) => {
      if (archive || dto.isActive !== undefined) {
        await tx.$queryRawUnsafe('SELECT id FROM venues WHERE id = $1::uuid FOR UPDATE', managed.venue_id);
      }
      if (dto.answers !== undefined) {
        await tx.$queryRaw`SELECT id FROM partner_venue_services WHERE id = ${serviceId}::uuid FOR UPDATE`;
      }
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
      if (dto.isActive !== undefined) {
        const venue = await tx.venues.findUniqueOrThrow({
          where: { id: managed.venue_id }, select: { booking_accept: true },
        });
        if (!venue.booking_accept) {
          // Convert the old venue-wide pause to activity pauses under the
          // venue lock. Resuming one service must never reopen its siblings.
          const siblings = await tx.partner_venue_services.findMany({
            where: { venue_id: managed.venue_id, status: 'APPROVED', is_active: true },
          });
          for (const sibling of siblings) {
            if (!sibling.facility_id) continue;
            const slots = await tx.slots.findMany({ where: {
              facility_id: sibling.facility_id, status: 'AVAILABLE', starts_at: { gt: new Date() },
            }, select: { id: true } });
            if (slots.length) {
              await tx.partner_service_paused_slots.createMany({
                data: slots.map(slot => ({ venue_service_id: sibling.id, slot_id: slot.id })),
                skipDuplicates: true,
              });
              await tx.slots.updateMany({ where: {
                id: { in: slots.map(slot => slot.id) }, status: 'AVAILABLE',
              }, data: { status: 'BLOCKED' } });
            }
          }
          await tx.partner_venue_services.updateMany({
            where: { venue_id: managed.venue_id, status: 'APPROVED', is_active: true },
            data: { is_active: false, pause_reason: 'Previously paused for the whole venue' },
          });
          await tx.venues.update({ where: { id: managed.venue_id }, data: { booking_accept: true } });
        }
      }
      // The management editor uses the onboarding question form. Persist all
      // category answers and legacy summary fields in this same transaction.
      if (dto.answers !== undefined) {
        const ids = dto.answers.map(answer => answer.questionId);
        if (new Set(ids).size !== ids.length) throw new BadRequestException('Duplicate activity question');
        const questions = ids.length ? await tx.partner_service_questions.findMany({ where: {
          id: { in: ids },
          AND: [
            { OR: [{ service_category_id: service.service_category_id }, { service_category_id: null }] },
            { OR: [{ venue_service_id: serviceId }, { venue_service_id: null }] },
          ],
        } }) : [];
        if (questions.length !== ids.length) throw new BadRequestException('Questions must belong to this activity category');
        const actor = ids.length ? await tx.partner_users.findFirst({ where: { partner_id: partnerId }, orderBy: { role: 'desc' } }) : null;
        for (const item of dto.answers) {
          const definition = questions.find(question => question.id === item.questionId)!;
          if (definition.is_required && (item.answer == null ||
              (typeof item.answer === 'string' && !item.answer.trim()) ||
              (Array.isArray(item.answer) && !item.answer.length))) {
            throw new BadRequestException(`Please answer: ${definition.question}`);
          }
          const where = { venue_id: service.venue_id, venue_service_id: serviceId, question_id: item.questionId };
          const existing = await tx.partner_venue_answers.findFirst({ where });
          const answer = item.answer as runtime.InputJsonValue;
          if (existing) {
            await tx.partner_venue_answers.update({ where: { id: existing.id }, data: {
              answer, answered_by_partner_user_id: actor?.id ?? null, updated_at: new Date(),
            } });
          } else {
            await tx.partner_venue_answers.create({ data: {
              id: randomUUID(), ...where, answer,
              answered_by_partner_user_id: actor?.id ?? null, updated_at: new Date(),
            } });
          }
        }
        const byLabel = new Map(questions.map(question => [
          this.normalizeQuestionLabel(question.question),
          dto.answers!.find(answer => answer.questionId === question.id)!.answer,
        ]));
        const labels = {
          description: ['Activity Description'],
          numberOfCourt: ['Total Courts', 'Total Turfs', 'Total Nets', 'Total Arenas', 'Total Tables', 'Total Fields', 'Number of Courts'],
          courtType: ['Court Type', 'Court Surface', 'Pitch Type', 'Pitch Surface', 'Turf Type', 'Field Type', 'Table Type', 'Lane Type', 'Range Type', 'Arena Type', 'Activity Type'],
          playingEnvironment: ['Playing Environment', 'Environment'],
          coachingAvailable: ['Coaching Available', 'Coaching'],
          recommendedFor: ['Recommended For'],
        };
        // Preserve older clients' flat payloads while keeping the management
        // summary consistent with the newly saved category answers.
        dto = { ...dto };
        for (const [field, candidates] of Object.entries(labels)) {
          const label = candidates.map(value => this.normalizeQuestionLabel(value)).find(value => byLabel.has(value));
          if (label !== undefined) {
            const value = byLabel.get(label);
            dto[field] = ['playingEnvironment', 'coachingAvailable', 'recommendedFor'].includes(field)
              ? this.answerAsList(value) : this.answerAsText(value);
          }
        }
        if ((dto.description?.length ?? 0) > 5000 ||
            (dto.numberOfCourt?.length ?? 0) > 50 || (dto.courtType?.length ?? 0) > 200) {
          throw new BadRequestException('Activity details exceed the allowed length');
        }
      }
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
      const updated = await tx.partner_venue_services.update({
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
      let autoDeactivated = false;
      if (archive) {
        const remaining = await tx.partner_venue_services.count({
          where: { venue_id: managed.venue_id, status: { not: 'ARCHIVED' } },
        });
        if (remaining === 0) {
          const changed = await tx.venues.updateMany({
            where: { id: managed.venue_id, booking_accept: true },
            data: { booking_accept: false },
          });
          autoDeactivated = changed.count > 0;
        }
      }
      if (archive || dto.isActive !== undefined) {
        await syncLegacyActivityVisibility(tx, managed.venue_id);
      }
      return { updated, autoDeactivated };
    });
    if (archive) {
      await this.adminNotificationsService.notify(
        AdminNotificationType.ACTIVITY_REMOVED,
        'Activity removed',
        `"${managed.title}" was removed from ${managed.venues.name}.`,
        { partnerId, venueId: managed.venue_id, serviceId },
      );
      if (result.autoDeactivated) {
        await this.adminNotificationsService.notify(
          AdminNotificationType.VENUE_AUTO_DEACTIVATED,
          'Venue bookings automatically disabled',
          `Bookings for ${managed.venues.name} were disabled because its last activity was removed.`,
          { partnerId, venueId: managed.venue_id },
        );
      }
    }
    return result.updated;
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
        where: { venue_id: service.venueId,
          OR: [{ venue_service_id: serviceId }, { venue_service_id: null }] },
        orderBy: { updated_at: 'asc' },
      }),
    ]);

    // Older venue onboarding stored category answers without a service id.
    // Restore those too, but an explicit activity answer always takes priority.
    const answerMap = new Map(answers.filter(answer => !answer.venue_service_id)
      .map(answer => [answer.question_id, answer.answer]));
    for (const answer of answers.filter(answer => answer.venue_service_id === serviceId)) {
      answerMap.set(answer.question_id, answer.answer);
    }

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
    const saved = await this.saveAnswers(service.venue_id, answers, partnerId, serviceId);
    try {
      const questionIds = answers.map((a) => a.questionId);
      const questions = await this.prisma.partner_service_questions.findMany({
        where: { id: { in: questionIds } },
      });
      for (const item of answers) {
        const q = questions.find((quest) => quest.id === item.questionId);
        const text = q?.question?.toLowerCase() ?? '';
        if (text.includes('activity description') || text.includes('description')) {
          if (typeof item.answer === 'string' && item.answer.trim()) {
            await this.prisma.partner_venue_services.update({
              where: { id: serviceId },
              data: { description: item.answer.trim(), updated_at: new Date() },
            });
          }
          break;
        }
      }
    } catch (_) {}
    return saved;
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

    await this.adminNotificationsService.notify(
      AdminNotificationType.ACTIVITY_SUBMITTED,
      'Activity submitted for review',
      `${saved.name} is ready for admin review.`,
      { partnerId, venueId: saved.venueId, serviceId: saved.id },
    );
    await this.notificationsService.notify(
      partnerId,
      NotificationType.ACTIVITY_UNDER_REVIEW,
      "Activity under review",
      `${saved.name} has been submitted and is being reviewed by ACTIV`,
      { serviceId: saved.id },
    );
    await this.partnerEmailService?.send(partnerId, 'activity_submitted', { activityName: saved.name, venueName: saved.venue?.name, reference: saved.id, deliveryKey: `activity-submitted:${saved.id}:${saved.submittedAt?.toISOString?.() || saved.updatedAt?.toISOString?.() || 'initial'}` });

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
    status: 'all' | 'pending' | 'approved' | 'rejected' = 'pending',
  ): Promise<[VenueService[], number]> {
    const reviewStatus = { pending: 'PENDING', approved: 'APPROVED', rejected: 'REJECTED' } as const;
    const where = status === 'all'
      ? { status: { in: ['PENDING', 'APPROVED', 'REJECTED'] as Array<'PENDING' | 'APPROVED' | 'REJECTED'> } }
      : { status: reviewStatus[status] };
    const [records, total] = await Promise.all([
      this.prisma.partner_venue_services.findMany({
        where,
        include: { venues: true },
        orderBy: [
          { submitted_at: { sort: "desc", nulls: "last" } },
          { created_at: "desc" },
          { id: "desc" },
        ],
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
    if (approved) await this.syncLegacyActivitySlots(record.venues.id);
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
    await this.partnerEmailService?.send(record.venues.partner_id, approved ? 'activity_approved' : 'activity_rejected', {
      activityName: saved.name, venueName: record.venues.name, reference: serviceId, reason: approved ? undefined : dto.reason, deliveryKey: `activity-review:${serviceId}:${saved.updatedAt?.toISOString?.() || dto.status}`,
    });
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
    if (!service.venues.booking_accept)
      throw new BadRequestException("Bookings are paused for this venue");
    if (service.status !== "APPROVED")
      throw new BadRequestException(
        "Activity must be approved to manage walk-in slots",
      );

    const slotDurationMinutes = service.min_duration_minutes || 60;
    const dayStart = new Date(`${date}T00:00:00.000Z`);
    const dayEnd = new Date(`${date}T23:59:59.999Z`);

    const facilityDayStart = this.istWallTimeToUtc(dayStart, 0);
    const facilityDayEnd = this.istWallTimeToUtc(dayStart, 24 * 60);

    // Get operational windows for the date's day of week
    const dayName = new Date(`${date}T00:00:00.000Z`)
      .toLocaleDateString("en-US", { weekday: "long", timeZone: "Asia/Kolkata" })
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

    // The facility's slots are the authoritative server-side schedule when
    // they exist. Do not synthesize a 24-hour grid or substitute another
    // activity/venue's facility.
    const facilitySlots = service.facility_id
      ? await this.prisma.slots.findMany({
          where: {
            facility_id: service.facility_id,
            starts_at: { gte: facilityDayStart, lt: facilityDayEnd },
          },
          orderBy: { starts_at: "asc" },
        })
      : [];
    // Facility slots can outlive a partner's edited availability window.
    // Never show those stale slots in walk-in booking; only slots fully inside
    // the exact window configured for this activity/day are valid.
    const exactFacilitySlots = facilitySlots.filter((slot) => {
      const start = this.istDateTimeToMinutes(slot.starts_at);
      const end = this.istDateTimeToMinutes(slot.ends_at);
      return end - start === slotDurationMinutes && operationalWindows.some((window) =>
        start >= window.open && end <= window.close &&
        (start - window.open) % slotDurationMinutes === 0,
      );
    });
    // Use persisted facility slots only when the complete set matches the
    // configured one-hour grid. Otherwise regenerate from each open time so
    // stale half-hour/misaligned slots cannot leak into walk-in booking.
    const useFacilitySlots = facilitySlots.length > 0 &&
      exactFacilitySlots.length === facilitySlots.length;

    // ACTIV bookings for this service+date
    const activBookings = service.facility_id
      ? await this.prisma.bookings.findMany({
          where: {
            status: { not: "CANCELLED" },
            starts_at: { lt: facilityDayEnd },
            slots: {
              facility_id: service.facility_id,
              ends_at: { gt: facilityDayStart },
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
        starts_at: { lt: facilityDayEnd },
        ends_at: { gt: facilityDayStart },
        notes: court ? { contains: `Court: ${court}` } : undefined,
      },
    });

    const slots: Array<{
      startTime: string;
      endTime: string;
      status: string;
      reservationId?: string;
    }> = [];

    if (useFacilitySlots) {
      for (const slot of exactFacilitySlots) {
        const startMin = this.istDateTimeToMinutes(slot.starts_at);
        const endMin = this.istDateTimeToMinutes(slot.ends_at);
        const hasActivBooking = activBookings.some((booking) =>
          startMin < this.istDateTimeToMinutes(booking.slots.ends_at) &&
          endMin > this.istDateTimeToMinutes(booking.slots.starts_at),
        );
        const matchedWalkIn = walkIns.find((reservation) =>
          startMin < this.istDateTimeToMinutes(reservation.ends_at) &&
          endMin > this.istDateTimeToMinutes(reservation.starts_at),
        );
        const status = slot.status === "BLOCKED"
          ? "blocked"
          : hasActivBooking
            ? "activ_booking"
            : matchedWalkIn
              ? "walk_in_reserved"
              : slot.booked_quantity >= slot.capacity
                ? "fully_booked"
                : "available";
        slots.push({
          startTime: this.minutesToTime(startMin),
          endTime: this.minutesToTime(endMin),
          status,
          ...(matchedWalkIn ? { reservationId: matchedWalkIn.id } : {}),
        });
      }
    } else {
      // No generated facility schedule exists: use only the configured
      // availability windows for this exact activity category.
      for (const window of operationalWindows) {
        for (let startMin = window.open; startMin + slotDurationMinutes <= window.close; startMin += slotDurationMinutes) {
          const endMin = startMin + slotDurationMinutes;
          const hasActivBooking = activBookings.some((b) => {
            const bStart = this.istDateTimeToMinutes(b.slots.starts_at);
            const bEnd = this.istDateTimeToMinutes(b.slots.ends_at);
            return startMin < bEnd && endMin > bStart;
          });
          const matchedWalkIn = walkIns.find((w) =>
            startMin < this.istDateTimeToMinutes(w.ends_at) &&
            endMin > this.istDateTimeToMinutes(w.starts_at),
          );
          slots.push({
            startTime: this.minutesToTime(startMin),
            endTime: this.minutesToTime(endMin),
            status: hasActivBooking
              ? "activ_booking"
              : matchedWalkIn
                ? "walk_in_reserved"
                : "available",
            ...(matchedWalkIn ? { reservationId: matchedWalkIn.id } : {}),
          });
        }
      }
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

  private istDateTimeToMinutes(value: Date): number {
    return this.dateTimeToMinutes(new Date(value.getTime() + 330 * 60_000));
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
    if (!service.venues.booking_accept)
      throw new BadRequestException("Bookings are paused for this venue");
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
        .toLocaleDateString("en-US", { weekday: "long", timeZone: "Asia/Kolkata" })
        .toLowerCase();
      const windows = await tx.partner_venue_availability.findMany({
        where: {
          venue_id: venueId,
          service_category_id: service.service_category_id,
          day: dayName,
        },
      });
      // Some legacy unit fixtures do not provide the normalized Prisma delegate.
      // Production Prisma transactions always do; retain the legacy validation
      // path for those fixtures until the writer is fully cut over.
      if (service.facility_id && tx.slots?.findMany) {
      const normalizedSlots = await tx.slots.findMany({
        where: {
          facility_id: service.facility_id,
          OR: requestedSlots.map(slot => ({ starts_at: slot.startsAt, ends_at: slot.endsAt })),
        },
        select: { id: true, facility_id: true, capacity: true, status: true, starts_at: true, ends_at: true },
      });
      if (normalizedSlots.length !== requestedSlots.length) {
        throw new ConflictException('One or more selected slots are not available in the normalized schedule');
      }
      await lockSlotsForCapacity(tx, normalizedSlots.map(slot => slot.id));
      for (const normalizedSlot of normalizedSlots) {
        const [slotBookings, slotAttempts, slotWalkIns] = await Promise.all([
          tx.bookings.findMany({ where: { slot_id: normalizedSlot.id }, select: { id: true, attempt_id: true, status: true, starts_at: true, slots: { select: { ends_at: true } } } }),
          tx.booking_attempts.findMany({ where: { slot_id: normalizedSlot.id, status: { in: ['HELD', 'PAYMENT_PROCESSING'] }, expires_at: { gt: new Date() } }, select: { status: true, quantity: true, expires_at: true, bookings: { select: { id: true } } } }),
          tx.partner_walk_in_reservations.findMany({
            where: {
              facility_id: normalizedSlot.facility_id,
              starts_at: { lt: normalizedSlot.ends_at },
              ends_at: { gt: normalizedSlot.starts_at },
            },
            select: { status: true, participant_count: true, starts_at: true, ends_at: true },
          }),
        ]);
        const occupancy = effectiveSlotOccupancy({
          bookings: slotBookings.map(row => ({ id: row.id, attemptId: row.attempt_id, status: row.status, quantity: 1, startsAt: row.starts_at, endsAt: row.slots.ends_at })),
          attempts: slotAttempts.map(row => ({ status: row.status, quantity: row.quantity, expiresAt: row.expires_at, bookingId: row.bookings?.id ?? null })),
          walkIns: slotWalkIns.map(row => ({ status: row.status, participantCount: row.participant_count, startsAt: row.starts_at, endsAt: row.ends_at })),
        });
        if (normalizedSlot.status !== 'AVAILABLE' || occupancy + 1 > normalizedSlot.capacity) {
          throw new ConflictException('One or more selected slots are unavailable');
        }
      }
      }
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
            starts_at: { lt: this.istWallTimeToUtc(dayStart, 24 * 60) },
            slots: {
              facility_id: service.facility_id,
              ends_at: { gt: this.istWallTimeToUtc(dayStart, 0) },
            },
          },
          include: { slots: true },
        });
        if (activBookings.some((booking) => requestedSlots.some((slot) =>
          this.istWallTimeToUtc(dayStart, this.timeToMinutes(slot.startTime)) < booking.slots.ends_at &&
          this.istWallTimeToUtc(dayStart, this.timeToMinutes(slot.endTime)) > booking.slots.starts_at))) {
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
      reservations: reservations.map((reservation) =>
        this.mapWalkInReservation(reservation),
      ),
    };
  }

  private walkInDateTime(date: string, time: string): Date {
    const day = new Date(`${date}T00:00:00.000Z`);
    return this.istWallTimeToUtc(day, this.timeToMinutes(time));
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
    if (reservation.status === "CANCELLED") return this.mapWalkInReservation(reservation);
    if (reservation.status !== "RESERVED") throw new BadRequestException("Reservation is already released");

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
    const istStart = new Date(reservation.starts_at.getTime() + 330 * 60_000);
    const dateCode = istStart.toISOString().slice(0, 10).replace(/-/g, "");
    const courtMatch = notes.match(/^Court: (.+)$/m);
    const emailMatch = notes.match(/^Email: (.+)$/m);
    const paymentMethodMatch = notes.match(/^Payment method: (.+)$/m);
    const paymentStatusMatch = notes.match(/^Payment status: (.+)$/m);
    const idempotencyKeyMatch = notes.match(/^Idempotency-Key: (.+)$/m);
    return {
      id: reservation.id,
      bookingReference: `WI-${dateCode}-${String(reservation.id).slice(0, 8).toUpperCase()}`,
      venueServiceId: reservation.venue_service_id,
      venueId: reservation.venue_id,
      partnerId: reservation.partner_id,
      court: courtMatch?.[1] ?? null,
      date: istStart.toISOString().slice(0, 10),
      slots: [
        {
          startTime: this.minutesToTime(this.istDateTimeToMinutes(reservation.starts_at)),
          endTime: this.minutesToTime(this.istDateTimeToMinutes(reservation.ends_at)),
        },
      ],
      participantName: reservation.participant_name,
      participantPhone: reservation.participant_phone_e164,
      participantEmail: emailMatch?.[1] ?? null,
      idempotencyKey: idempotencyKeyMatch?.[1] ?? null,
      paymentMethod: paymentMethodMatch?.[1] ?? null,
      paymentStatus: paymentStatusMatch?.[1] ?? null,
      amountPaise: reservation.amount_paise?.toString() ?? null,
      status: reservation.status.toLowerCase(),
      createdAt: reservation.created_at,
    };
  }
}
