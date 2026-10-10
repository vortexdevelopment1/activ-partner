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
  UploadedFiles,
  UseInterceptors,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor, FileFieldsInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import * as fs from 'fs';
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

@ApiTags('Partners')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('partners')
export class PartnersController {
  constructor(private readonly partnersService: PartnersService) {}

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
    storage: diskStorage({
      destination: (_req, _file, cb) => {
        const dir = './uploads/avatars';
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
        cb(null, dir);
      },
      filename: (_req, file, cb) => {
        const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
        cb(null, `avatar-${unique}${extname(file.originalname)}`);
      },
    }),
  }))
  async updateAvatar(
    @CurrentUser() partner: Partner,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('Avatar image file is required');
    const avatarUrl = `${process.env.APP_URL || ''}/uploads/avatars/${file.filename}`;
    const data = await this.partnersService.updateAvatar(partner.id, avatarUrl);
    return { message: 'Avatar updated successfully', data };
  }

  @Patch('legal')
  @Roles(UserRole.PARTNER)
  @ApiOperation({
    summary: 'Update legal documents (Partner only — post-approval)',
    description: 'All fields and files are optional. Only provided values are overwritten.',
  })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        aadhaarName:   { type: 'string', example: 'Virat Kohli' },
        aadhaarNumber: { type: 'string', example: '1234-5678-9101' },
        panNumber:     { type: 'string', example: 'ABCDE1234F' },
        gstNumber:     { type: 'string', example: '27AAPFU0939F1ZV' },
        gstName:       { type: 'string', example: 'Acme Fitness Pvt Ltd' },
        panCard:       { type: 'string', format: 'binary' },
        aadhaarCard:   { type: 'string', format: 'binary' },
        gstinDoc:      { type: 'string', format: 'binary' },
      },
    },
  })
  @UseInterceptors(FileFieldsInterceptor(
    [
      { name: 'panCard', maxCount: 1 },
      { name: 'aadhaarCard', maxCount: 1 },
      { name: 'gstinDoc', maxCount: 1 },
    ],
    {
      storage: diskStorage({
        destination: (_req, _file, cb) => {
          const dir = './uploads/legal';
          if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
          cb(null, dir);
        },
        filename: (_req, file, cb) => {
          const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
          cb(null, `legal-${unique}${extname(file.originalname)}`);
        },
      }),
    },
  ))
  async updateLegal(
    @CurrentUser() partner: Partner,
    @Body() body: { aadhaarName?: string; aadhaarNumber?: string; panNumber?: string; gstNumber?: string; gstName?: string },
    @UploadedFiles() files: { panCard?: Express.Multer.File[]; aadhaarCard?: Express.Multer.File[]; gstinDoc?: Express.Multer.File[] },
  ) {
    const baseUrl = process.env.APP_URL || '';
    const fields: Record<string, string> = {};

    if (body.aadhaarName)   fields.aadhaarName   = body.aadhaarName;
    if (body.aadhaarNumber) fields.aadhaarNumber = body.aadhaarNumber;
    if (body.panNumber)     fields.panNumber     = body.panNumber;
    if (body.gstNumber)     fields.gstNumber     = body.gstNumber;
    if (body.gstName)       fields.gstName       = body.gstName;
    if (files?.panCard?.[0])     fields.panCardUrl     = `${baseUrl}/uploads/legal/${files.panCard[0].filename}`;
    if (files?.aadhaarCard?.[0]) fields.aadhaarCardUrl = `${baseUrl}/uploads/legal/${files.aadhaarCard[0].filename}`;
    if (files?.gstinDoc?.[0])    fields.gstinDocUrl    = `${baseUrl}/uploads/legal/${files.gstinDoc[0].filename}`;

    const data = await this.partnersService.updateLegalInfo(partner.id, fields);
    return { message: 'Legal information updated successfully', data };
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

  @Patch(':id/verify')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Verify partner (Admin only)' })
  async verify(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.partnersService.verify(id);
    return { message: 'Partner verified successfully', data };
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
  @ApiOperation({ summary: 'Delete partner (Admin only)' })
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
      storage: diskStorage({
        destination: (_req, _file, cb) => {
          const dir = './uploads/gst-docs';
          if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
          cb(null, dir);
        },
        filename: (_req, file, cb) => {
          const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
          cb(null, `gst-${unique}${extname(file.originalname)}`);
        },
      }),
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
  async approveGstVerification(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.partnersService.approveGstVerification(id);
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
