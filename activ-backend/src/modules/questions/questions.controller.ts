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
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { QuestionsService } from './questions.service';
import { CreateQuestionDto } from './dto/create-question.dto';
import { UpdateQuestionDto } from './dto/update-question.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { PaginationDto } from '../../common/dto/pagination.dto';

@ApiTags('Questions')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('questions')
export class QuestionsController {
  constructor(private readonly questionsService: QuestionsService) {}

  @Post()
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Create a question (Admin only)' })
  async create(@Body() createQuestionDto: CreateQuestionDto) {
    const data = await this.questionsService.create(createQuestionDto);
    return { message: 'Question created successfully', data };
  }

  @Get()
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get all questions with pagination (Admin only)' })
  @ApiQuery({ name: 'categoryId', required: false })
  async findAll(@Query() pagination: PaginationDto, @Query('categoryId') categoryId?: string) {
    const [questions, total] = await this.questionsService.findAll(pagination, categoryId);
    return {
      message: 'Questions fetched successfully',
      data: {
        items: questions,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Get('category/:categoryId')
  @Public()
  @ApiOperation({ summary: 'Get questions for a category (includes global questions) - Public' })
  async findByCategory(@Param('categoryId', ParseUUIDPipe) categoryId: string) {
    const data = await this.questionsService.findByCategoryId(categoryId);
    return { message: 'Questions fetched successfully', data };
  }

  @Get(':id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get question by ID (Admin only)' })
  async findOne(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.questionsService.findOne(id);
    return { message: 'Question fetched successfully', data };
  }

  @Patch('reorder')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Reorder questions (Admin only)' })
  async reorder(@Body() questionOrders: { id: string; order: number }[]) {
    await this.questionsService.reorder(questionOrders);
    return { message: 'Questions reordered successfully', data: null };
  }

  @Patch(':id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Update question (Admin only)' })
  async update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updateQuestionDto: UpdateQuestionDto,
  ) {
    const data = await this.questionsService.update(id, updateQuestionDto);
    return { message: 'Question updated successfully', data };
  }

  @Patch(':id/toggle-status')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Toggle question status (Admin only)' })
  async toggleStatus(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.questionsService.toggleStatus(id);
    return { message: 'Question status updated successfully', data };
  }

  @Delete(':id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete question (Admin only)' })
  async remove(@Param('id', ParseUUIDPipe) id: string) {
    await this.questionsService.remove(id);
    return { message: 'Question deleted successfully', data: null };
  }
}
