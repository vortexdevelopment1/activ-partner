import { Module, Global } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { MailService } from './mail.service';
import { GoogleOAuthService } from './google-oauth.service';
import { PartnerEmailService } from './partner-email.service';
import { PrismaModule } from '../../prisma/prisma.module';
import { EmailDeliveryService } from './email-delivery.service';
import { EmailDeliveriesController } from './email-deliveries.controller';
import { GoogleCredentialStore } from './google-credential.store';

@Global()
@Module({
  imports: [ConfigModule, PrismaModule],
  controllers: [EmailDeliveriesController],
  providers: [MailService, GoogleOAuthService, GoogleCredentialStore, PartnerEmailService, EmailDeliveryService],
  exports: [MailService, GoogleOAuthService, PartnerEmailService],
})
export class MailModule {}
