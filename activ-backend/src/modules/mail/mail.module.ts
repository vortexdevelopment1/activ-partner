import { Module, Global } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { MailService } from './mail.service';
import { GoogleOAuthService } from './google-oauth.service';

@Global()
@Module({
  imports: [ConfigModule],
  providers: [MailService, GoogleOAuthService],
  exports: [MailService, GoogleOAuthService],
})
export class MailModule {}
