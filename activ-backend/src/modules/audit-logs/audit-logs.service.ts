import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export interface AuditLogFilters {
  page: number;
  limit: number;
  search?: string;
  resource?: string;
  outcome?: 'success' | 'failed';
}

@Injectable()
export class AuditLogsService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(filters: AuditLogFilters) {
    const where: any = {};
    if (filters.resource) where.entity_type = filters.resource;
    if (filters.outcome) {
      where.after_json = { path: ['outcome'], equals: filters.outcome };
    }
    if (filters.search) {
      where.OR = [
        { action: { contains: filters.search, mode: 'insensitive' } },
        { entity_type: { contains: filters.search, mode: 'insensitive' } },
        { entity_id: { contains: filters.search, mode: 'insensitive' } },
        { users: { is: { name: { contains: filters.search, mode: 'insensitive' } } } },
        { users: { is: { email: { contains: filters.search, mode: 'insensitive' } } } },
      ];
    }

    const [records, total] = await Promise.all([
      this.prisma.audit_events.findMany({
        where,
        include: { users: { select: { name: true, email: true, phone_e164: true } } },
        orderBy: [{ created_at: 'desc' }, { id: 'desc' }],
        skip: (filters.page - 1) * filters.limit,
        take: filters.limit,
      }),
      this.prisma.audit_events.count({ where }),
    ]);

    return {
      items: records.map((record) => {
        const metadata = record.after_json && typeof record.after_json === 'object' && !Array.isArray(record.after_json)
          ? record.after_json as Record<string, unknown> : {};
        return {
          id: record.id,
          action: record.action,
          resource: record.entity_type,
          targetId: record.entity_id,
          actor: record.users?.name?.trim() || record.users?.email || record.users?.phone_e164 || null,
          details: {
            outcome: metadata.outcome === 'failed' ? 'failed' : 'success',
            statusCode: typeof metadata.statusCode === 'number' ? metadata.statusCode : null,
          },
          createdAt: record.created_at,
        };
      }),
      total,
      page: filters.page,
      limit: filters.limit,
      totalPages: Math.ceil(total / filters.limit),
    };
  }
}
