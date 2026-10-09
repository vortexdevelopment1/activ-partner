import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  Query,
  UseGuards,
  ParseUUIDPipe,
  HttpCode,
  HttpStatus,
  UploadedFiles,
  UseInterceptors,
  BadRequestException,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery, ApiConsumes, ApiBody } from '@nestjs/swagger';
import { FilesInterceptor, FileFieldsInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import * as fs from 'fs';
import { VenuesService } from './venues.service';
import { CreateVenueDto } from './dto/create-venue.dto';
import { ManageActivityDto } from './dto/manage-activity.dto';
import { AdminCreateVenueDto } from './dto/admin-create-venue.dto';
import { UpdateVenueDto } from './dto/update-venue.dto';
import { VenueApprovalDto } from './dto/venue-approval.dto';
import { AddVenueServiceDto } from './dto/add-venue-service.dto';
import { SubmitVenueUpdateDto } from './dto/submit-venue-update.dto';
import { ReviewVenueUpdateDto } from './dto/review-venue-update.dto';
import { CreateVenueActivityDto } from './dto/create-venue-activity.dto';
import { SetActivityAmenitiesDto } from './dto/set-activity-amenities.dto';
import { ActivityApprovalDto } from './dto/activity-approval.dto';
import { CreateWalkInReservationDto } from './dto/create-walk-in-reservation.dto';
import { VenueUpdateRequestStatus } from './entities/venue-update-request.entity';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { VenueStatus } from '../../common/enums/venue-status.enum';
import { PaginationDto } from '../../common/dto/pagination.dto';

@ApiTags('Venues')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('venues')
export class VenuesController {
  constructor(private readonly venuesService: VenuesService) {}

  // ============ Partner Endpoints ============

  @Post()
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Step 1 — Create a new venue (Partner only)' })
  async create(@Body() createVenueDto: CreateVenueDto, @CurrentUser() user: any) {
    const data = await this.venuesService.create(createVenueDto, user.id);
    return { message: 'Venue draft created successfully', data };
  }

  @Patch(':id/legal')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER, UserRole.ADMIN)
  @ApiOperation({ summary: 'Step 5 — Submit legal information with document uploads (Partner or Admin)' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileFieldsInterceptor(
    [
      { name: 'panCard', maxCount: 1 },
      { name: 'aadhaarCard', maxCount: 1 },
      { name: 'gstinDoc', maxCount: 1 },
    ],
    {
      storage: diskStorage({
        destination: (_req, _file, cb) => {
          const path = './uploads/legal';
          if (!fs.existsSync(path)) fs.mkdirSync(path, { recursive: true });
          cb(null, path);
        },
        filename: (_req, file, cb) => {
          const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
          cb(null, `legal-${unique}${extname(file.originalname)}`);
        },
      }),
    },
  ))
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        aadhaarName:   { type: 'string', example: 'Virat Kohli' },
        aadhaarNumber: { type: 'string', example: '1234-5678-9101' },
        panNumber:     { type: 'string', example: 'ABCDE1234F' },
        gstNumber:     { type: 'string', example: 'BQRTA557T' },
        panCard:       { type: 'string', format: 'binary' },
        aadhaarCard:   { type: 'string', format: 'binary' },
        gstinDoc:      { type: 'string', format: 'binary' },
      },
    },
  })
  async saveLegalInfo(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: any,
    @Body() body: { aadhaarName?: string; aadhaarNumber?: string; panNumber?: string; gstNumber?: string; gstName?: string },
    @UploadedFiles() files: { panCard?: Express.Multer.File[]; aadhaarCard?: Express.Multer.File[]; gstinDoc?: Express.Multer.File[] },
  ) {
    const baseUrl = process.env.APP_URL || '';
    const legalData: any = {};
    if (body.aadhaarName !== undefined)   legalData.aadhaarName   = body.aadhaarName;
    if (body.aadhaarNumber !== undefined) legalData.aadhaarNumber = body.aadhaarNumber;
    if (body.panNumber !== undefined)     legalData.panNumber     = body.panNumber;
    if (body.gstNumber !== undefined)     legalData.gstNumber     = body.gstNumber;
    if (body.gstName !== undefined)       legalData.gstName       = body.gstName;

    if (files?.panCard?.[0])    legalData.panCardUrl    = `${baseUrl}/uploads/legal/${files.panCard[0].filename}`;
    if (files?.aadhaarCard?.[0]) legalData.aadhaarCardUrl = `${baseUrl}/uploads/legal/${files.aadhaarCard[0].filename}`;
    if (files?.gstinDoc?.[0])   legalData.gstinDocUrl   = `${baseUrl}/uploads/legal/${files.gstinDoc[0].filename}`;

    const isAdmin = user.role === UserRole.ADMIN;
    const data = await this.venuesService.saveLegalInfo(id, user.id, legalData, isAdmin);
    return { message: 'Legal information saved successfully', data };
  }

  @Patch(':id/terms')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Step 7 — Accept terms and provide electronic signature (Partner only)' })
  @ApiBody({
    schema: {
      type: 'object',
      required: ['electronicSignature'],
      properties: {
        electronicSignature: { type: 'string', example: 'Full Name' },
        termsAccepted: { type: 'boolean', example: true },
      },
    },
  })
  async acceptTerms(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: any,
    @Body() body: { electronicSignature: string; termsAccepted?: boolean },
  ) {
    const data = await this.venuesService.acceptTerms(id, user.id, body.electronicSignature);
    return { message: 'Terms accepted successfully', data };
  }

  @Get(':id/partner-agreement/download')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER, UserRole.ADMIN)
  @ApiOperation({
    summary: 'Download the official Partner Agreement PDF with the Agreement Acceptance page populated for this venue (Partner/Admin)',
  })
  async downloadPartnerAgreement(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.generatePartnerAgreementPdf(id, user);
    return { message: 'Partner agreement generated successfully', data };
  }

  @Patch(':id/availability')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Set venue operating days and timings per category (Partner only)',
    description: 'Save per-category day-wise availability. Each category can have different operating hours per day.',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        venue_timing: {
          type: 'object',
          example: {
            'cat-uuid-1': {
              Monday:    [{ open: '09:00 AM', close: '07:00 PM', capacity: 4, price: 500, discountedPrice: 400 }],
              Tuesday:   [{ open: '-',        close: '-' }],
              Wednesday: [{ open: '09:00 AM', close: '05:00 PM', capacity: 4, price: 500, discountedPrice: 450 }],
              Thursday:  [{ open: '09:00 AM', close: '12:00 PM', capacity: 4, price: 500, discountedPrice: 0 }],
              Friday:    [{ open: '-',        close: '-' }],
              Saturday:  [{ open: '09:00 AM', close: '03:00 PM', capacity: 4, price: 500, discountedPrice: 0 }],
              Sunday:    [{ open: '-',        close: '-' }],
            },
          },
        },
      },
    },
  })
  async setAvailability(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: any,
    @Body() body: { venue_timing: Record<string, Record<string, Array<{ open: string; close: string; capacity?: number; price?: number; discountedPrice?: number }>>> },
  ) {
    const data = await this.venuesService.setAvailability(id, body.venue_timing, user.id);
    return { message: 'Venue availability saved successfully', data };
  }

  @Post(':id/answers')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Save category question answers for a venue (Partner only)',
    description: 'Upserts answers — if an answer for the same questionId already exists it is updated, otherwise a new one is created.',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        venueServiceId: { type: 'string', format: 'uuid', description: 'Optional — scope answers to a specific activity/service' },
        answers: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              questionId: { type: 'string', format: 'uuid' },
              answer: { description: 'Any value: string, number, boolean, or array for multi-select' },
            },
          },
          example: [
            { questionId: 'uuid-1', answer: 'Yes' },
            { questionId: 'uuid-2', answer: ['Football', 'Cricket'] },
          ],
        },
      },
    },
  })
  async saveAnswers(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: any,
    @Body() body: { venueServiceId?: string; answers: Array<{ questionId: string; answer: any }> },
  ) {
    const data = await this.venuesService.saveAnswers(id, body.answers, user.id, body.venueServiceId);
    return { message: 'Answers saved successfully', data };
  }

  @Post(':id/submit')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Final Step — Submit venue for admin review (draft → pending)' })
  async submitForReview(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.submitForReview(id, user.id);
    return { message: 'Venue submitted for review successfully', data };
  }

  @Get('my-venues')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: "Get partner's own venues" })
  async getMyVenues(@Query() pagination: PaginationDto, @CurrentUser() user: any) {
    const [venues, total] = await this.venuesService.findByPartner(user.id, pagination);
    return {
      message: 'Venues fetched successfully',
      data: {
        items: venues,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Patch(':id/mark-welcome-seen')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Mark welcome screen as seen for a venue (Partner only)' })
  async markWelcomeSeen(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.markWelcomeSeen(id, user.id);
    return { message: 'Welcome screen marked as seen', data };
  }

  @Patch(':id/pause-bookings')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({
    summary: 'Pause or resume bookings for a venue (Partner only)',
    description: 'Set `bookingAccept: false` to pause new bookings, `true` to resume.',
  })
  @ApiBody({
    schema: {
      type: 'object',
      required: ['bookingAccept'],
      properties: { bookingAccept: { type: 'boolean', example: false } },
    },
  })
  async pauseBookings(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: any,
    @Body('bookingAccept') bookingAccept: boolean,
  ) {
    const accept = bookingAccept === true || (bookingAccept as any) === 'true';
    const data = await this.venuesService.pauseBookings(id, user.id, accept);
    const message = accept ? 'Bookings resumed successfully' : 'Bookings paused successfully';
    return { message, data };
  }

  @Get('my-approved-venues')
  @ApiBearerAuth()
  @ApiOperation({ summary: "Get partner's approved venues ordered by newest first (Partner or Team Member JWT)" })
  async getMyApprovedVenues(@CurrentUser() user: any) {
    // Team members carry partnerId in their token; partners use their own id
    const partnerId = user.role === 'team_member' ? user.partnerId : user.id;
    const data = await this.venuesService.findApprovedByPartner(partnerId);
    return { message: 'Approved venues fetched successfully', data };
  }

  @Patch(':id/services')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Add a service to a venue (Partner only)' })
  async addService(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() serviceDto: AddVenueServiceDto,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.addService(id, serviceDto, user.id);
    return { message: 'Service added successfully', data };
  }

  @Patch('services/:serviceId')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Update a venue service (Partner only)' })
  async updateService(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @Body() serviceDto: AddVenueServiceDto,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.updateService(serviceId, serviceDto, user.id);
    return { message: 'Service updated successfully', data };
  }

  @Post(':venueId/services/images')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER, UserRole.ADMIN)
  @ApiOperation({
    summary: 'Upload images for an activity/service (Partner only)',
    description: 'Creates the service if it does not exist yet, then attaches uploaded images. Pass `serviceName` (e.g. "Badminton") as a form field along with image files.',
  })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['serviceName'],
      properties: {
        serviceName: { type: 'string', example: 'Badminton' },
        categoryId: { type: 'string', format: 'uuid', description: 'Category UUID — sets category_id on the service' },
        amenities: { type: 'string', description: 'JSON string array e.g. ["Free Parking","WiFi"]' },
        images: { type: 'array', items: { type: 'string', format: 'binary' } },
      },
    },
  })
  @UseInterceptors(FilesInterceptor('images', 12, {
    limits: { fileSize: 5 * 1024 * 1024 },
    storage: diskStorage({
      destination: (_req, _file, cb) => {
        const path = './uploads/services';
        if (!fs.existsSync(path)) fs.mkdirSync(path, { recursive: true });
        cb(null, path);
      },
      filename: (_req, file, cb) => {
        const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
        cb(null, `service-${unique}${extname(file.originalname)}`);
      },
    }),
  }))
  async uploadServiceImages(
    @Param('venueId', ParseUUIDPipe) venueId: string,
    @CurrentUser() user: any,
    @UploadedFiles() files: Express.Multer.File[],
    @Body() body: { serviceName: string; categoryId?: string; amenities?: string },
  ) {
    const baseUrl = process.env.APP_URL || '';
    const urls = (files || []).map((f) => `${baseUrl}/uploads/services/${f.filename}`);

    let amenities: string[] | undefined;
    if (body.amenities) {
      try {
        const parsed = JSON.parse(body.amenities);
        amenities = Array.isArray(parsed) ? parsed.filter((a) => typeof a === 'string') : undefined;
      } catch {
        amenities = undefined;
      }
    }

    const data = await this.venuesService.uploadServiceImages(venueId, body.serviceName, urls, user.id, user.role, body.categoryId, amenities);
    return { message: 'Service images uploaded successfully', data };
  }

  @Patch('services/:serviceId/cover')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Set cover photo for an activity/service (Partner only)' })
  async setServiceCover(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
    @Body() body: { imageUrl: string },
  ) {
    const data = await this.venuesService.setServiceCover(serviceId, body.imageUrl, user.id);
    return { message: 'Cover photo set successfully', data };
  }

  @Delete('services/:serviceId/images')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete an image from an activity/service (Partner only)' })
  async deleteServiceImage(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
    @Body() body: { imageUrl: string },
  ) {
    const data = await this.venuesService.deleteServiceImage(serviceId, body.imageUrl, user.id);
    return { message: 'Service image deleted successfully', data };
  }

  @Delete('services/:serviceId')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Remove a service from a venue (Partner only)' })
  async removeService(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
  ) {
    await this.venuesService.removeService(serviceId, user.id);
    return { message: 'Service removed successfully', data: null };
  }

  @Delete('images/:imageId')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Remove a venue image (Partner only)' })
  async removeImage(
    @Param('imageId', ParseUUIDPipe) imageId: string,
    @CurrentUser() user: any,
  ) {
    await this.venuesService.removeImage(imageId, user.id);
    return { message: 'Image removed successfully', data: null };
  }

  @Patch('images/:imageId/set-primary')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Set an image as primary (Partner only)' })
  async setPrimaryImage(
    @Param('imageId', ParseUUIDPipe) imageId: string,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.setPrimaryImage(imageId, user.id);
    return { message: 'Primary image set successfully', data };
  }

  // ============ Venue Activities (Partner "Add New Activity" wizard) ============

  @Post(':venueId/activities')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({
    summary: 'Step 1 — Select activity: create or resume a draft activity for a category',
    description: 'Picking a category that already has a draft/pending/approved activity resumes it instead of duplicating. Picking one that was rejected restarts it as a fresh draft.',
  })
  async createActivity(
    @Param('venueId', ParseUUIDPipe) venueId: string,
    @Body() dto: CreateVenueActivityDto,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.createActivity(venueId, user.id, dto);
    return { message: 'Activity created successfully', data };
  }

  @Post(':venueId/activities/full')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({
    summary: 'Add New Activity — single combined submission (mobile wizard)',
    description:
      'Accepts everything the wizard collects in one multipart call: category, images, answers, amenities, ' +
      'and day-wise timing. action=draft leaves it editable; action=submit validates minimums (4+ images, ' +
      '1+ amenity, required answers) and sends it for admin review.',
  })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['categoryId', 'action'],
      properties: {
        categoryId: { type: 'string', format: 'uuid' },
        action: { type: 'string', enum: ['draft', 'submit'] },
        answers: { type: 'string', description: 'JSON string: [{"questionId":"uuid","answer":"..."}]' },
        amenities: { type: 'string', description: 'JSON string array of amenity names: ["Free Parking","WiFi"]' },
        timing: {
          type: 'string',
          description:
            'JSON string keyed by day name: {"Monday":[{"open_time":"09:00 AM","close_time":"07:00 PM","slot_price":"500","discounted_price":"400","max_members":"10"}]}',
        },
        images: { type: 'array', items: { type: 'string', format: 'binary' } },
      },
    },
  })
  @UseInterceptors(FilesInterceptor('images', 12, {
    storage: diskStorage({
      destination: (_req, _file, cb) => {
        const path = './uploads/services';
        if (!fs.existsSync(path)) fs.mkdirSync(path, { recursive: true });
        cb(null, path);
      },
      filename: (_req, file, cb) => {
        const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
        cb(null, `activity-${unique}${extname(file.originalname)}`);
      },
    }),
  }))
  async submitFullActivity(
    @Param('venueId', ParseUUIDPipe) venueId: string,
    @CurrentUser() user: any,
    @UploadedFiles() files: Express.Multer.File[],
    @Body() body: { categoryId: string; action: 'draft' | 'submit'; answers?: string; amenities?: string; timing?: string },
  ) {
    if (!body.categoryId) throw new BadRequestException('categoryId is required');
    if (body.action !== 'draft' && body.action !== 'submit') {
      throw new BadRequestException('action must be "draft" or "submit"');
    }

    const baseUrl = process.env.APP_URL || '';
    const imageUrls = (files || []).map((f) => `${baseUrl}/uploads/services/${f.filename}`);

    const parseJsonArray = (raw?: string): any[] => {
      if (!raw) return [];
      try {
        const parsed = JSON.parse(raw);
        return Array.isArray(parsed) ? parsed : [];
      } catch {
        return [];
      }
    };

    const parseJsonObject = (raw?: string): Record<string, any> => {
      if (!raw) return {};
      try {
        const parsed = JSON.parse(raw);
        return typeof parsed === 'object' && parsed !== null ? parsed : {};
      } catch {
        return {};
      }
    };

    const answers = parseJsonArray(body.answers);
    const amenities = parseJsonArray(body.amenities).filter((a) => typeof a === 'string');
    const timing = parseJsonObject(body.timing);

    const data = await this.venuesService.submitFullActivity(
      venueId,
      user.id,
      { categoryId: body.categoryId, action: body.action },
      imageUrls,
      answers,
      amenities,
      timing,
    );

    const message =
      body.action === 'submit' ? 'Activity submitted for review successfully' : 'Activity saved as draft';

    return { message, data };
  }

  @Get(':venueId/activities/full')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Full activity list — all activities with category info, imageUrls, description & stats' })
  async getVenueActivitiesFull(
    @Param('venueId', ParseUUIDPipe) venueId: string,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.findVenueActivitiesFull(venueId, user.id);
    return { message: 'Activities fetched successfully', data };
  }

  @Get(':venueId/activities')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Activity Management — list activities for a venue with booking count & earnings' })
  @ApiQuery({ name: 'status', required: false, enum: ['active', 'in_review', 'draft', 'inactive'] })
  async getVenueActivities(
    @Param('venueId', ParseUUIDPipe) venueId: string,
    @CurrentUser() user: any,
    @Query('status') status?: 'active' | 'in_review' | 'draft' | 'inactive',
  ) {
    const data = await this.venuesService.findVenueActivities(venueId, user.id, status);
    return { message: 'Activities fetched successfully', data };
  }

  @Post('activities/:serviceId/images')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Steps 2/3 — Upload images for an activity (min 4 enforced at submit, not here)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { images: { type: 'array', items: { type: 'string', format: 'binary' } } },
    },
  })
  @UseInterceptors(FilesInterceptor('images', 10, {
    storage: diskStorage({
      destination: (_req, _file, cb) => {
        const path = './uploads/services';
        if (!fs.existsSync(path)) fs.mkdirSync(path, { recursive: true });
        cb(null, path);
      },
      filename: (_req, file, cb) => {
        const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
        cb(null, `activity-${unique}${extname(file.originalname)}`);
      },
    }),
  }))
  async uploadActivityImages(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
    @UploadedFiles() files: Express.Multer.File[],
  ) {
    const baseUrl = process.env.APP_URL || '';
    const urls = (files || []).map((f) => `${baseUrl}/uploads/services/${f.filename}`);
    const data = await this.venuesService.uploadActivityImages(serviceId, urls, user.id);
    return { message: 'Activity images uploaded successfully', data };
  }

  @Delete('activities/:serviceId/images')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Step 3 — Delete one image from an activity' })
  async deleteActivityImage(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
    @Body() body: { imageUrl: string },
  ) {
    const data = await this.venuesService.deleteServiceImage(serviceId, body.imageUrl, user.id);
    return { message: 'Activity image deleted successfully', data };
  }

  @Get('activities/:serviceId/questions')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: "Step 4 — Get the activity's category question set, with any answers already saved" })
  async getActivityQuestions(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.getActivityQuestions(serviceId, user.id);
    return { message: 'Activity questions fetched successfully', data };
  }

  @Post('activities/:serviceId/answers')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Step 4 — Save / upsert activity-specific question answers' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        answers: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              questionId: { type: 'string', format: 'uuid' },
              answer: { description: 'Any value: string, number, boolean, or array for multi-select' },
            },
          },
        },
      },
    },
  })
  async saveActivityAnswers(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
    @Body() body: { answers: Array<{ questionId: string; answer: any }> },
  ) {
    const data = await this.venuesService.saveActivityAnswers(serviceId, body.answers, user.id);
    return { message: 'Activity answers saved successfully', data };
  }

  @Patch('activities/:serviceId/amenities')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Step 5 — Save amenities for the activity (minimum 1 required)' })
  async setActivityAmenities(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @Body() dto: SetActivityAmenitiesDto,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.setActivityAmenities(serviceId, dto, user.id);
    return { message: 'Activity amenities saved successfully', data };
  }

  @Get('activities/:serviceId')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Step 8 — Combined review payload: images + amenities + answers + slots' })
  async getActivityDetail(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.getActivityDetail(serviceId, user.id);
    return { message: 'Activity details fetched successfully', data };
  }

  @Get('activities/:serviceId/management')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  async getActivityManagement(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
  ) {
    return { data: await this.venuesService.getActivityManagement(serviceId, user.id) };
  }

  @Patch('activities/:serviceId/management')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  async updateActivityManagement(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
    @Body() dto: ManageActivityDto,
  ) {
    await this.venuesService.updateActivityManagement(serviceId, user.id, dto);
    return { message: 'Activity updated successfully' };
  }

  @Delete('activities/:serviceId/management')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  async archiveActivity(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
  ) {
    await this.venuesService.updateActivityManagement(serviceId, user.id, {}, true);
    return { message: 'Activity deleted. Existing bookings are preserved.' };
  }

  @Post('activities/:serviceId/save-draft')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '"Save as Draft" button — explicit confirmation, activity stays editable' })
  async saveActivityDraft(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.saveActivityDraft(serviceId, user.id);
    return { message: 'Activity saved as draft', data };
  }

  @Post('activities/:serviceId/submit')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '"Submit for review" button — validates minimums, draft/rejected -> pending' })
  async submitActivityForReview(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.submitActivityForReview(serviceId, user.id);
    return { message: 'Activity submitted for review successfully', data };
  }

  @Patch('activities/:serviceId/toggle-active')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Pause or resume an approved activity (Active <-> Inactive)' })
  @ApiBody({
    schema: {
      type: 'object',
      required: ['isActive'],
      properties: {
        isActive: { type: 'boolean', example: false },
        reason: { type: 'string', example: 'Maintenance / Repair', description: 'Only used when pausing (isActive: false)' },
      },
    },
  })
  async toggleActivityActive(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
    @Body('isActive') isActive: boolean,
    @Body('reason') reason?: string,
  ) {
    const active = isActive === true || (isActive as any) === 'true';
    const data = await this.venuesService.toggleActivityActive(serviceId, user.id, active, reason);
    const message = active ? 'Activity activated successfully' : 'Activity paused successfully';
    return { message, data };
  }

  // ============ Walk-In Slot Booking ============

  @Get(':venueId/activities/:serviceId/slots')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Get slot availability grid for a date (Partner only)' })
  @ApiQuery({ name: 'date', required: true, description: 'YYYY-MM-DD' })
  @ApiQuery({ name: 'court', required: false, description: 'Court name (for activities with courts)' })
  async getActivitySlots(
    @Param('venueId', ParseUUIDPipe) venueId: string,
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
    @Query('date') date: string,
    @Query('court') court?: string,
  ) {
    if (!date) throw new BadRequestException('date query param is required (YYYY-MM-DD)');
    const data = await this.venuesService.getActivitySlots(venueId, serviceId, user.id, date, court);
    return { message: 'Slots fetched successfully', data };
  }

  @Post(':venueId/activities/:serviceId/walk-in')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Reserve walk-in slot(s) for a participant (Partner only)' })
  async createWalkIn(
    @Param('venueId', ParseUUIDPipe) venueId: string,
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
    @Body() dto: CreateWalkInReservationDto,
  ) {
    const data = await this.venuesService.createWalkIn(venueId, serviceId, user.id, dto);
    return { message: 'Walk-in slot reserved successfully', data };
  }

  @Get(':venueId/activities/:serviceId/walk-in')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'List walk-in reservations for an activity (Partner only)' })
  @ApiQuery({ name: 'date', required: false, description: 'Filter by date YYYY-MM-DD' })
  async getWalkIns(
    @Param('venueId', ParseUUIDPipe) venueId: string,
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: any,
    @Query('date') date?: string,
  ) {
    const data = await this.venuesService.getWalkIns(venueId, serviceId, user.id, date);
    return { message: 'Walk-in reservations fetched successfully', data };
  }

  @Get(':venueId/activities/:serviceId/walk-in/:reservationId')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Get a single walk-in reservation detail (Partner only)' })
  async getWalkIn(
    @Param('venueId', ParseUUIDPipe) venueId: string,
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @Param('reservationId', ParseUUIDPipe) reservationId: string,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.getWalkIn(venueId, serviceId, reservationId, user.id);
    return { message: 'Reservation fetched successfully', data };
  }

  @Delete(':venueId/activities/:serviceId/walk-in/:reservationId')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Release a walk-in reservation — slot returns to ACTIV (Partner only)' })
  async releaseWalkIn(
    @Param('venueId', ParseUUIDPipe) venueId: string,
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @Param('reservationId', ParseUUIDPipe) reservationId: string,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.releaseWalkIn(venueId, serviceId, reservationId, user.id);
    return { message: 'Walk-in reservation released successfully', data };
  }

  // ============ Admin Endpoints ============

  @Post('admin/create')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Create a new venue on behalf of a partner (Admin only)' })
  async adminCreate(@Body() dto: AdminCreateVenueDto) {
    const data = await this.venuesService.create(dto, dto.partnerId);
    return { message: 'Venue created successfully', data };
  }

  @Get('admin/all')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get all venues (Admin only)' })
  @ApiQuery({ name: 'status', enum: VenueStatus, required: false })
  @ApiQuery({ name: 'categoryId', required: false })
  async findAll(
    @Query() pagination: PaginationDto,
    @Query('status') status?: VenueStatus,
    @Query('categoryId') categoryId?: string,
  ) {
    const [venues, total] = await this.venuesService.findAll(pagination, status, categoryId);
    return {
      message: 'Venues fetched successfully',
      data: {
        items: venues,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Get('admin/pending')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get all pending venues (Admin only)' })
  async getPendingVenues(@Query() pagination: PaginationDto) {
    const [venues, total] = await this.venuesService.findAll(pagination, VenueStatus.PENDING);
    return {
      message: 'Pending venues fetched successfully',
      data: {
        items: venues,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Get('admin/stats')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get venue statistics (Admin only)' })
  async getStats() {
    const data = await this.venuesService.getVenueStats();
    return { message: 'Venue stats fetched successfully', data };
  }

  @Patch('admin/:id/approval')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Approve or reject a venue (Admin only)' })
  async processApproval(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() approvalDto: VenueApprovalDto,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.processApproval(id, approvalDto, user.id);
    return {
      message: `Venue ${approvalDto.status} successfully`,
      data,
    };
  }

  @Get('admin/:id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get complete venue details for admin review, including unapproved venues' })
  async findAdminVenue(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.venuesService.findAdminVenue(id);
    return { message: 'Venue fetched successfully', data };
  }

  @Get('admin/activities/pending')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get all activities pending review (Admin only)' })
  async getPendingActivities(@Query() pagination: PaginationDto) {
    const [items, total] = await this.venuesService.findPendingActivities(pagination);
    return {
      message: 'Pending activities fetched successfully',
      data: {
        items,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Patch('admin/activities/:serviceId/approval')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Approve or reject an activity (Admin only)' })
  async processActivityApproval(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @Body() dto: ActivityApprovalDto,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.processActivityApproval(serviceId, dto, user.id);
    return { message: `Activity ${dto.status} successfully`, data };
  }

  // ============ Venue Update Requests ============

  @Post(':id/update-request')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Submit a venue info update request (Partner only)' })
  async submitVenueUpdateRequest(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SubmitVenueUpdateDto,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.submitVenueUpdateRequest(id, user.id, dto);
    return { message: 'Venue update request submitted successfully', data };
  }

  @Get('update-requests/my')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: "Get partner's own venue update requests (Partner only)" })
  async getMyVenueUpdateRequests(@CurrentUser() user: any) {
    const data = await this.venuesService.findMyVenueUpdateRequests(user.id);
    return { message: 'Venue update requests fetched successfully', data };
  }

  @Get('update-requests')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get all venue update requests (Admin only)' })
  @ApiQuery({ name: 'status', enum: VenueUpdateRequestStatus, required: false })
  async findAllVenueUpdateRequests(
    @Query() pagination: PaginationDto,
    @Query('status') status?: VenueUpdateRequestStatus,
  ) {
    const [items, total] = await this.venuesService.findAllVenueUpdateRequests(pagination, status);
    return {
      message: 'Venue update requests fetched successfully',
      data: {
        items,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Get('update-requests/:requestId')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get single venue update request by ID (Admin only)' })
  async findOneVenueUpdateRequest(@Param('requestId', ParseUUIDPipe) requestId: string) {
    const data = await this.venuesService.findOneVenueUpdateRequest(requestId);
    return { message: 'Venue update request fetched successfully', data };
  }

  @Patch('update-requests/:requestId/approve')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Approve venue update request and apply changes to the live venue (Admin only)' })
  async approveVenueUpdateRequest(@Param('requestId', ParseUUIDPipe) requestId: string, @CurrentUser() user: any) {
    const data = await this.venuesService.approveVenueUpdateRequest(requestId, user.id);
    return { message: 'Venue update request approved and applied successfully', data };
  }

  @Patch('update-requests/:requestId/reject')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reject venue update request (Admin only)' })
  async rejectVenueUpdateRequest(
    @Param('requestId', ParseUUIDPipe) requestId: string,
    @Body() dto: ReviewVenueUpdateDto,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.rejectVenueUpdateRequest(requestId, dto, user.id);
    return { message: 'Venue update request rejected successfully', data };
  }

  // ============ Public / User Endpoints ============

  @Get()
  @Public()
  @ApiOperation({ summary: 'Get all approved venues (Public)' })
  @ApiQuery({ name: 'categoryId', required: false })
  async findApproved(
    @Query() pagination: PaginationDto,
    @Query('categoryId') categoryId?: string,
  ) {
    const [venues, total] = await this.venuesService.findApproved(pagination, categoryId);
    return {
      message: 'Venues fetched successfully',
      data: {
        items: venues,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Get(':id')
  @Public()
  @ApiOperation({ summary: 'Get venue details by ID (Public)' })
  async findOne(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.venuesService.findPublicVenue(id);
    return { message: 'Venue fetched successfully', data };
  }

  @Patch(':id')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER, UserRole.ADMIN)
  @ApiOperation({ summary: 'Update venue (Partner can update own, Admin can update any)' })
  async update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updateVenueDto: UpdateVenueDto,
    @CurrentUser() user: any,
  ) {
    const data = await this.venuesService.update(id, updateVenueDto, user);
    return { message: 'Venue updated successfully', data };
  }

  @Delete(':id')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER, UserRole.ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete venue (Partner can delete own, Admin can delete any)' })
  async remove(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: any) {
    await this.venuesService.remove(id, user);
    return { message: 'Venue deleted successfully', data: null };
  }
}
