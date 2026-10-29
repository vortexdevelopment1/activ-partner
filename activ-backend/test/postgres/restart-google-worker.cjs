require('ts-node/register/transpile-only');
const net = require('net');
const original = net.Socket.prototype.connect;
net.Socket.prototype.connect = function (...args) {
  const options = net._normalizeArgs(args)[0];
  if (options.host !== '127.0.0.1') throw new Error('External network disabled');
  return original.apply(this, args);
};
const { PrismaClient } = require('../../src/generated/prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { GoogleCredentialStore } = require('../../src/modules/mail/google-credential.store');
const { GoogleOAuthService } = require('../../src/modules/mail/google-oauth.service');
async function main() {
  const url = new URL(process.env.ACTIV_PG_TEST_URL || '');
  if (url.hostname !== '127.0.0.1' || url.pathname !== '/activ_integration_test' || url.username !== 'activ_integration') throw new Error('Test target rejected');
  const db = new PrismaClient({ adapter: new PrismaPg({ connectionString: url.toString() }) });
  try {
    const rows = await db.$queryRaw`SELECT marker FROM activ_integration_guard`;
    if (rows[0]?.marker !== process.env.ACTIV_PG_TEST_MARKER) throw new Error('Test guard rejected');
    const settings = { GOOGLE_TOKEN_SOURCE: 'database', GOOGLE_SENDER_EMAIL: 'support@activ.live', GOOGLE_CLIENT_ID: 'postgres-oauth-test-client',
      GOOGLE_CLIENT_SECRET: 'synthetic-secret', GOOGLE_REFRESH_TOKEN_STORAGE_KEY: process.env.ACTIV_PG_GOOGLE_KEY };
    const config = { get: (key, fallback) => settings[key] ?? fallback };
    const store = new GoogleCredentialStore(db, config);
    const service = new GoogleOAuthService(config, store);
    await service.onModuleInit(); // No Google requests: only local database read/decrypt.
    const loaded = await store.load('support@activ.live', 'postgres-oauth-test-client');
    if (!service.hasRefreshToken() || loaded.token !== process.env.ACTIV_PG_GOOGLE_EXPECTED || !(await service.credentialStatus()).verified) throw new Error('Recovery failed');
    console.log('Verified database credential recovered in fresh process');
  } finally { await db.$disconnect(); }
}
main().catch(() => { console.error('Google credential restart recovery failed'); process.exitCode = 1; });
