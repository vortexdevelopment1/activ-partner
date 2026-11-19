import { PhoneOtpRateLimitGuard } from './phone-otp-rate-limit.guard';
import { AuthController } from './auth.controller';
import { TeamController } from '../team/team.controller';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Reflector } from '@nestjs/core';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { CreateTeamMemberDto } from '../team/dto/create-team-member.dto';

describe('phone OTP abuse limits', () => {
  let guard: PhoneOtpRateLimitGuard;
  let rows: any[];
  let prisma: any;
  const context = (handler = 'requestOtp', phone = '9876543210', ip = '127.0.0.1') => ({
    getHandler: () => AuthController.prototype[handler],
    switchToHttp: () => ({ getRequest: () => ({ body: { phone }, ip, res: { setHeader: jest.fn() } }) }),
  } as any);
  beforeEach(() => {
    rows = [];
    prisma = { $executeRaw: jest.fn(), otp_challenges: {
      findFirst: jest.fn(async ({ where }) => rows.find(row => row.phone_e164 === where.phone_e164 && row.expires_at > where.expires_at.gt)),
      create: jest.fn(async ({ data }) => rows.push(data)),
      update: jest.fn(async ({ where }) => rows.find(row => row.id === where.id).attempts++),
    } };
    prisma.$transaction = jest.fn(callback => callback(prisma));
    guard = new PhoneOtpRateLimitGuard(prisma);
  });
  it('limits phone sends across changing IPs and request/resend endpoints', async () => {
    for (let i = 0; i < 6; i++) await guard.canActivate(context(i % 2 ? 'resendOtp' : 'requestOtp', '9876543210', `ip-${i}`));
    await expect(guard.canActivate(context())).rejects.toMatchObject({ status: 429 });
    expect(JSON.stringify(rows)).not.toContain('9876543210');
  });
  it('limits IP sends across changing phone numbers', async () => {
    for (let i = 0; i < 30; i++) await guard.canActivate(context('requestOtp', `987654${String(i).padStart(4, '0')}`));
    await expect(guard.canActivate(context())).rejects.toMatchObject({ status: 429 });
  });
  it('limits phone verification independently of sends', async () => {
    for (let i = 0; i < 15; i++) await guard.canActivate(context('verifyOtp'));
    await expect(guard.canActivate(context('verifyOtp'))).rejects.toMatchObject({ status: 429 });
    await expect(guard.canActivate(context('requestOtp'))).resolves.toBe(true);
  });
  it('shares the phone budget between local and international representations', async () => {
    for (let i = 0; i < 6; i++) await guard.canActivate(context());
    await expect(guard.canActivate(context('resendOtp', '+919876543210'))).rejects.toMatchObject({ status: 429 });
  });
  it('allows requests after the counter window expires', async () => {
    for (let i = 0; i < 6; i++) await guard.canActivate(context());
    rows.forEach(row => row.expires_at = new Date(0));
    await expect(guard.canActivate(context())).resolves.toBe(true);
  });
  it.each(['requestOtp', 'verifyOtp', 'resendOtp'])('protects the live %s endpoint', handler => {
    expect(Reflect.getMetadata(GUARDS_METADATA, AuthController.prototype[handler])).toContain(PhoneOtpRateLimitGuard);
  });
  it.each(['create', 'findAll', 'update', 'remove', 'resendInvitation'])('keeps %s partner-only', handler => {
    const roles = new RolesGuard(new Reflector());
    const ctx = { getHandler: () => TeamController.prototype[handler], getClass: () => TeamController,
      switchToHttp: () => ({ getRequest: () => ({ user: { role: 'team_member' } }) }) } as any;
    expect(() => roles.canActivate(ctx)).toThrow('permission');
  });
  it.each([
    { fullName: '   ' }, { role: 'owner' }, { phone: 'invalid' },
    { permissions: { bookingManagement: 'true' } },
  ])('rejects invalid team details %#', invalid => {
    const dto = plainToInstance(CreateTeamMemberDto, {
      fullName: 'Test Member', phone: '+919876543210', role: 'manager', ...invalid,
    });
    expect(validateSync(dto).length).toBeGreaterThan(0);
  });
});
