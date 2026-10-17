import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional } from 'class-validator';
import { PaginationDto } from '../../../common/dto/pagination.dto';
import { CallbackStatus } from '../../../common/enums/callback-status.enum';

export class CallbackQueryDto extends PaginationDto {
  @ApiPropertyOptional({ enum: CallbackStatus })
  @IsOptional()
  @IsEnum(CallbackStatus)
  status?: CallbackStatus;
}
