import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional, IsString } from 'class-validator';
import { CallbackStatus } from '../../../common/enums/callback-status.enum';

export class UpdateSupportEmailDto {
  @ApiPropertyOptional({ enum: CallbackStatus })
  @IsOptional()
  @IsEnum(CallbackStatus)
  status?: CallbackStatus;

  @ApiPropertyOptional({ example: 'Reviewed and resolved.' })
  @IsOptional()
  @IsString()
  adminNotes?: string;
}
