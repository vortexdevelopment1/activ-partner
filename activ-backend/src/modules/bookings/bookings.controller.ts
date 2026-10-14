import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Query,
  UseGuards,
  ParseUUIDPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { BookingsService } from './bookings.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { UpdateBookingDto } from './dto/update-booking.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { BookingStatus } from '../../common/enums/booking-status.enum';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { User } from '../users/entities/user.entity';

@ApiTags('Bookings')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('bookings')
export class BookingsController {
  constructor(private readonly bookingsService: BookingsService) {}

  @Post()
  @Roles(UserRole.USER)
  @ApiOperation({ summary: 'Create a booking (User only)' })
  async create(@Body() createBookingDto: CreateBookingDto, @CurrentUser() user: User) {
    const data = await this.bookingsService.create(createBookingDto, user.id);
    return { message: 'Booking created successfully', data };
  }

  @Get()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get all bookings (Admin only)' })
  @ApiQuery({ name: 'status', enum: BookingStatus, required: false })
  async findAll(@Query() pagination: PaginationDto, @Query('status') status?: BookingStatus) {
    const [bookings, total] = await this.bookingsService.findAll(pagination, status);
    return {
      message: 'Bookings fetched successfully',
      data: {
        items: bookings,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Get('my-bookings')
  @Roles(UserRole.USER)
  @ApiOperation({ summary: "Get current user's bookings" })
  @ApiQuery({ name: 'status', enum: BookingStatus, required: false })
  async getMyBookings(
    @Query() pagination: PaginationDto,
    @CurrentUser() user: User,
    @Query('status') status?: BookingStatus,
  ) {
    const [bookings, total] = await this.bookingsService.findByUser(user.id, pagination, status);
    return {
      message: 'Bookings fetched successfully',
      data: {
        items: bookings,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Get('venue/:venueId')
  @Roles(UserRole.PARTNER, UserRole.ADMIN)
  @ApiOperation({ summary: 'Get bookings for a venue (Partner/Admin)' })
  @ApiQuery({ name: 'status', enum: BookingStatus, required: false })
  async getVenueBookings(
    @Param('venueId', ParseUUIDPipe) venueId: string,
    @Query() pagination: PaginationDto,
    @Query('status') status?: BookingStatus,
  ) {
    const [bookings, total] = await this.bookingsService.findByVenue(venueId, pagination, status);
    return {
      message: 'Venue bookings fetched successfully',
      data: {
        items: bookings,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Get('stats')
  @Roles(UserRole.ADMIN, UserRole.PARTNER)
  @ApiOperation({ summary: 'Get booking statistics' })
  async getStats(@CurrentUser() user: User) {
    const partnerId = user.role === UserRole.PARTNER ? user.id : undefined;
    const data = await this.bookingsService.getBookingStats(partnerId);
    return { message: 'Booking stats fetched successfully', data };
  }

  @Get('reference/:reference')
  @ApiOperation({ summary: 'Get booking by reference number' })
  async findByReference(@Param('reference') reference: string) {
    const data = await this.bookingsService.findByReference(reference);
    return { message: 'Booking fetched successfully', data };
  }

  @Get('payout-history')
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: "Get the current partner's payout transaction history" })
  @ApiQuery({ name: 'status', enum: ['success', 'pending', 'failed'], required: false })
  async getPayoutHistory(
    @Query() pagination: PaginationDto,
    @CurrentUser() user: User,
    @Query('status') status?: 'success' | 'pending' | 'failed',
  ) {
    const data = await this.bookingsService.getPayoutHistory(user, pagination, status);
    return { message: 'Payout history fetched successfully', data };
  }

  @Get(':id/payout-statement')
  @Roles(UserRole.PARTNER, UserRole.ADMIN)
  @ApiOperation({ summary: 'Get the payout breakdown for a single booking (Transaction Details screen)' })
  async getPayoutStatement(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: User) {
    const data = await this.bookingsService.getPayoutStatement(id, user);
    return { message: 'Payout statement fetched successfully', data };
  }

  @Get(':id/payout-statement/download')
  @Roles(UserRole.PARTNER, UserRole.ADMIN)
  @ApiOperation({ summary: 'Download the branded Transaction Statement PDF (GST/Non-GST) for a booking' })
  async downloadPayoutStatement(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: User) {
    const data = await this.bookingsService.generatePayoutStatementPdf(id, user);
    return { message: 'Transaction statement generated successfully', data };
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get booking by ID' })
  async findOne(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.bookingsService.findOne(id);
    return { message: 'Booking fetched successfully', data };
  }

  @Patch(':id/cancel')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Cancel a booking' })
  async cancel(
    @Param('id', ParseUUIDPipe) id: string,
    @Body('reason') reason: string,
    @CurrentUser() user: User,
  ) {
    const data = await this.bookingsService.cancel(id, reason, user);
    return { message: 'Booking cancelled successfully', data };
  }

  @Patch(':id/confirm')
  @Roles(UserRole.ADMIN, UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Confirm a booking (Admin/Partner)' })
  async confirm(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.bookingsService.confirm(id);
    return { message: 'Booking confirmed successfully', data };
  }

  @Patch(':id/complete')
  @Roles(UserRole.ADMIN, UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Mark booking as completed (Admin/Partner)' })
  async complete(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.bookingsService.complete(id);
    return { message: 'Booking completed successfully', data };
  }

  @Patch(':id/check-in')
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Check in a customer — marks booking as confirmed (Partner only)' })
  async checkIn(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: User) {
    const data = await this.bookingsService.checkIn(id, user.id);
    return { message: 'Customer checked in successfully', data };
  }

  @Patch(':id/no-show')
  @Roles(UserRole.PARTNER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Mark booking as no-show (Partner only)' })
  async markNoShow(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: User) {
    const data = await this.bookingsService.markNoShow(id, user.id);
    return { message: 'Booking marked as no-show', data };
  }
}
