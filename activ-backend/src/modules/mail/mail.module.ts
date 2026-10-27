import { Module, Global } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { MailService } from './mail.service';
import { GoogleOAuthService } from './google-oauth.service';
import { PartnerEmailService } from './partner-email.service';
import { PrismaModule } from '../../prisma/prisma.module';

@Global()
@Module({
  imports: [ConfigModule, PrismaModule],
  providers: [MailService, GoogleOAuthService, PartnerEmailService],
  exports: [MailService, GoogleOAuthService, PartnerEmailService],
})
export class MailModule {}
