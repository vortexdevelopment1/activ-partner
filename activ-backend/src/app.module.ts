import { MiddlewareConsumer, Module, NestModule, RequestMethod } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD, APP_INTERCEPTOR, APP_FILTER } from '@nestjs/core';
import * as path from 'path';

import { isProductionEnvironment } from './config/environment';
import { PrismaModule } from './prisma/prisma.module';
import { CloudinaryModule } from './modules/cloudinary/cloudinary.module';
import { MailModule } from './modules/mail/mail.module';
import { OtpModule } from './modules/otp/otp.module';
import { PushNotificationsModule } from './modules/push-notifications/push-notifications.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { PartnersModule } from './modules/partners/partners.module';
import { CategoriesModule } from './modules/categories/categories.module';
import { QuestionsModule } from './modules/questions/questions.module';
import { VenuesModule } from './modules/venues/venues.module';
import { BookingsModule } from './modules/bookings/bookings.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { CommissionModule } from './modules/commission/commission.module';
import { LegalModule } from './modules/legal/legal.module';
import { LocationModule } from './modules/location/location.module';
import { TeamModule } from './modules/team/team.module';
import { BankAccountsModule } from './modules/bank-accounts/bank-accounts.module';
import { SupportModule } from './modules/support/support.module';
import { FaqModule } from './modules/faq/faq.module';
import { PayoutsModule } from './modules/payouts/payouts.module';
import { NotificationPreferencesModule } from './modules/notification-preferences/notification-preferences.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { AdminNotificationsModule } from './modules/admin-notifications/admin-notifications.module';
import { ReviewsModule } from './modules/reviews/reviews.module';
import { AmenitiesModule } from './modules/amenities/amenities.module';
import { AuditLogsModule } from './modules/audit-logs/audit-logs.module';
import { AdminSearchModule } from './modules/admin-search/admin-search.module';

import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { ResponseInterceptor } from './common/interceptors/response.interceptor';
import { AuditLogInterceptor } from './common/interceptors/audit-log.interceptor';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { PerformanceInterceptor } from './common/interceptors/performance.interceptor';
import { PerformanceTimingMiddleware } from './common/middleware/performance-timing.middleware';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      ignoreEnvFile: isProductionEnvironment(process.env),
      envFilePath: [
        path.resolve(__dirname, '..', '.env.local'),
        path.resolve(__dirname, '..', '.env'),
        '.env.local',
        '.env',
      ],
    }),
    PrismaModule,
    CloudinaryModule,
    MailModule,
    OtpModule,
    PushNotificationsModule,
    AuthModule,
    UsersModule,
    PartnersModule,
    CategoriesModule,
    QuestionsModule,
    VenuesModule,
    BookingsModule,
    PaymentsModule,
    CommissionModule,
    LegalModule,
    LocationModule,
    TeamModule,
    BankAccountsModule,
    SupportModule,
    FaqModule,
    PayoutsModule,
    NotificationPreferencesModule,
    NotificationsModule,
    AdminNotificationsModule,
    ReviewsModule,
    AmenitiesModule,
    AuditLogsModule,
    AdminSearchModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
    {
      provide: APP_GUARD,
      useClass: RolesGuard,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: ResponseInterceptor,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: AuditLogInterceptor,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: PerformanceInterceptor,
    },
    {
      provide: APP_FILTER,
      useClass: HttpExceptionFilter,
    },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(PerformanceTimingMiddleware)
      .forRoutes({ path: '*', method: RequestMethod.ALL });
  }
}
