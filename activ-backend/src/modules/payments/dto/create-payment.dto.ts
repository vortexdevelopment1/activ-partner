import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, IsUUID } from 'class-validator';

export class CreatePaymentOrderDto {
  @ApiProperty({ description: 'Booking ID to create payment for' })
  @IsNotEmpty()
  @IsUUID()
  bookingId: string;

  @ApiPropertyOptional({ example: 'upi' })
  @IsOptional()
  @IsString()
  paymentMethod?: string;
}

export class VerifyPaymentDto {
  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  razorpayOrderId: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  razorpayPaymentId: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  razorpaySignature: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsUUID()
  bookingId: string;
}
