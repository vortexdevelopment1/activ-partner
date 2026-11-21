
import { NestFactory, Reflector } from '@nestjs/core';
import {
  ValidationPipe,
  ClassSerializerInterceptor,
} from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import * as path from 'path';
import * as express from 'express';
import { NestExpressApplication } from '@nestjs/platform-express';

async function bootstrap() {
  console.log('Starting ACTIV Partner backend...');

  const app = await NestFactory.create<NestExpressApplication>(
    AppModule,
  );

  const configService = app.get(ConfigService);

  // Render provides PORT automatically.
  const port = Number(
    process.env.PORT ?? configService.get('APP_PORT', 3000),
  );

  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`Invalid application port: ${port}`);
  }

  const host = '0.0.0.0';

  // Increase body size limit
  app.use(express.json({ limit: '50mb' }));
  app.use(
    express.urlencoded({
      limit: '50mb',
      extended: true,
    }),
  );

  // Enable CORS
  app.enableCors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: [
      'Content-Type',
      'Authorization',
      'X-Google-OAuth-Setup-Key',
    ],
    credentials: true,
  });

  // Global API prefix
  app.setGlobalPrefix('api/v1');

  // Serve uploaded files
  app.useStaticAssets(path.join(process.cwd(), 'uploads'), {
    prefix: '/uploads',
  });

  // Global validation
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

  // Global serializer
  app.useGlobalInterceptors(
    new ClassSerializerInterceptor(app.get(Reflector)),
  );

  // Swagger documentation
  const config = new DocumentBuilder()
    .setTitle('ActivProduct API')
    .setDescription(`
      ## ActivProduct Backend API

      ### Authentication
      Use the /auth/login endpoint to get a JWT token,
      then click Authorize and enter Bearer {your-token}.

      ### Roles
      - admin - Full access to all resources
      - partner - Manage venues, services and bookings
      - user - Browse venues, create bookings and payments

      ### Venue Approval Flow
      1. Partner creates venue - pending
      2. Admin approves or rejects venue
      3. Approved venues are visible to users
    `)
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

  // Start HTTP server
  console.log(`Attempting to bind to ${host}:${port}`);

  await app.listen(port, host);

  console.log('========================================');
  console.log('ACTIV Partner Backend Started');
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Listening on: ${host}:${port}`);
  console.log(`API: http://localhost:${port}/api/v1`);
  console.log(`Swagger: http://localhost:${port}/api/docs`);
  console.log('========================================');
}

// Catch startup failures
bootstrap().catch((error) => {
  console.error('========================================');
  console.error('ACTIV Partner Backend Startup Failed');
  console.error(error);
  console.error('========================================');
  process.exit(1);
});
