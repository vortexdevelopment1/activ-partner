import { existsSync, readFileSync } from 'fs';
import { parse } from 'dotenv';

export const isProductionEnvironment = (env: NodeJS.ProcessEnv): boolean =>
  env.NODE_ENV === 'production' || env.APP_ENV === 'production';

/** Parse without mutating process.env. Deployment secrets always win. */
export function migrationEnvironment(env: NodeJS.ProcessEnv, read = (file: string) =>
  existsSync(file) ? parse(readFileSync(file)) : {}): NodeJS.ProcessEnv {
  if (isProductionEnvironment(env)) {
    if (!env.DATABASE_URL && !env.DIRECT_URL && !env.DB_HOST) {
      throw new Error('Production migration requires an explicitly injected database target');
    }
    return { ...env };
  }
  const files = { ...read('.env'), ...read('.env.local') };
  // An injected database target must not inherit a different local DIRECT_URL.
  if (env.DATABASE_URL || env.DIRECT_URL || env.DB_HOST) {
    for (const key of Object.keys(files)) {
      if (key === 'DATABASE_URL' || key === 'DIRECT_URL' || key.startsWith('DB_')) delete files[key];
    }
  }
  return { ...files, ...env };
}
