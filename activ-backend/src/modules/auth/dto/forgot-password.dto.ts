import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty } from 'class-validator';

export class ForgotPasswordDto {
  @ApiProperty({ example: 'partner@example.com', description: 'Partner account email' })
  @IsEmail()
  @IsNotEmpty()
  email: string;
}
