import { CallHandler, ExecutionContext, Injectable, Logger, NestInterceptor } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AuditLogInterceptor implements NestInterceptor {
  private readonly logger = new Logger(AuditLogInterceptor.name);

  constructor(private readonly prisma: PrismaService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest();
    if (!request || !['POST', 'PUT', 'PATCH', 'DELETE'].includes(request.method) || !request.user) {
      return next.handle();
    }

    const method: string = request.method;
    const path: string = `${request.baseUrl || ''}${request.route?.path || request.path}`;
    const segments = path.split('/').filter(Boolean).filter((part) => part !== 'api' && !/^v\d+$/.test(part));
    const resource = segments[0] === 'admin' ? segments[1] || 'admin' : segments[0] || 'system';
    const actorId = request.user.userId || (request.user.role === 'team_member' ? null : request.user.id);
    const write = (outcome: 'success' | 'failed', statusCode: number, result?: any) => {
      const targetId = request.params?.id || request.params?.venueId || request.params?.partnerId ||
        result?.data?.id || result?.data?.venueId || result?.id || '';
      void this.prisma.audit_events.create({
        data: {
          id: randomUUID(),
          actor_id: actorId,
          action: `${method} ${path}`,
          entity_type: resource,
          entity_id: typeof targetId === 'string' ? targetId : '',
          after_json: { outcome, statusCode },
        },
      }).catch((error) => this.logger.warn(`Could not record activity: ${error.message}`));
    };

    return next.handle().pipe(tap({
      next: (result) => write('success', context.switchToHttp().getResponse().statusCode, result),
      error: (error) => write('failed', typeof error.getStatus === 'function' ? error.getStatus() : 500),
    }));
  }
}
