import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: 'john@example.com', description: 'Email address or phone number' })
  @IsNotEmpty()
  email: string;

  @ApiProperty({ example: 'Password@123' })
  @IsNotEmpty()
  @IsString()
  password: string;
}
