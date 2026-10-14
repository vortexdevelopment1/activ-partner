import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
  MinLength,
  Matches,
} from 'class-validator';

export class RegisterPartnerDto {
  @ApiProperty({ example: 'Jane' })
  @IsNotEmpty()
  @IsString()
  firstName: string;

  @ApiProperty({ example: 'Smith' })
  @IsNotEmpty()
  @IsString()
  lastName: string;

  @ApiProperty({ example: 'jane@example.com' })
  @IsNotEmpty()
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'Password@123', minLength: 8 })
  @IsNotEmpty()
  @IsString()
  @MinLength(8)
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/, {
    message: 'Password must contain uppercase, lowercase, number and special character',
  })
  password: string;

  @ApiProperty({ example: '+911234567890' })
  @IsNotEmpty()
  @IsString()
  phone: string;

  @ApiProperty({ example: 'Sports Arena Pvt Ltd' })
  @IsNotEmpty()
  @IsString()
  businessName: string;

  @ApiPropertyOptional({ example: 'Premium sports venue provider' })
  @IsOptional()
  @IsString()
  businessDescription?: string;

  @ApiProperty({ example: '123 MG Road' })
  @IsNotEmpty()
  @IsString()
  businessAddress: string;

  @ApiProperty({ example: 'Bengaluru' })
  @IsNotEmpty()
  @IsString()
  city: string;

  @ApiProperty({ example: 'Karnataka' })
  @IsNotEmpty()
  @IsString()
  state: string;

  @ApiPropertyOptional({ example: '560001' })
  @IsOptional()
  @IsString()
  zipCode?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  deviceToken?: string;
}
