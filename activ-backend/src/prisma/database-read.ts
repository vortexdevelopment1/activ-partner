import { ServiceUnavailableException } from '@nestjs/common';

export function isDatabaseConnectionError(error: unknown, depth = 0): boolean {
  if (!error || typeof error !== 'object' || depth > 4) return false;
  const details = error as Record<string, unknown>;
  if (['P1001', 'P1002', 'P1017', 'ECONNRESET', 'ECONNREFUSED', 'ETIMEDOUT',
    'EPIPE', '08000', '08003', '08006', '57P01', '57P02', '57P03'].includes(String(details.code))) return true;
  if (typeof details.message === 'string' &&
    /Connection terminated unexpectedly|Connection terminated due to connection timeout|Client network socket disconnected before secure TLS connection was established/i.test(details.message)) return true;
  return ['cause', 'meta', 'driverAdapterError'].some((key) =>
    isDatabaseConnectionError(details[key], depth + 1));
}

// Only use for read-only work: a dropped connection can leave a write's outcome unknown.
export async function databaseRead<T>(read: () => Promise<T>): Promise<T> {
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      return await read();
    } catch (error) {
      if (!isDatabaseConnectionError(error)) throw error;
      if (attempt === 1) {
        throw new ServiceUnavailableException('Database connection is temporarily unavailable. Please try again.');
      }
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
  }
  throw new ServiceUnavailableException();
}
