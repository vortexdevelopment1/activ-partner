import { Pool, PoolClient } from 'pg';

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
      try {
        client = await super.connect();
        // Avoid adding a network round trip to every query on a busy connection.
        if (Date.now() - (this.checkedAt.get(client) ?? 0) >= 5000) {
          const probe = { text: 'SELECT 1', query_timeout: 5000 };
          await client.query(probe);
          this.checkedAt.set(client, Date.now());
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
}
