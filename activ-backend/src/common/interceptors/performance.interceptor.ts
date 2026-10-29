import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { Observable, tap } from 'rxjs';

/** Opt-in request timing. Set PERF_LOGGING=true in a development environment. */
@Injectable()
export class PerformanceInterceptor implements NestInterceptor {
  private readonly logger = new Logger('ACTIV_PERF');

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (process.env.PERF_LOGGING !== 'true') return next.handle();
    const request = context.switchToHttp().getRequest<Request>();
    const response = context.switchToHttp().getResponse<Response>();
    const timing = response.locals.activPerf as { id: string; started: bigint } | undefined;
    const id = timing?.id || request.header('x-request-id') || 'api-unknown';
    const started = timing?.started || process.hrtime.bigint();
    const method = request.method;
    const route = request.route?.path || request.path;
    this.logger.log(`event=request_controller_start id=${id} method=${method} route=${route}`);
    return next.handle().pipe(tap({
      next: () => this.finish(id, method, route, response, started, 'success'),
      error: (error: unknown) => this.finish(
        id, method, route, response, started,
        `error_${error instanceof Error ? error.name : 'unknown'}`,
      ),
    }));
  }

  private finish(id: string, method: string, route: string, response: Response,
      started: bigint, outcome: string): void {
    const durationMs = Number(process.hrtime.bigint() - started) / 1e6;
    const length = response.getHeader('content-length');
    const bytes = typeof length === 'string' || typeof length === 'number'
        ? Number(length) : undefined;
    this.logger.log([
      'event=request_end', `id=${id}`, `method=${method}`, `route=${route}`,
      `duration_ms=${durationMs.toFixed(1)}`, `status=${response.statusCode}`,
      `outcome=${outcome}`, ...(bytes == null ? [] : [`response_bytes=${bytes}`]),
    ].join(' '));
  }
}
