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
  UploadedFile,
  UseInterceptors,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { extname } from 'path';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiConsumes, ApiBody, ApiQuery } from '@nestjs/swagger';
import { PartnersService } from './partners.service';
import { CreatePartnerDto } from './dto/create-partner.dto';
import { UpdatePartnerDto } from './dto/update-partner.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { Partner } from './entities/partner.entity';
import { GstVerificationStatus } from './entities/gst-verification-request.entity';
import { SubmitGstVerificationDto } from './dto/submit-gst-verification.dto';
import { ReviewGstVerificationDto } from './dto/review-gst-verification.dto';
import { CloudinaryService } from '../cloudinary/cloudinary.service';

@ApiTags('Partners')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('partners')
export class PartnersController {
  constructor(
    private readonly partnersService: PartnersService,
    private readonly cloudinaryService: CloudinaryService,
  ) {}

  @Post()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Create partner profile (Admin only)' })
  async create(@Body() createPartnerDto: CreatePartnerDto) {
    const data = await this.partnersService.create(createPartnerDto);
    return { message: 'Partner created successfully', data };
  }

  @Get()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get all partners (Admin only)' })
  async findAll(@Query() pagination: PaginationDto) {
    const [partners, total] = await this.partnersService.findAll(pagination);
    return {
      message: 'Partners fetched successfully',
      data: {
        items: partners,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Get('profile')
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Get own partner profile' })
  async getOwnProfile(@CurrentUser() partner: Partner) {
    const data = await this.partnersService.findOne(partner.id);
    return { message: 'Partner profile fetched successfully', data };
  }

  @Patch('avatar')
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Upload or update partner avatar (Partner only)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        avatar: { type: 'string', format: 'binary' },
      },
    },
  })
  @UseInterceptors(FileInterceptor('avatar', {
    storage: memoryStorage(),
  }))
  async updateAvatar(
    @CurrentUser() partner: Partner,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('Avatar image file is required');
    const avatarUrl = await this.cloudinaryService.uploadFile(file, 'activ/avatars', 'image');
    const data = await this.partnersService.updateAvatar(partner.id, avatarUrl);
    return { message: 'Avatar updated successfully', data };
  }

  @Delete('avatar')
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Remove partner avatar (Partner only)' })
  async removeAvatar(@CurrentUser() partner: Partner) {
    const data = await this.partnersService.removeAvatar(partner.id);
    return { message: 'Avatar removed successfully', data };
  }

  @Patch('profile')
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Update own partner profile' })
  async updateOwnProfile(
    @CurrentUser() partner: Partner,
    @Body() updatePartnerDto: UpdatePartnerDto,
  ) {
    const data = await this.partnersService.updateOwnProfile(partner.id, updatePartnerDto);
    return { message: 'Partner profile updated successfully', data };
  }

  @Patch(':id')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Update partner (Admin only)' })
  async update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updatePartnerDto: UpdatePartnerDto,
  ) {
    const data = await this.partnersService.update(id, updatePartnerDto);
    return { message: 'Partner updated successfully', data };
  }

  @Patch(':id/toggle-status')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Toggle partner active status (Admin only)' })
  async toggleStatus(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.partnersService.toggleStatus(id);
    return { message: 'Partner status updated successfully', data };
  }

  @Delete('account')
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Delete own partner account (Partner only)',
    description:
      'Permanently deletes the authenticated partner account along with all venues, venue data, and team members. Blocked if any venue has active (pending or confirmed) bookings.',
  })
  async deleteAccount(@CurrentUser() partner: Partner) {
    await this.partnersService.deleteAccount(partner.id);
    return { message: 'Account deleted successfully', data: null };
  }

  @Delete(':id')
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Delete partner (Admin only)',
    description: 'Permanently deletes the partner account and associated data in a transaction. Blocked by pending or confirmed bookings, administrator logins, or owner logins shared with another partner.',
  })
  async remove(@Param('id', ParseUUIDPipe) id: string) {
    await this.partnersService.remove(id);
    return { message: 'Partner deleted successfully', data: null };
  }

  // ─── GST Verification ────────────────────────────────────────────────────

  @Post('gst-verification')
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Submit GST verification request with document (Partner only)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['gstNumber', 'gstName'],
      properties: {
        gstNumber: { type: 'string', example: '27AAPFU0939F1ZV' },
        gstName:   { type: 'string', example: 'Acme Fitness Pvt Ltd' },
        gstDoc:    { type: 'string', format: 'binary' },
      },
    },
  })
  @UseInterceptors(
    FileInterceptor('gstDoc', {
      storage: memoryStorage(),
      fileFilter: (_req, file, cb) => {
        const allowed = ['.jpg', '.jpeg', '.png', '.pdf'];
        if (!allowed.includes(extname(file.originalname).toLowerCase())) {
          return cb(new BadRequestException('Only JPG, JPEG, PNG and PDF files are allowed'), false);
        }
        cb(null, true);
      },
      limits: { fileSize: 10 * 1024 * 1024 },
    }),
  )
  async submitGstVerification(
    @CurrentUser() partner: Partner,
    @Body() dto: SubmitGstVerificationDto,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (file) {
      (file as Express.Multer.File & { cloudinaryUrl?: string }).cloudinaryUrl =
        await this.cloudinaryService.uploadFile(file, 'activ/gst-docs', 'auto');
    }
    const data = await this.partnersService.submitGstVerification(partner.id, dto, file);
    return { message: 'GST verification request submitted successfully', data };
  }

  @Get('gst-verification/my')
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Get own latest GST verification request status (Partner only)' })
  async getMyGstVerification(@CurrentUser() partner: Partner) {
    const data = await this.partnersService.findMyGstVerification(partner.id);
    return { message: 'GST verification request fetched successfully', data };
  }

  @Get('gst-verification')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get all GST verification requests (Admin only)' })
  @ApiQuery({ name: 'status', enum: GstVerificationStatus, required: false })
  async findAllGstVerifications(
    @Query() pagination: PaginationDto,
    @Query('status') status?: GstVerificationStatus,
  ) {
    const [items, total] = await this.partnersService.findAllGstVerifications(pagination, status);
    return {
      message: 'GST verification requests fetched successfully',
      data: {
        items,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Get('gst-verification/:id')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get a GST verification request by ID (Admin only)' })
  async findOneGstVerification(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.partnersService.findOneGstVerification(id);
    return { message: 'GST verification request fetched successfully', data };
  }

  @Patch('gst-verification/:id/approve')
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Approve GST verification — writes to partner row and deletes request (Admin only)',
  })
  async approveGstVerification(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() admin: any) {
    const data = await this.partnersService.approveGstVerification(id, admin.id);
    return { message: 'GST verification approved and partner updated successfully', data };
  }

  @Patch('gst-verification/:id/reject')
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reject GST verification with optional notes (Admin only)' })
  async rejectGstVerification(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReviewGstVerificationDto,
  ) {
    const data = await this.partnersService.rejectGstVerification(id, dto);
    return { message: 'GST verification rejected', data };
  }

  @Get(':id')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get partner by ID (Admin only)' })
  async findOne(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.partnersService.findOne(id);
    return { message: 'Partner fetched successfully', data };
  }
}
