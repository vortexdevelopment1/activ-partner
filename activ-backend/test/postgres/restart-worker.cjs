// A fresh process, real Prisma/outbox, mocked transport. No application/OAuth bootstrap.
require('ts-node/register/transpile-only');
const { PrismaClient } = require('../../src/generated/prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { EmailDeliveryService } = require('../../src/modules/mail/email-delivery.service');
const net = require('net');
const original = net.Socket.prototype.connect;
net.Socket.prototype.connect = function (...args) {
  const options = net._normalizeArgs(args)[0];
  if (options.host !== '127.0.0.1') throw new Error('External network disabled');
  return original.apply(this, args);
};
async function main() {
  const url = new URL(process.env.ACTIV_PG_TEST_URL || '');
  if (url.hostname !== '127.0.0.1' || url.pathname !== '/activ_integration_test' || url.username !== 'activ_integration') throw new Error('Test target rejected');
  const db = new PrismaClient({ adapter: new PrismaPg({ connectionString: url.toString() }) });
  try {
    const rows = await db.$queryRaw`SELECT marker FROM activ_integration_guard`;
    if (rows[0]?.marker !== process.env.ACTIV_PG_TEST_MARKER) throw new Error('Test guard rejected');
    let sent = 0;
    const config = { get: key => key === 'EMAIL_DELIVERY_STORAGE_KEY' ? process.env.ACTIV_PG_TEST_STORAGE_KEY : undefined };
    const deliveries = new EmailDeliveryService(db, config);
    deliveries.configure(async job => {
      if (job.method !== 'approval' || !job.params.password) throw new Error('Expected recoverable encrypted approval');
      sent++; return 'mock-restart-message';
    }, true);
    await deliveries.tick();
    console.log(`Recovered ${sent} pending approval`);
  } finally { await db.$disconnect(); }
}
main().catch(() => { console.error('Restart recovery failed'); process.exitCode = 1; });
