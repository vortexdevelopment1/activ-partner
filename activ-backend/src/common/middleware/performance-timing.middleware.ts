import { Injectable, NestMiddleware } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Request, Response, NextFunction } from 'express';

@Injectable()
export class PerformanceTimingMiddleware implements NestMiddleware {
  use(request: Request, response: Response, next: NextFunction): void {
    if (process.env.PERF_LOGGING === 'true') {
      const id = request.header('x-request-id') || `api-${randomUUID()}`;
      response.locals.activPerf = { id, started: process.hrtime.bigint() };
      response.setHeader('x-request-id', id);
    }
    next();
  }
}
