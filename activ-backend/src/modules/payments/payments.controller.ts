import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
  ParseUUIDPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { PaymentsService } from './payments.service';
import { CreatePaymentOrderDto, VerifyPaymentDto } from './dto/create-payment.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { PaymentStatus } from '../../common/enums/booking-status.enum';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { User } from '../users/entities/user.entity';

@ApiTags('Payments')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('payments')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Post('create-order')
  @Roles(UserRole.USER)
  @ApiOperation({ summary: 'Create a payment order (User only)' })
  async createOrder(
    @Body() createPaymentDto: CreatePaymentOrderDto,
    @CurrentUser() user: User,
  ) {
    const data = await this.paymentsService.createOrder(createPaymentDto, user.id);
    return { message: 'Payment order created successfully', data };
  }

  @Post('verify')
  @Roles(UserRole.USER)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify payment and confirm booking (User only)' })
  async verifyPayment(@Body() verifyDto: VerifyPaymentDto, @CurrentUser() user: User) {
    const data = await this.paymentsService.verifyPayment(verifyDto, user.id);
    return { message: 'Payment verified and booking confirmed', data };
  }

  @Get()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get all payments (Admin only)' })
  @ApiQuery({ name: 'status', enum: PaymentStatus, required: false })
  async findAll(@Query() pagination: PaginationDto, @Query('status') status?: PaymentStatus) {
    const [payments, total] = await this.paymentsService.findAll(pagination, status);
    return {
      message: 'Payments fetched successfully',
      data: {
        items: payments,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Get('my-payments')
  @Roles(UserRole.USER)
  @ApiOperation({ summary: "Get current user's payment history" })
  async getMyPayments(@Query() pagination: PaginationDto, @CurrentUser() user: User) {
    const [payments, total] = await this.paymentsService.findByUser(user.id, pagination);
    return {
      message: 'Payment history fetched successfully',
      data: {
        items: payments,
        total,
        page: pagination.page,
        limit: pagination.limit,
        totalPages: Math.ceil(total / pagination.limit),
      },
    };
  }

  @Get('stats/revenue')
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Get revenue statistics (Admin only)' })
  async getRevenueStats() {
    const data = await this.paymentsService.getRevenueStats();
    return { message: 'Revenue stats fetched successfully', data };
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get payment by ID' })
  async findOne(@Param('id', ParseUUIDPipe) id: string) {
    const data = await this.paymentsService.findOne(id);
    return { message: 'Payment fetched successfully', data };
  }
}
