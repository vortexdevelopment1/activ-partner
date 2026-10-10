import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { PayoutsService } from './payouts.service';
import { PayoutQueryDto } from './dto/payout-query.dto';
import { RecordPayoutDto } from './dto/record-payout.dto';

@ApiTags('payouts')
@ApiBearerAuth()
@Controller('payouts')
export class PayoutsController {
  constructor(private readonly payoutsService: PayoutsService) {}

  @Get('my')
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Get own database payout history with date and status filters' })
  async history(@CurrentUser() partner: any, @Query() query: PayoutQueryDto) {
    return { message: 'Payout history fetched', data: await this.payoutsService.history(partner.id, query) };
  }

  @Get('download')
  @Roles(UserRole.PARTNER)
  @ApiOperation({ summary: 'Export own filtered payout records as a base64 PDF or CSV' })
  async download(@CurrentUser() partner: any, @Query() query: PayoutQueryDto) {
    return { message: 'Payout report generated', data: await this.payoutsService.generateExport(partner.id, query) };
  }

  @Post()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Record a payout outcome; does not initiate a money transfer' })
  async record(@Body() dto: RecordPayoutDto) {
    return { message: 'Payout recorded', data: await this.payoutsService.record(dto) };
  }
}
