import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiParam, ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { CommissionService } from './commission.service';
import { CreateCityCommissionDto } from './dto/create-city-commission.dto';
import { UpdateCityCommissionDto } from './dto/update-city-commission.dto';

@ApiTags('Commissions')
@Controller('commissions')
export class CommissionController {
  constructor(private readonly commissionService: CommissionService) {}

  @Post()
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Create city commission (Admin only)' })
  async create(@Body() dto: CreateCityCommissionDto) {
    const data = await this.commissionService.create(dto);
    return { message: 'City commission created successfully', data };
  }

  @Get()
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get all city commissions with pagination (Admin only)' })
  async findAll(@Query() pagination: PaginationDto) {
    const [items, total] = await this.commissionService.findAll(pagination);
    return {
      message: 'City commissions fetched successfully',
      data: {
        items,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  // NOTE: this route must come before /:id to avoid route collision
  @Get('city/:city')
  @Public()
  @ApiOperation({ summary: 'Get commission percentage by city name (Public). Returns default 10% if not configured.' })
  @ApiParam({ name: 'city', example: 'Mumbai', description: 'City name' })
  async getByCity(@Param('city') city: string) {
    const data = await this.commissionService.getCommissionByCity(city);
    return { message: 'Commission fetched successfully', data };
  }

  @Get(':id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get city commission by ID (Admin only)' })
  async findOne(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.commissionService.findOne(id);
    return { message: 'City commission fetched successfully', data };
  }

  @Patch(':id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Update city commission (Admin only)' })
  async update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateCityCommissionDto) {
    const data = await this.commissionService.update(id, dto);
    return { message: 'City commission updated successfully', data };
  }

  @Delete(':id')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete city commission (Admin only)' })
  async remove(@Param('id', ParseUUIDPipe) id: string) {
    await this.commissionService.remove(id);
    return { message: 'City commission deleted successfully', data: null };
  }
}
