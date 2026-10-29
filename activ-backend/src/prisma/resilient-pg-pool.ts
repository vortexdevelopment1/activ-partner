import { Pool, PoolClient } from 'pg';
import { Logger } from '@nestjs/common';

const connectionCodes = new Set([
  'ECONNRESET', 'ECONNREFUSED', 'EPIPE', 'ETIMEDOUT',
  '08000', '08001', '08003', '08006', '57P01', '57P02', '57P03',
  'P1001', 'P1002', 'P1017',
]);

export function isDatabaseConnectionError(error: unknown, depth = 0): boolean {
  if (!error || typeof error !== 'object' || depth > 4) return false;
  const value = error as Record<string, unknown>;
  if (['ConnectionClosed', 'DatabaseNotReachable', 'SocketTimeout'].includes(String(value.kind))) return true;
  if (connectionCodes.has(String(value.code ?? value.originalCode ?? ''))) return true;
  if (typeof value.message === 'string' &&
      /^(?:Connection terminated unexpectedly|Connection terminated|Connection closed|server closed the connection unexpectedly)$/i.test(value.message.trim())) return true;
  return ['cause', 'meta', 'driverAdapterError'].some(key => isDatabaseConnectionError(value[key], depth + 1));
}

type CheckoutCallback = (error: Error | undefined, client: PoolClient | undefined, release: (error?: any) => void) => void;

/** Verify pooled sockets before giving them to Prisma. Never replay application SQL. */
export class ResilientPgPool extends Pool {
  private readonly checkedAt = new WeakMap<PoolClient, number>();
  private readonly instrumentedClients = new WeakSet<PoolClient>();
  private readonly perfLogger = new Logger('ACTIV_PERF');
  connect(): Promise<PoolClient>;
  connect(callback: CheckoutCallback): void;
  connect(callback?: CheckoutCallback): Promise<PoolClient> | void {
    const checkout = this.checkoutHealthyClient();
    if (!callback) return checkout;
    void checkout.then(
      client => callback(undefined, client, client.release.bind(client)),
      error => callback(error, undefined, () => {}),
    );
  }

  private async checkoutHealthyClient(): Promise<PoolClient> {
    for (let attempt = 0; ; attempt++) {
      let client: PoolClient | undefined;
      const checkoutStarted = process.hrtime.bigint();
      try {
        client = await super.connect();
        this.instrumentClient(client);
        this.logTiming('db_pool_checkout', checkoutStarted, {
          attempt, total: this.totalCount, idle: this.idleCount, waiting: this.waitingCount,
        });
        // Avoid adding a network round trip to every query on a busy connection.
        if (Date.now() - (this.checkedAt.get(client) ?? 0) >= 5000) {
          const probe = { text: 'SELECT 1', query_timeout: 5000 };
          const healthStarted = process.hrtime.bigint();
          await client.query(probe);
          this.checkedAt.set(client, Date.now());
          this.logTiming('db_health_check', healthStarted, { attempt });
        }
        return client;
      } catch (error) {
        // Destroy failed sockets rather than returning them to the idle pool.
        client?.release(true);
        const failure = error instanceof Error && error.message === 'Query read timeout'
          ? Object.assign(new Error('Database connection health check timed out'), { code: 'ETIMEDOUT' })
          : error;
        if (attempt !== 0 || this.ending || !isDatabaseConnectionError(failure)) throw failure;
        await new Promise(resolve => setTimeout(resolve, 250));
      }
    }
  }

  private logTiming(event: string, started: bigint, fields: Record<string, number>): void {
    if (process.env.PERF_LOGGING !== 'true') return;
    const durationMs = Number(process.hrtime.bigint() - started) / 1e6;
    this.perfLogger.log([
      `event=${event}`, `duration_ms=${durationMs.toFixed(1)}`,
      ...Object.entries(fields).map(([key, value]) => `${key}=${value}`),
    ].join(' '));
  }

  private instrumentClient(client: PoolClient): void {
    if (process.env.PERF_LOGGING !== 'true' || this.instrumentedClients.has(client)) return;
    this.instrumentedClients.add(client);
    const originalQuery = client.query.bind(client) as (...args: any[]) => any;
    client.query = ((...args: any[]) => {
      const started = process.hrtime.bigint();
      const result = originalQuery(...args);
      if (!result || typeof result.then !== 'function') return result;
      return result.then(
        (value: unknown) => {
          this.logTiming('db_query', started, { success: 1 });
          return value;
        },
        (error: unknown) => {
          this.logTiming('db_query_error', started, { success: 0 });
          throw error;
        },
      );
    }) as PoolClient['query'];
  }
}
