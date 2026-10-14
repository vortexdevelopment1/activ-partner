import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional, IsString } from 'class-validator';
import { CallbackStatus } from '../../../common/enums/callback-status.enum';

export class UpdateCallbackRequestDto {
  @ApiPropertyOptional({ enum: CallbackStatus })
  @IsOptional()
  @IsEnum(CallbackStatus)
  status?: CallbackStatus;

  @ApiPropertyOptional({ example: 'Called and resolved the issue.' })
  @IsOptional()
  @IsString()
  adminNotes?: string;
}
