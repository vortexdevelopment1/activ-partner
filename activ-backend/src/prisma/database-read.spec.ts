import { ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { databaseRead, isDatabaseConnectionError } from './database-read';

describe('read-only database connection recovery', () => {
  it('retries a transient connection loss once', async () => {
    const read = jest.fn().mockRejectedValueOnce(new Error('Connection terminated unexpectedly'))
      .mockResolvedValue({ id: 'partner' });
    await expect(databaseRead(read)).resolves.toEqual({ id: 'partner' });
    expect(read).toHaveBeenCalledTimes(2);
  });

  it('returns 503 when the database remains unavailable', async () => {
    const read = jest.fn().mockRejectedValue({ code: 'P1001' });
    await expect(databaseRead(read)).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(read).toHaveBeenCalledTimes(2);
  });

  it('does not retry invalid credentials or database constraints', async () => {
    for (const error of [new UnauthorizedException(), { code: 'P2002' }, { code: 'P2025' }]) {
      const read = jest.fn().mockRejectedValue(error);
      await expect(databaseRead(read)).rejects.toBe(error);
      expect(read).toHaveBeenCalledTimes(1);
    }
  });

  it('recognizes wrapped adapter network errors but not certificate validation failures', () => {
    expect(isDatabaseConnectionError({ code: 'P2010', meta: { driverAdapterError: {
      cause: { code: 'ECONNRESET' },
    } } })).toBe(true);
    expect(isDatabaseConnectionError(new Error('Client network socket disconnected before secure TLS connection was established'))).toBe(true);
    expect(isDatabaseConnectionError({ code: 'DEPTH_ZERO_SELF_SIGNED_CERT' })).toBe(false);
  });
});
