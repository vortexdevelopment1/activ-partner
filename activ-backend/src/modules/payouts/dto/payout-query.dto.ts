import { Type } from 'class-transformer';
import { IsDateString, IsIn, IsInt, IsOptional, Matches, Max, Min } from 'class-validator';

export class PayoutQueryDto {
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  @IsDateString({ strict: true })
  startDate?: string;

  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  @IsDateString({ strict: true })
  endDate?: string;

  @IsOptional()
  @IsIn(['all', 'success', 'pending', 'failed'])
  status: string = 'all';

  @IsOptional()
  @IsIn(['pdf', 'csv'])
  format: 'pdf' | 'csv' = 'pdf';

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit: number = 20;
}
