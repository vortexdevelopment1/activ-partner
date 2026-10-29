const preflight = require('../../scripts/check-email-schema.cjs');

describe('safe email schema preflight', () => {
  it('prints only database identity, never credentials or other URL parameters', () => {
    const result = preflight.describeTarget('postgresql://user:secret@localhost:5433/dev?schema=public&password=hidden');
    expect(result).toEqual({ host: 'localhost', port: '5433', database: 'dev', schema: 'public', loopback: true });
    expect(JSON.stringify(result)).not.toMatch(/secret|hidden|user/);
  });
  it('blocks remote runtime or migration targets and production before inspection', () => {
    const local = 'postgresql://localhost/dev', remote = 'postgresql://example.com/db';
    for (const config of [
      { production: false, runtimeUrl: remote, migrationUrl: local },
      { production: false, runtimeUrl: local, migrationUrl: remote },
      { production: true, runtimeUrl: local, migrationUrl: local },
    ]) expect(() => preflight.assertLocal(config)).toThrow('No connection was opened');
    expect(() => preflight.assertLocal({ production: false, runtimeUrl: local, migrationUrl: local })).not.toThrow();
  });
  it('detects a different CLI direct target and respects local file precedence', () => {
    const config = preflight.configuration({}, file => file === '.env.local'
      ? { DATABASE_URL: 'postgresql://localhost/override' }
      : { DATABASE_URL: 'postgresql://localhost/base', DIRECT_URL: 'postgresql://localhost/direct' });
    expect(config.runtimeUrl).toBe('postgresql://localhost/override');
    expect(config.migrationUrl).toBe('postgresql://localhost/direct');
  });
  it('never overrides injected production credentials with local files', () => {
    const read = jest.fn(() => ({ DATABASE_URL: 'postgresql://wrong/db' }));
    const config = preflight.configuration({ NODE_ENV: 'production', DATABASE_URL: 'postgresql://localhost/intended' }, read);
    expect(config.runtimeUrl).toBe(config.migrationUrl);
    expect(config.runtimeUrl).toBe('postgresql://localhost/intended');
    expect(read).not.toHaveBeenCalled();
  });
});
