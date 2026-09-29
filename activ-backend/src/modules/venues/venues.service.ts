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
  ) {}

  async create(createVenueDto: CreateVenueDto, partnerId: string): Promise<Venue> {
    const { services, answers, categoryIds, ...venueData } = createVenueDto;

    if (!categoryIds || categoryIds.length === 0) {
      throw new BadRequestException('At least one categoryId is required');
    }

    const categories = await this.categoryRepository.findBy({ id: In(categoryIds) });

    if (categories.length === 0) {
      throw new BadRequestException('No valid categories found for the provided categoryIds');
    }

    const venue = this.venueRepository.create({
      ...venueData,
      partnerId,
      status: VenueStatus.DRAFT,
    });

    venue.categories = categories;

    const savedVenue = await this.venueRepository.save(venue);

    if (services && services.length > 0) {
      const venueServices = services.map((s) =>
        this.venueServiceRepository.create({ ...s, venueId: savedVenue.id }),
      );
      await this.venueServiceRepository.save(venueServices);
    }

    if (answers && answers.length > 0) {
      const venueAnswers = answers.map((a) =>
        this.venueAnswerRepository.create({ ...a, venueId: savedVenue.id }),
      );
      await this.venueAnswerRepository.save(venueAnswers);
    }

    return this.findOne(savedVenue.id);
  }

  // Partner submits venue for admin review (draft → pending)
  async submitForReview(venueId: string, partnerId: string): Promise<Venue> {
    const venue = await this.findOne(venueId);

    if (venue.partnerId !== partnerId) {
      throw new ForbiddenException('You can only submit your own venues');
    }

    if (venue.status !== VenueStatus.DRAFT) {
      throw new BadRequestException('Only draft venues can be submitted for review');
    }

    // Delete any other orphaned drafts this partner has (except the one being submitted)
    await this.venueRepository.delete({
      partnerId,
      status: VenueStatus.DRAFT,
      id: Not(venueId),
    });

    venue.status = VenueStatus.PENDING;
    return this.venueRepository.save(venue);
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
  ): Promise<Partner> {
    const venue = await this.findOne(venueId);

    if (!isAdmin && venue.partnerId !== callerId) {
      throw new ForbiddenException('Access denied');
    }

    const partnerId = isAdmin ? venue.partnerId : callerId;
    const partner = await this.partnerRepository.findOne({ where: { id: partnerId } });

    if (!partner) {
      throw new NotFoundException('Partner profile not found');
    }

    let aadhaarTouched = false;
    let panTouched     = false;
    let gstTouched     = false;

    if (legalData.aadhaarName !== undefined)    { partner.aadhaarName    = legalData.aadhaarName;    aadhaarTouched = true; }
    if (legalData.aadhaarNumber !== undefined)  { partner.aadhaarNumber  = legalData.aadhaarNumber;  aadhaarTouched = true; }
    if (legalData.aadhaarCardUrl !== undefined) { partner.aadhaarCardUrl = legalData.aadhaarCardUrl; aadhaarTouched = true; }
    if (legalData.panNumber !== undefined)      { partner.panNumber      = legalData.panNumber;       panTouched = true; }
    if (legalData.panCardUrl !== undefined)     { partner.panCardUrl     = legalData.panCardUrl;      panTouched = true; }
    if (legalData.gstNumber !== undefined)      { partner.gstNumber      = legalData.gstNumber;       gstTouched = true; }
    if (legalData.gstName !== undefined)        { partner.gstName        = legalData.gstName;         gstTouched = true; }
    if (legalData.gstinDocUrl !== undefined)    { partner.gstinDocUrl    = legalData.gstinDocUrl;     gstTouched = true; }

    await this.partnerRepository.save(partner);

    const setClauses: string[] = [];
    if (aadhaarTouched) setClauses.push(`aadhaar_verified_at = NOW()`);
    if (panTouched)     setClauses.push(`pan_verified_at = NOW()`);
    if (gstTouched)     setClauses.push(`gst_verified_at = NOW()`);

    if (setClauses.length > 0) {
      await this.dataSource.query(
        `UPDATE partners SET ${setClauses.join(', ')} WHERE id = $1`,
        [partnerId],
      );
    }

    return this.partnerRepository.findOne({ where: { id: partnerId } });
  }

  // Partner accepts terms and provides electronic signature
  async acceptTerms(
    venueId: string,
    partnerId: string,
    electronicSignature: string,
  ): Promise<Venue> {
    const venue = await this.findOne(venueId);

    if (venue.partnerId !== partnerId) {
      throw new ForbiddenException('You can only sign your own venue agreements');
    }

    venue.termsAccepted = true;
    venue.termsAcceptedAt = new Date();
    venue.electronicSignature = electronicSignature;

    return this.venueRepository.save(venue);
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
    const qb = this.venueRepository
      .createQueryBuilder('venue')
      .leftJoinAndSelect('venue.categories', 'category')
      .leftJoinAndSelect('venue.partner', 'partner')
      .leftJoinAndSelect('venue.images', 'images');

    if (status) qb.andWhere('venue.status = :status', { status });
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
    const venues = await this.venueRepository.find({
      where: { partnerId, status: VenueStatus.APPROVED },
      relations: [
        'categories',
        'images',
        'services',
        'answers',
        'answers.question',
        'answers.question.category',
      ],
      order: { createdAt: 'DESC' },
    });

    // Attach answers to the service whose name matches the answer's category name
    return venues.map((venue) => ({
      ...venue,
      services: (venue.services || []).map((service) => ({
        ...service,
        answers: (venue.answers || []).filter(
          (a) =>
            a.question?.category?.name?.toLowerCase() ===
            service.name?.toLowerCase(),
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
    const venue = await this.venueRepository.findOne({
      where: { id },
      relations: ['categories', 'partner', 'images', 'services', 'answers', 'answers.question'],
    });

    if (!venue) {
      throw new NotFoundException(`Venue with id ${id} not found`);
    }

    return venue;
  }

  async setAvailability(
    venueId: string,
    venueTiming: Record<string, Record<string, Array<{ open: string; close: string; capacity?: number; price?: number; discountedPrice?: number }>>>,
    partnerId: string,
  ): Promise<Venue> {
    const venue = await this.findOne(venueId);

    if (venue.partnerId !== partnerId) {
      throw new ForbiddenException('You can only update your own venue');
    }

    if (!venueTiming) throw new BadRequestException('venue_timing is required');

    // Merge into the existing per-category map — a venue can have several
    // independently-managed activities (categories), each calling this endpoint
    // for just its own categoryId. Overwriting the whole object would wipe out
    // every other activity's slots.
    const availability: Record<string, Array<{ day: string; slots: Array<{ openTime: string; closeTime: string; capacity: number; price: number; discountedPrice: number }> }>> = {
      ...(venue.availability || {}),
    };

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

    venue.availability = availability;
    return this.venueRepository.save(venue);
  }

  // Save / upsert answers for a venue's category questions
  async saveAnswers(
    venueId: string,
    answers: Array<{ questionId: string; answer: any }>,
    partnerId: string,
    venueServiceId?: string,
  ): Promise<VenueAnswer[]> {
    const venue = await this.findOne(venueId);

    if (venue.partnerId !== partnerId) {
      throw new ForbiddenException('You can only save answers for your own venues');
    }

    const saved: VenueAnswer[] = [];

    for (const { questionId, answer } of answers) {
      const existing = await this.venueAnswerRepository.findOne({
        where: { venueId, questionId, ...(venueServiceId ? { venueServiceId } : { venueServiceId: IsNull() }) },
      });

      if (existing) {
        existing.answer = answer;
        saved.push(await this.venueAnswerRepository.save(existing));
      } else {
        const newAnswer = this.venueAnswerRepository.create({
          venueId,
          questionId,
          answer,
          ...(venueServiceId ? { venueServiceId } : {}),
        });
        saved.push(await this.venueAnswerRepository.save(newAnswer));
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
    const venue = await this.findOne(id);

    if (
      approvalDto.status === VenueStatus.REJECTED ||
      approvalDto.status === VenueStatus.SUSPENDED
    ) {
      if (!approvalDto.reason) {
        throw new BadRequestException('Reason is required when rejecting or suspending a venue');
      }
      venue.rejectionReason = approvalDto.reason;
    }

    if (approvalDto.status === VenueStatus.APPROVED) {
      venue.approvedAt = new Date();
      venue.approvedBy = adminId;
      venue.rejectionReason = null;
      // Auto-generate password and send email to partner
      await this.handlePartnerApproval(venue);
    }

    if (approvalDto.status === VenueStatus.REJECTED) {
      await this.handlePartnerRejection(venue, approvalDto.reason);
    }

    venue.status = approvalDto.status;
    const saved = await this.venueRepository.save(venue);

    // Auto-approve draft services AFTER venue save to prevent cascade overwrite.
    // { cascade: true } on venue.services would re-save in-memory draft status
    // if the update ran before venueRepository.save().
    if (approvalDto.status === VenueStatus.APPROVED) {
      await this.venueServiceRepository
        .createQueryBuilder()
        .update()
        .set({ status: VenueServiceStatus.APPROVED, approvedAt: new Date(), approvedBy: adminId })
        .where('venue_id = :venueId AND status = :status', { venueId: venue.id, status: 'draft' })
        .execute();
    }

    return saved;
  }

  private async handlePartnerApproval(venue: Venue): Promise<void> {
    const partner = await this.partnerRepository.findOne({ where: { id: venue.partnerId } });

    if (!partner) return;

    // Skip if email is not yet set (phone-only OTP registration not yet completed)
    if (!partner.email) return;

    // Generate a strong readable password
    const password = this.generatePassword();

    // Hash and save — also activate the partner account
    const hashedPassword = await bcrypt.hash(password, 10);
    await this.partnerRepository.update(partner.id, { password: hashedPassword, isActive: true });

    // Send email with credentials
    await this.mailService.sendPartnerApprovalEmail({
      toEmail: partner.email,
      partnerName: partner.fullName || partner.businessName,
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
    const partner = await this.partnerRepository.findOne({ where: { id: venue.partnerId } });

    if (!partner || !partner.email) return;

    const fullName = partner.fullName || partner.businessName || '';
    const firstName = fullName.split(' ')[0];

    await this.mailService.sendPartnerRejectionEmail({
      toEmail: partner.email,
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
  ): Promise<VenueService> {
    const venue = await this.findOne(venueId);

    if (userRole !== UserRole.ADMIN && venue.partnerId !== userId) {
      throw new ForbiddenException('You can only update images for your own venue services');
    }

    // Find existing service by name, or create it
    let service = await this.venueServiceRepository.findOne({
      where: { venueId, name: serviceName },
    });

    if (!service) {
      service = this.venueServiceRepository.create({
        venueId,
        name: serviceName,
        pricePerHour: 0,
        imageUrls: [],
        ...(categoryId ? { categoryId } : {}),
        ...(amenities && amenities.length > 0 ? { amenities } : {}),
      });
    } else {
      if (categoryId && !service.categoryId) service.categoryId = categoryId;
      if (amenities && amenities.length > 0) service.amenities = amenities;
    }

    service.imageUrls = [...(service.imageUrls || []), ...newUrls];

    // Auto-set cover photo from first image if not already set
    if (!service.imageUrl && newUrls.length > 0) {
      service.imageUrl = newUrls[0];
    }

    return this.venueServiceRepository.save(service);
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
    const total = await this.venueRepository.count();
    const draft = await this.venueRepository.count({ where: { status: VenueStatus.DRAFT } });
    const pending = await this.venueRepository.count({ where: { status: VenueStatus.PENDING } });
    const approved = await this.venueRepository.count({ where: { status: VenueStatus.APPROVED } });
    const rejected = await this.venueRepository.count({ where: { status: VenueStatus.REJECTED } });

    return { total, draft, pending, approved, rejected };
  }

  // ─── Venue Update Requests ────────────────────────────────────────────────

  async submitVenueUpdateRequest(
    venueId: string,
    partnerId: string,
    dto: SubmitVenueUpdateDto,
  ): Promise<VenueUpdateRequest> {
    const venue = await this.findOne(venueId);

    if (venue.partnerId !== partnerId) {
      throw new ForbiddenException('You can only submit update requests for your own venues');
    }

    const existing = await this.venueUpdateRequestRepo.findOne({
      where: { venueId, status: VenueUpdateRequestStatus.PENDING },
    });

    if (existing) {
      throw new ConflictException(
        'A pending update request already exists for this venue. Please wait for admin review.',
      );
    }

    const request = this.venueUpdateRequestRepo.create({ venueId, partnerId, ...dto });
    return this.venueUpdateRequestRepo.save(request);
  }

  async findMyVenueUpdateRequests(partnerId: string): Promise<VenueUpdateRequest[]> {
    return this.venueUpdateRequestRepo.find({
      where: { partnerId },
      order: { createdAt: 'DESC' },
    });
  }

  async findAllVenueUpdateRequests(
    pagination: PaginationDto,
    status?: VenueUpdateRequestStatus,
  ): Promise<[VenueUpdateRequest[], number]> {
    const qb = this.venueUpdateRequestRepo
      .createQueryBuilder('req')
      .orderBy('req.createdAt', 'DESC');

    if (status) {
      qb.andWhere('req.status = :status', { status });
    }

    if (pagination.search) {
      qb.andWhere('req.name ILIKE :search', { search: `%${pagination.search}%` });
    }

    qb.skip(pagination.skip).take(pagination.limit);
    return qb.getManyAndCount();
  }

  async findOneVenueUpdateRequest(id: string): Promise<VenueUpdateRequest> {
    const request = await this.venueUpdateRequestRepo.findOne({ where: { id } });
    if (!request) throw new NotFoundException('Venue update request not found');
    return request;
  }

  async approveVenueUpdateRequest(id: string): Promise<Venue> {
    const request = await this.findOneVenueUpdateRequest(id);

    if (request.status !== VenueUpdateRequestStatus.PENDING) {
      throw new BadRequestException('Only pending requests can be approved');
    }

    const venue = await this.findOne(request.venueId);

    // Apply only the fields that were submitted (undefined means "not requested")
    if (request.name !== null && request.name !== undefined)        venue.name        = request.name;
    if (request.description !== null && request.description !== undefined) venue.description = request.description;
    if (request.address !== null && request.address !== undefined)  venue.address     = request.address;
    if (request.city !== null && request.city !== undefined)        venue.city        = request.city;
    if (request.state !== null && request.state !== undefined)      venue.state       = request.state;
    if (request.zipCode !== null && request.zipCode !== undefined)  venue.zipCode     = request.zipCode;
    if (request.flatBuilding !== null && request.flatBuilding !== undefined) venue.flatBuilding = request.flatBuilding;
    if (request.latitude !== null && request.latitude !== undefined)   venue.latitude    = request.latitude;
    if (request.longitude !== null && request.longitude !== undefined) venue.longitude   = request.longitude;
    if (request.locationUrl !== null && request.locationUrl !== undefined) venue.locationUrl = request.locationUrl;
    if (request.venuePhone !== null && request.venuePhone !== undefined)   venue.venuePhone  = request.venuePhone;

    await this.venueRepository.save(venue);
    await this.venueUpdateRequestRepo.remove(request);

    return venue;
  }

  async rejectVenueUpdateRequest(
    id: string,
    dto: ReviewVenueUpdateDto,
  ): Promise<VenueUpdateRequest> {
    const request = await this.findOneVenueUpdateRequest(id);

    if (request.status !== VenueUpdateRequestStatus.PENDING) {
      throw new BadRequestException('Only pending requests can be rejected');
    }

    request.status     = VenueUpdateRequestStatus.REJECTED;
    request.adminNotes = dto.adminNotes ?? null;
    return this.venueUpdateRequestRepo.save(request);
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
