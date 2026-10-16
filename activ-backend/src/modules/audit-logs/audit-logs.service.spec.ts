import { AuditLogsService } from './audit-logs.service';

describe('AuditLogsService', () => {
  it('lists newest events with actor labels and pagination', async () => {
    const created = new Date('2026-10-16T09:00:00Z');
    const findMany = jest.fn().mockResolvedValue([{ id: 'event-1', action: 'PATCH /venues/:id',
      entity_type: 'venues', entity_id: 'venue-1', after_json: { outcome: 'success', privateDocument: 'hidden' },
      created_at: created, users: { name: 'Admin Name', email: null, phone_e164: null } }]);
    const count = jest.fn().mockResolvedValue(26);
    const service = new AuditLogsService({ audit_events: { findMany, count } } as any);
    const result = await service.findAll({ page: 2, limit: 25, resource: 'venues', outcome: 'success',
      search: 'Admin', from: '2026-10-15T18:30:00.000Z', to: '2026-10-16T18:30:00.000Z' });
    expect(findMany).toHaveBeenCalledWith(expect.objectContaining({
      skip: 25, take: 25, orderBy: [{ created_at: 'desc' }, { id: 'desc' }],
      where: expect.objectContaining({ entity_type: 'venues',
        OR: expect.arrayContaining([{ action: 'legal_content.published' }]),
        AND: expect.arrayContaining([{ OR: expect.arrayContaining([
          { users: { is: { phone_e164: { contains: 'Admin' } } } },
        ]) }]),
        created_at: { gte: new Date('2026-10-15T18:30:00.000Z'), lt: new Date('2026-10-16T18:30:00.000Z') },
      }),
    }));
    expect(result).toMatchObject({ total: 26, page: 2, totalPages: 2,
      items: [{ actor: 'Admin Name', resource: 'venues', targetId: 'venue-1', details: { outcome: 'success', statusCode: null } }] });
    expect(JSON.stringify(result)).not.toContain('hidden');
  });

  it('lists resources present in the audit table', async () => {
    const groupBy = jest.fn().mockResolvedValue([{ entity_type: 'venues' }, { entity_type: 'partners' }]);
    const service = new AuditLogsService({ audit_events: { groupBy } } as any);
    expect(await service.resources()).toEqual(['partners', 'venues']);
    expect(groupBy).toHaveBeenCalledWith({ by: ['entity_type'] });
  });
});
