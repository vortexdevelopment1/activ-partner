import { IsDateString, IsIn, IsNotEmpty, IsNumber, IsOptional, IsString, IsUUID, MaxLength, Min } from 'class-validator';

export class RecordPayoutDto {
  @IsUUID()
  partnerId: string;

  @IsOptional()
  @IsUUID()
  bankAccountId?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  reference: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  amount: number;

  @IsIn(['pending', 'success', 'failed'])
  status: 'pending' | 'success' | 'failed';

  @IsDateString({ strict: true })
  payoutDate: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  failureReason?: string;
}
