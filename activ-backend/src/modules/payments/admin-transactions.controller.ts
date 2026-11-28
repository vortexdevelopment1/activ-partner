import { Controller, Get, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { AdminTransactionsQuery, AdminTransactionsService } from './admin-transactions.service';

@ApiTags('Transactions')
@ApiBearerAuth()
@Roles(UserRole.ADMIN)
@Controller('admin/transactions')
export class AdminTransactionsController {
  constructor(private readonly transactions: AdminTransactionsService) {}

  @Get()
  @ApiOperation({ summary: 'List booking payments, refunds, commission estimates or recorded payouts' })
  async list(@Query() query: AdminTransactionsQuery) {
    return { data: await this.transactions.list(query) };
  }
}
