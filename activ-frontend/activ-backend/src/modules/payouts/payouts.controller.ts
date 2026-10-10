import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';

import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { PayoutsService } from './payouts.service';

@ApiTags('payouts')
@Controller('payouts')
export class PayoutsController {
  constructor(private readonly payoutsService: PayoutsService) {}

  /**
   * Returns a base64-encoded PDF or CSV so the mobile app can decode and
   * save/open the file locally without a separate file-download stream.
   *
   * Response shape:
   *   { base64: string, filename: string, mimeType: string }
   */
  @Get('download')
  @Roles(UserRole.PARTNER)
  @ApiOperation({
    summary: 'Download payout history as PDF or CSV (base64)',
    description:
      'Returns a base64-encoded file. Mobile apps should decode the base64 ' +
      'string and write it to the local file system, then open with the device viewer.',
  })
  @ApiQuery({ name: 'format',    enum: ['pdf', 'csv'], required: false, description: 'Export format (default: pdf)' })
  @ApiQuery({ name: 'startDate', required: false, description: 'Period start date (YYYY-MM-DD)' })
  @ApiQuery({ name: 'endDate',   required: false, description: 'Period end date (YYYY-MM-DD)' })
  async downloadPayout(
    @Query('format')    format: 'pdf' | 'csv' = 'pdf',
    @Query('startDate') startDate: string = '',
    @Query('endDate')   endDate: string = '',
    @CurrentUser() partner: any,
  ) {
    const partnerName =
      partner?.businessName ||
      [partner?.firstName, partner?.lastName].filter(Boolean).join(' ') ||
      'Venue Partner';

    const fmtPeriodDate = (iso: string) => {
      if (!iso) return '';
      const [y, m, d] = iso.split('-');
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return `${parseInt(d)} ${months[parseInt(m) - 1]} ${y}`;
    };

    const periodStart = fmtPeriodDate(startDate) || '01 May 2026';
    const periodEnd   = fmtPeriodDate(endDate)   || '31 May 2026';

    const data = await this.payoutsService.generateExport(format, partnerName, periodStart, periodEnd);
    return { message: 'Payout export generated successfully', data };
  }
}
