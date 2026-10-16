import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AuditLogsController } from './audit-logs.controller';

describe('AuditLogsController access', () => {
  const guard = new RolesGuard(new Reflector());
  const context = (role: string) => ({
    getHandler: () => AuditLogsController.prototype.findAll,
    getClass: () => AuditLogsController,
    switchToHttp: () => ({ getRequest: () => ({ user: { role } }) }),
  }) as unknown as ExecutionContext;

  it('allows admins to read logs', () => {
    expect(guard.canActivate(context('admin'))).toBe(true);
  });

  it('rejects partners and regular users', () => {
    expect(() => guard.canActivate(context('partner'))).toThrow(ForbiddenException);
    expect(() => guard.canActivate(context('user'))).toThrow(ForbiddenException);
  });
});
