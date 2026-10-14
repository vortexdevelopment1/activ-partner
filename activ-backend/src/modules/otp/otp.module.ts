import { Module, Global } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { OtpService } from './otp.service';

@Global()
@Module({
  imports: [ConfigModule],
  providers: [OtpService],
  exports: [OtpService],
})
export class OtpModule {}
