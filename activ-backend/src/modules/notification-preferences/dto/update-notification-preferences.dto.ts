import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsOptional } from 'class-validator';

export class UpdateNotificationPreferencesDto {
  @ApiPropertyOptional({ description: 'Master toggle turns all notifications on/off', example: true })
  @IsOptional()
  @IsBoolean()
  enableAllNotifications?: boolean;

  @ApiPropertyOptional({ description: 'Alerts for new bookings, updates and cancellations', example: true })
  @IsOptional()
  @IsBoolean()
  bookingNotifications?: boolean;

  @ApiPropertyOptional({ description: 'Payment success, failure and refund alerts', example: false })
  @IsOptional()
  @IsBoolean()
  paymentUpdates?: boolean;

  @ApiPropertyOptional({ description: 'Activity and listing approval notifications', example: false })
  @IsOptional()
  @IsBoolean()
  approvalUpdates?: boolean;

  @ApiPropertyOptional({ description: 'Offers, trip and product promotional messages', example: false })
  @IsOptional()
  @IsBoolean()
  promotionalMessages?: boolean;
}
