import { ExecutionContext, HttpException, HttpStatus } from '@nestjs/common';
import { of, throwError } from 'rxjs';
import { AuditLogInterceptor } from './audit-log.interceptor';

describe('AuditLogInterceptor', () => {
  const create = jest.fn().mockResolvedValue({});
  const interceptor = new AuditLogInterceptor({ audit_events: { create } } as any);
  const context = (request: any) => ({
    switchToHttp: () => ({
      getRequest: () => request,
      getResponse: () => ({ statusCode: 201 }),
    }),
  }) as ExecutionContext;

  beforeEach(() => create.mockClear());

  it('records an authenticated change without its body or query values', async () => {
    const request = {
      method: 'POST', baseUrl: '', route: { path: '/api/v1/venues/admin/create' },
      user: { id: 'admin-id', role: 'admin' }, params: {},
      body: { password: 'secret' }, query: { token: 'private' },
    };
    await new Promise<void>((resolve) => interceptor.intercept(context(request), { handle: () => of({ data: { id: 'venue-id' } }) }).subscribe({ complete: resolve }));
    expect(create).toHaveBeenCalledWith({ data: expect.objectContaining({
      actor_id: 'admin-id', action: 'POST /api/v1/venues/admin/create', entity_type: 'venues', entity_id: 'venue-id',
      after_json: { outcome: 'success', statusCode: 201 },
    }) });
    expect(JSON.stringify(create.mock.calls[0][0])).not.toMatch(/secret|private/);
  });

  it('uses the user ID behind a partner JWT and records failed actions', async () => {
    const request = {
      method: 'PATCH', baseUrl: '', route: { path: '/api/v1/venues/:id' },
      user: { id: 'partner-id', userId: 'owner-id', role: 'partner' }, params: { id: 'venue-id' },
    };
    await new Promise<void>((resolve) => interceptor.intercept(context(request), {
      handle: () => throwError(() => new HttpException('Bad data', HttpStatus.BAD_REQUEST)),
    }).subscribe({ error: () => resolve() }));
    expect(create).toHaveBeenCalledWith({ data: expect.objectContaining({
      actor_id: 'owner-id', entity_id: 'venue-id', after_json: { outcome: 'failed', statusCode: 400 },
    }) });
  });

  it('does not record reads or unauthenticated requests', async () => {
    for (const request of [{ method: 'GET', user: { id: 'admin-id' } }, { method: 'POST' }]) {
      await new Promise<void>((resolve) => interceptor.intercept(context(request), { handle: () => of(null) }).subscribe({ complete: resolve }));
    }
    expect(create).not.toHaveBeenCalled();
  });

  it('does not break the action when logging fails', async () => {
    create.mockRejectedValueOnce(new Error('database unavailable'));
    const request = { method: 'POST', route: { path: '/api/v1/venues' }, user: { id: 'admin-id' }, params: {} };
    await expect(new Promise((resolve, reject) => interceptor.intercept(context(request), {
      handle: () => of('saved'),
    }).subscribe({ next: resolve, error: reject }))).resolves.toBe('saved');
  });
});
