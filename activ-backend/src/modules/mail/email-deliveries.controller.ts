import { Body, Controller, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { IsBoolean, IsOptional } from 'class-validator';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { EmailDeliveryService } from './email-delivery.service';

class RetryEmailDto {
  @IsOptional() @IsBoolean() confirmUnknownOutcome?: boolean;
}

/** Global JWT and role guards protect these administrative recovery routes. */
@Controller('email-deliveries')
@Roles(UserRole.ADMIN)
export class EmailDeliveriesController {
  constructor(private readonly deliveries: EmailDeliveryService) {}

  @Get() list() { return this.deliveries.list(); }

  @Post(':id/retry')
  retry(@Param('id', ParseUUIDPipe) id: string, @Body() body: RetryEmailDto) {
    return this.deliveries.retry(id, body?.confirmUnknownOutcome === true);
  }
}
