import { migrationEnvironment, isProductionEnvironment } from './environment';

describe('deployment environment isolation', () => {
  it.each(['NODE_ENV', 'APP_ENV'])('ignores local files when %s is production', key => {
    const read = jest.fn(() => ({ DIRECT_URL: 'postgresql://wrong/local' }));
    const env = { [key]: 'production', DATABASE_URL: 'postgresql://injected/target' };
    expect(migrationEnvironment(env, read)).toEqual(env);
    expect(read).not.toHaveBeenCalled();
    expect(isProductionEnvironment(env)).toBe(true);
  });
  it('rejects production migration without an injected target', () => {
    expect(() => migrationEnvironment({ NODE_ENV: 'production' })).toThrow('explicitly injected');
  });
  it('does not let local DIRECT_URL or DB_HOST change an injected target', () => {
    const env = migrationEnvironment({ DATABASE_URL: 'postgresql://injected/target' }, () => ({
      DATABASE_URL: 'postgresql://wrong/local', DIRECT_URL: 'postgresql://wrong/direct', DB_HOST: 'wrong', OTHER: 'local',
    }));
    expect(env).toEqual({ DATABASE_URL: 'postgresql://injected/target', OTHER: 'local' });
  });
  it('supports local development files with .env.local taking precedence', () => {
    expect(migrationEnvironment({}, file => ({ DATABASE_URL: file }))).toEqual({ DATABASE_URL: '.env.local' });
  });
});
