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
  UseInterceptors,
  UploadedFile,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import * as fs from 'fs';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiConsumes } from '@nestjs/swagger';
import { CategoriesService } from './categories.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { PaginationDto } from '../../common/dto/pagination.dto';

const categoryImageStorage = diskStorage({
  destination: (req, file, cb) => {
    const uploadPath = './uploads/categories';
    if (!fs.existsSync(uploadPath)) {
      fs.mkdirSync(uploadPath, { recursive: true });
    }
    cb(null, uploadPath);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, `category-${uniqueSuffix}${extname(file.originalname)}`);
  },
});

@ApiTags('Categories')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('categories')
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  @Post()
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Create a new category (Admin only)' })
  @ApiConsumes('multipart/form-data', 'application/json')
  @UseInterceptors(FileInterceptor('image', { storage: categoryImageStorage }))
  async create(
    @Body() createCategoryDto: CreateCategoryDto,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (file) {
      const baseUrl = process.env.APP_URL || '';
      createCategoryDto.imageUrl = `${baseUrl}/uploads/categories/${file.filename}`;
    }
    const data = await this.categoriesService.create(createCategoryDto);
    return { message: 'Category created successfully', data };
  }

  @Get()
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get all categories with pagination (Admin only)' })
  async findAll(@Query() pagination: PaginationDto) {
    const [categories, total] = await this.categoriesService.findAll(pagination);
    return {
      message: 'Categories fetched successfully',
      data: {
        items: categories,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Get('active')
  @Public()
  @ApiOperation({ summary: 'Get all active categories (Public)' })
  async findAllActive() {
    const data = await this.categoriesService.findAllActive();
    return { message: 'Categories fetched successfully', data };
  }

  @Get(':id')
  @Public()
  @ApiOperation({ summary: 'Get category by ID (Public)' })
  async findOne(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.categoriesService.findOne(id);
    return { message: 'Category fetched successfully', data };
  }

  @Patch(':id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Update category (Admin only)' })
  @ApiConsumes('multipart/form-data', 'application/json')
  @UseInterceptors(FileInterceptor('image', { storage: categoryImageStorage }))
  async update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updateCategoryDto: UpdateCategoryDto,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (file) {
      const baseUrl = process.env.APP_URL || '';
      updateCategoryDto.imageUrl = `${baseUrl}/uploads/categories/${file.filename}`;
    }
    const data = await this.categoriesService.update(id, updateCategoryDto);
    return { message: 'Category updated successfully', data };
  }

  @Patch(':id/toggle-status')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Toggle category status (Admin only)' })
  async toggleStatus(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.categoriesService.toggleStatus(id);
    return { message: 'Category status updated successfully', data };
  }

  @Delete(':id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete category (Admin only)' })
  async remove(@Param('id', ParseUUIDPipe) id: string) {
    await this.categoriesService.remove(id);
    return { message: 'Category deleted successfully', data: null };
  }
}
