import { NestFactory, Reflector } from '@nestjs/core';
import { ValidationPipe, ClassSerializerInterceptor } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import * as path from 'path';
import * as express from 'express';
import { NestExpressApplication } from '@nestjs/platform-express';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  const configService = app.get(ConfigService);
  const port = process.env.PORT || configService.get<number>('APP_PORT', 3000);

  // Increase body size limit for file uploads
  app.use(express.json({ limit: '50mb' }));
  app.use(express.urlencoded({ limit: '50mb', extended: true }));

  // Enable CORS
  app.enableCors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  });

  // Global prefix
  app.setGlobalPrefix('api/v1');

  // Serve static files (uploads)
  app.useStaticAssets(path.join(process.cwd(), 'uploads'), {
    prefix: '/uploads',
  });

  // Global pipes
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  // Class serializer for @Exclude()
  app.useGlobalInterceptors(new ClassSerializerInterceptor(app.get(Reflector)));

  // Swagger documentation
  const config = new DocumentBuilder()
    .setTitle('ActivProduct API')
    .setDescription(
      `
      ## ActivProduct Backend API

      ### Authentication
      Use the /auth/login endpoint to get a JWT token, then click **Authorize** and enter: **Bearer {your-token}**

      ### Roles
      - **admin** - Full access to all resources
      - **partner** - Can manage their venues, services, view their bookings
      - **user** - Can browse venues, create bookings, make payments

      ### Venue Approval Flow
      1. Partner creates a venue → status: **pending**
      2. Admin reviews and approves/rejects → status: **approved** or **rejected**
      3. Approved venues are visible to users
    `,
    )
    .setVersion('1.0')
    .addBearerAuth()
    .addTag('Authentication', 'Login, Register, Profile')
    .addTag('Users', 'User management (Admin)')
    .addTag('Partners', 'Partner management')
    .addTag('Categories', 'Venue categories (Admin)')
    .addTag('Questions', 'Venue creation questions (Admin)')
    .addTag('Venues', 'Venue management, approval flow')
    .addTag('Bookings', 'Booking management')
    .addTag('Payments', 'Payment processing')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document, {
    swaggerOptions: {
      persistAuthorization: true,
    },
  });

  await app.listen(port);

  console.log(`\n🚀 Application is running on: http://localhost:${port}/api/v1`);
  console.log(`📚 Swagger docs: http://localhost:${port}/api/docs\n`);
}

bootstrap();
