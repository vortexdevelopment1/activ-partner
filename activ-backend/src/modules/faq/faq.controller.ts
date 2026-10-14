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
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { FaqService } from './faq.service';
import { CreateFaqDto } from './dto/create-faq.dto';
import { UpdateFaqDto } from './dto/update-faq.dto';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { PaginationDto } from '../../common/dto/pagination.dto';

@ApiTags('FAQs')
@Controller('faqs')
export class FaqController {
  constructor(private readonly faqService: FaqService) {}

  // ─── Public ───────────────────────────────────────────────────────────────

  @Get('public')
  @Public()
  @ApiOperation({ summary: 'Get all active FAQs (Public — no auth required)' })
  async findAllActive() {
    const data = await this.faqService.findAllActive();
    return { message: 'FAQs fetched successfully', data };
  }

  // ─── Admin CRUD ───────────────────────────────────────────────────────────

  @Post()
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a FAQ (Admin only)' })
  async create(@Body() dto: CreateFaqDto) {
    const data = await this.faqService.create(dto);
    return { message: 'FAQ created successfully', data };
  }

  @Get()
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get all FAQs with pagination and search (Admin only)' })
  async findAll(@Query() pagination: PaginationDto) {
    const [items, total] = await this.faqService.findAll(pagination);
    return {
      message: 'FAQs fetched successfully',
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
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get a FAQ by ID (Admin only)' })
  async findOne(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.faqService.findOne(id);
    return { message: 'FAQ fetched successfully', data };
  }

  @Patch(':id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Update a FAQ (Admin only)' })
  async update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateFaqDto) {
    const data = await this.faqService.update(id, dto);
    return { message: 'FAQ updated successfully', data };
  }

  @Delete(':id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete a FAQ (Admin only)' })
  async remove(@Param('id', ParseUUIDPipe) id: string) {
    await this.faqService.remove(id);
    return { message: 'FAQ deleted successfully', data: null };
  }
}
