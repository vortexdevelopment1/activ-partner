import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  Query,
  ParseUUIDPipe,
  HttpCode,
  HttpStatus,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import * as fs from 'fs';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery, ApiConsumes, ApiBody } from '@nestjs/swagger';
import { SupportService } from './support.service';
import { CreateCallbackRequestDto } from './dto/create-callback-request.dto';
import { UpdateCallbackRequestDto } from './dto/update-callback-request.dto';
import { CreateSupportEmailDto } from './dto/create-support-email.dto';
import { UpdateSupportEmailDto } from './dto/update-support-email.dto';
import { Roles } from '../../common/decorators/roles.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { CallbackStatus } from '../../common/enums/callback-status.enum';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { Partner } from '../partners/entities/partner.entity';

@ApiTags('Support')
@Controller('support')
export class SupportController {
  constructor(private readonly supportService: SupportService) {}

  @Public()
  @Post('callback')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: 'Submit a callback request',
    description: 'No login required — reachable from the pre-login Help FAB as well as inside the app.',
  })
  async createCallback(@Body() dto: CreateCallbackRequestDto) {
    const data = await this.supportService.createCallback(dto);
    return { message: 'Callback request submitted successfully', data };
  }

  @Get('callback')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get all callback requests (Admin only)' })
  @ApiQuery({ name: 'status', enum: CallbackStatus, required: false })
  async findAll(@Query() pagination: PaginationDto, @Query('status') status?: CallbackStatus) {
    const [items, total] = await this.supportService.findAll(pagination, status);
    return {
      message: 'Callback requests fetched successfully',
      data: {
        items,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Get('callback/:id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get a callback request by ID (Admin only)' })
  async findOne(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.supportService.findOne(id);
    return { message: 'Callback request fetched successfully', data };
  }

  @Patch('callback/:id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Update callback request status / notes (Admin only)' })
  async update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateCallbackRequestDto,
  ) {
    const data = await this.supportService.update(id, dto);
    return { message: 'Callback request updated successfully', data };
  }

  @Delete('callback/:id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete a callback request (Admin only)' })
  async remove(@Param('id', ParseUUIDPipe) id: string) {
    await this.supportService.remove(id);
    return { message: 'Callback request deleted successfully', data: null };
  }

  // ─── Support Email ────────────────────────────────────────────────────────

  @Post('email')
  @ApiBearerAuth()
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Submit a support email with optional attachment (Partner only)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['subject', 'message'],
      properties: {
        subject:    { type: 'string', example: 'Issue with booking' },
        message:    { type: 'string', example: 'I am facing an issue...' },
        attachment: { type: 'string', format: 'binary' },
      },
    },
  })
  @UseInterceptors(
    FileInterceptor('attachment', {
      storage: diskStorage({
        destination: (_req, _file, cb) => {
          const dir = './uploads/support-attachments';
          if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
          cb(null, dir);
        },
        filename: (_req, file, cb) => {
          const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
          cb(null, `support-${unique}${extname(file.originalname)}`);
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
  async createEmail(
    @Body() dto: CreateSupportEmailDto,
    @CurrentUser() partner: Partner,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    const data = await this.supportService.createEmail(dto, partner.id, file);
    return { message: 'Support email submitted successfully', data };
  }

  @Get('email')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get all support emails (Admin only)' })
  @ApiQuery({ name: 'status', enum: CallbackStatus, required: false })
  async findAllEmails(
    @Query() pagination: PaginationDto,
    @Query('status') status?: CallbackStatus,
  ) {
    const [items, total] = await this.supportService.findAllEmails(pagination, status);
    return {
      message: 'Support emails fetched successfully',
      data: {
        items,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Get('email/:id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get a support email by ID (Admin only)' })
  async findOneEmail(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.supportService.findOneEmail(id);
    return { message: 'Support email fetched successfully', data };
  }

  @Patch('email/:id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Update support email status / notes (Admin only)' })
  async updateEmail(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateSupportEmailDto,
  ) {
    const data = await this.supportService.updateEmail(id, dto);
    return { message: 'Support email updated successfully', data };
  }

  @Delete('email/:id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete a support email (Admin only)' })
  async removeEmail(@Param('id', ParseUUIDPipe) id: string) {
    await this.supportService.removeEmail(id);
    return { message: 'Support email deleted successfully', data: null };
  }
}
