import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { BaseExceptionFilter, HttpAdapterHost } from '@nestjs/core';
import { isDatabaseConnectionError } from '../../prisma/resilient-pg-pool';

@Catch()
export class HttpExceptionFilter extends BaseExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  constructor(adapterHost: HttpAdapterHost) {
    super(adapterHost.httpAdapter);
  }

  catch(exception: unknown, host: ArgumentsHost) {
    if (!(exception instanceof HttpException)) {
      if (!isDatabaseConnectionError(exception)) return super.catch(exception, host);
      const response = host.switchToHttp().getResponse<Response>();
      this.logger.warn('Database connection was interrupted while handling a request.');
      response.setHeader('Retry-After', '1');
      response.status(HttpStatus.SERVICE_UNAVAILABLE).json({
        success: false,
        statusCode: HttpStatus.SERVICE_UNAVAILABLE,
        message: 'The database connection was interrupted. Please refresh to check the latest status before trying again.',
        timestamp: new Date().toISOString(),
      });
      return;
    }
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const status = exception.getStatus();
    const exceptionResponse = exception.getResponse();

    const error =
      typeof exceptionResponse === 'string'
        ? { message: exceptionResponse }
        : (exceptionResponse as object);

    this.logger.error(
      `${request.method} ${request.url} ${status}`,
      JSON.stringify(error),
    );

    response.status(status).json({
      success: false,
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      ...error,
    });
  }
}
