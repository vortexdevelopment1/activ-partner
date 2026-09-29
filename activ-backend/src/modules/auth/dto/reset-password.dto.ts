import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString, Matches, MinLength } from 'class-validator';

export class ResetPasswordDto {
  @ApiProperty({ example: 'partner@example.com', description: 'Partner account email' })
  @IsEmail()
  @IsNotEmpty()
  email: string;

  @ApiProperty({ example: '3210', description: 'Reset code received via email' })
  @IsString()
  @IsNotEmpty()
  @Matches(/^\d{4,6}$/, { message: 'Code must be 4 to 6 digits' })
  code: string;

  @ApiProperty({ example: 'NewPassword123!', description: 'New password' })
  @IsString()
  @MinLength(6)
  newPassword: string;
}
