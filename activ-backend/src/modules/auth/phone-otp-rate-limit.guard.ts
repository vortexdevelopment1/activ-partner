import { CanActivate, ExecutionContext, HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { createHash, randomUUID } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';

/** Shared PostgreSQL counters: no process-local limits or new persistence system. */
@Injectable()
export class PhoneOtpRateLimitGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const verify = context.getHandler().name === 'verifyOtp';
    const digits = typeof request.body?.phone === 'string' ? request.body.phone.replace(/\D/g, '') : '';
    const phone = digits.length === 10 ? `91${digits}` : digits;
    const action = verify ? 'verify' : 'send';
    // req.ip uses Express's configured proxy trust. Never read forwarded headers directly.
    const budgets: [string, number][] = [[`ip:${request.ip || request.socket?.remoteAddress || 'unknown'}`, verify ? 90 : 30]];
    if (phone) budgets.push([`phone:${phone}`, verify ? 15 : 6]);

    for (const [identity, limit] of budgets) {
      const key = `otp-rate:${action}:${createHash('sha256').update(identity).digest('hex')}`;
      const allowed = await this.prisma.$transaction(async tx => {
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${key}, 0))`;
        const now = new Date();
        const counter = await tx.otp_challenges.findFirst({
          where: { phone_e164: key, expires_at: { gt: now } }, orderBy: { created_at: 'desc' },
        });
        if (counter) {
          if (counter.attempts >= limit) return false;
          await tx.otp_challenges.update({ where: { id: counter.id }, data: { attempts: { increment: 1 } } });
        } else {
          await tx.otp_challenges.create({ data: {
            id: randomUUID(), phone_e164: key, code_hash: 'rate-limit', attempts: 1,
            expires_at: new Date(now.getTime() + 10 * 60_000),
          } });
        }
        return true;
      });
      if (!allowed) {
        request.res?.setHeader('Retry-After', '600');
        throw new HttpException('Too many OTP requests. Please try again later.', HttpStatus.TOO_MANY_REQUESTS);
      }
    }
    return true;
  }
}
