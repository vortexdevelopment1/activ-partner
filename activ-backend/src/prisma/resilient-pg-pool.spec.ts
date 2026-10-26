import { Pool } from 'pg';
import { isDatabaseConnectionError, ResilientPgPool } from './resilient-pg-pool';

describe('database connection recovery', () => {
  const lost = () => new Error('Connection terminated unexpectedly');
  const client = () => ({ query: jest.fn().mockResolvedValue({ rows: [] }), release: jest.fn() });
  const connectSpy = () => jest.spyOn(Pool.prototype, 'connect') as unknown as jest.SpyInstance<Promise<any>, []>;
  afterEach(() => jest.restoreAllMocks());

  it('destroys a stale socket and checks a new connection before returning it', async () => {
    const stale = client(), healthy = client();
    stale.query.mockRejectedValueOnce(lost());
    const connect = connectSpy()
      .mockResolvedValueOnce(stale as any).mockResolvedValueOnce(healthy as any);
    const pool = new ResilientPgPool();
    expect(await pool.connect()).toBe(healthy);
    expect(stale.release).toHaveBeenCalledWith(true);
    expect(healthy.query).toHaveBeenCalledWith({ text: 'SELECT 1', query_timeout: 5000 });
    expect(connect).toHaveBeenCalledTimes(2);
  });

  it('retries a connection failure before any application SQL is sent', async () => {
    const healthy = client();
    connectSpy().mockRejectedValueOnce(lost()).mockResolvedValueOnce(healthy as any);
    expect(await new ResilientPgPool().connect()).toBe(healthy);
    expect(healthy.query).toHaveBeenCalledTimes(1);
  });

  it('stops after one recovery attempt during an outage', async () => {
    const connect = connectSpy().mockRejectedValue(lost());
    await expect(new ResilientPgPool().connect()).rejects.toThrow('Connection terminated unexpectedly');
    expect(connect).toHaveBeenCalledTimes(2);
  });

  it('does not retry invalid credentials', async () => {
    const error = Object.assign(new Error('Authentication failed'), { code: '28P01' });
    const connect = connectSpy().mockRejectedValue(error);
    await expect(new ResilientPgPool().connect()).rejects.toBe(error);
    expect(connect).toHaveBeenCalledTimes(1);
  });

  it('bounds health-check failures and destroys timed-out sockets', async () => {
    const stale = client(), healthy = client();
    stale.query.mockRejectedValueOnce(new Error('Query read timeout'));
    jest.spyOn(Pool.prototype, 'connect').mockImplementationOnce(async () => stale as any)
      .mockImplementationOnce(async () => healthy as any);
    expect(await new ResilientPgPool().connect()).toBe(healthy);
    expect(stale.release).toHaveBeenCalledWith(true);
  });

  it('does not add a health query to every checkout on a busy connection', async () => {
    const healthy = client();
    connectSpy().mockResolvedValue(healthy as any);
    const pool = new ResilientPgPool();
    (await pool.connect()).release();
    await pool.connect();
    expect(healthy.query).toHaveBeenCalledTimes(1);
  });

  it('supports the callback checkout used by pg Pool.query', async () => {
    const healthy = client();
    connectSpy().mockResolvedValue(healthy as any);
    const pool = new ResilientPgPool();
    await new Promise<void>((resolve, reject) => pool.connect((error, checkedOut, release) => {
      if (error) return reject(error);
      expect(checkedOut).toBe(healthy);
      release();
      expect(healthy.release).toHaveBeenCalledTimes(1);
      resolve();
    }));
  });

  it('never replays application SQL after the checked-out connection fails', async () => {
    const healthy = client();
    const connect = connectSpy().mockResolvedValue(healthy as any);
    const checkedOut = await new ResilientPgPool().connect();
    healthy.query.mockRejectedValueOnce(lost());
    await expect(checkedOut.query('UPDATE bookings SET updated_at = NOW()')).rejects.toThrow();
    expect(healthy.query.mock.calls.map(call => call[0])).toEqual([{ text: 'SELECT 1', query_timeout: 5000 }, 'UPDATE bookings SET updated_at = NOW()']);
    expect(connect).toHaveBeenCalledTimes(1);
  });

  it('recognizes nested Prisma adapter disconnects without treating all query errors as retryable', () => {
    expect(isDatabaseConnectionError({ meta: { driverAdapterError: { cause: { originalCode: '57P01' } } } })).toBe(true);
    expect(isDatabaseConnectionError({ meta: { driverAdapterError: { cause: { kind: 'ConnectionClosed' } } } })).toBe(true);
    expect(isDatabaseConnectionError({ code: 'P2002' })).toBe(false);
    expect(isDatabaseConnectionError(new Error('Connection terminated due to connection timeout'))).toBe(false);
  });
});
