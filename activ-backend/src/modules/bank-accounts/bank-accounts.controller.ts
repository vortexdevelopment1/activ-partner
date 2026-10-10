import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Body,
  Query,
  ParseUUIDPipe,
  HttpCode,
  HttpStatus,
  UploadedFile,
  UseInterceptors,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import * as fs from 'fs';
import {
  ApiTags,
  ApiBearerAuth,
  ApiOperation,
  ApiConsumes,
  ApiBody,
  ApiQuery,
} from '@nestjs/swagger';
import { BankAccountsService } from './bank-accounts.service';
import { SubmitBankAccountDto } from './dto/submit-bank-account.dto';
import { ReviewBankAccountDto } from './dto/review-bank-account.dto';
import { BankAccountStatus } from './entities/bank-account.entity';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { PaginationDto } from '../../common/dto/pagination.dto';

@ApiTags('Bank Accounts')
@ApiBearerAuth()
@Controller('bank-accounts')
export class BankAccountsController {
  constructor(private readonly bankAccountsService: BankAccountsService) {}

  // ─── Partner ────────────────────────────────────────────────────────────────

  @Post()
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Submit bank account details for verification (Partner only)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['accountHolderName', 'bankName', 'accountNumber', 'ifscCode', 'accountType'],
      properties: {
        accountHolderName: { type: 'string', example: 'Rahul Sharma' },
        bankName:          { type: 'string', example: 'HDFC Bank' },
        accountNumber:     { type: 'string', example: '1234567890' },
        ifscCode:          { type: 'string', example: 'HDFC0001234' },
        accountType:       { type: 'string', example: 'Saving Account' },
        branchName:        { type: 'string', example: 'Kormangala, Bengaluru' },
        cancelledCheque:   { type: 'string', format: 'binary' },
      },
    },
  })
  @UseInterceptors(FileInterceptor('cancelledCheque', {
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter: (_req, file, cb) => {
      const allowed = ['.jpg', '.jpeg', '.png', '.pdf'];
      cb(allowed.includes(extname(file.originalname).toLowerCase())
        ? null : new BadRequestException('Only JPG, JPEG, PNG and PDF files are allowed'),
        allowed.includes(extname(file.originalname).toLowerCase()));
    },
    storage: diskStorage({
      destination: (_req, _file, cb) => {
        const dir = './uploads/bank-docs';
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
        cb(null, dir);
      },
      filename: (_req, file, cb) => {
        const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
        cb(null, `cheque-${unique}${extname(file.originalname)}`);
      },
    }),
  }))
  async submit(
    @CurrentUser() user: any,
    @Body() dto: SubmitBankAccountDto,
    @UploadedFile() file: Express.Multer.File,
  ) {
    const cancelledChequeUrl = file
      ? `${process.env.APP_URL || ''}/uploads/bank-docs/${file.filename}`
      : undefined;

    const data = await this.bankAccountsService.submit(user.id, dto, cancelledChequeUrl);
    return { message: 'Bank account submitted for verification', data };
  }

  @Get('my')
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: "Get partner's own bank account submissions" })
  async getMyBankAccounts(@CurrentUser() user: any) {
    const data = await this.bankAccountsService.findByPartner(user.id);
    return { message: 'Bank accounts fetched successfully', data };
  }

  @Get('summary')
  @Roles(UserRole.PARTNER)
  async summary(@CurrentUser() user: any) {
    return { message: 'Bank account summary fetched', data: await this.bankAccountsService.summary(user.id) };
  }

  @Patch(':id/mark-verified-seen')
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Mark verified screen as seen (Partner only)',
    description: 'Call once after showing the Bank Account Verified screen. Sets hasSeenVerifiedScreen = true so the screen is never shown again.',
  })
  async markVerifiedScreenSeen(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: any,
  ) {
    const data = await this.bankAccountsService.markVerifiedScreenSeen(id, user.id);
    return { message: 'Verified screen marked as seen', data };
  }

  // ─── Admin ───────────────────────────────────────────────────────────────────

  @Get()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'List all bank account submissions (Admin only)' })
  @ApiQuery({ name: 'status', enum: BankAccountStatus, required: false })
  async findAll(
    @Query() pagination: PaginationDto,
    @Query('status') status?: BankAccountStatus,
  ) {
    const [items, total] = await this.bankAccountsService.findAll(pagination, status);
    return {
      message: 'Bank accounts fetched successfully',
      data: {
        items,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Get(':id')
  @Roles(UserRole.ADMIN, UserRole.PARTNER)
  @ApiOperation({ summary: 'Get bank account submission by ID' })
  async findOne(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: any) {
    const data = await this.bankAccountsService.findOne(id, user.role === UserRole.ADMIN ? undefined : user.id);
    return { message: 'Bank account fetched successfully', data };
  }

  @Patch(':id/review')
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Approve or reject a bank account submission (Admin only)' })
  async review(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReviewBankAccountDto,
    @CurrentUser() admin: any,
  ) {
    const data = await this.bankAccountsService.review(id, dto, admin.id);
    return { message: `Bank account ${dto.status} successfully`, data };
  }
}
