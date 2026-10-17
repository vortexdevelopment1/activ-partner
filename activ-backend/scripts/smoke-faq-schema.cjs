const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { config } = require('dotenv');
const { ConfigService } = require('@nestjs/config');
const { PrismaService } = require('../dist/prisma/prisma.service');
const { FaqService } = require('../dist/modules/faq/faq.service');
const { PaginationDto } = require('../dist/common/dto/pagination.dto');

const env = { ...process.env, ...config({ path: '.env', quiet: true }).parsed,
  ...config({ path: '.env.local', quiet: true }).parsed };
const prisma = new PrismaService(new ConfigService(env));
const rollback = new Error('FAQ smoke transaction rollback');

(async () => {
  try {
    await prisma.$connect();
    try {
      await prisma.$transaction(async (tx) => {
        const service = new FaqService(tx);
        const question = `FAQ schema smoke ${randomUUID()}`;
        const faq = await service.create({ question, answer: 'Schema verification', order: 2, isActive: false });
        assert.equal(faq.isActive, false);
        assert.equal(faq.order, 2);
        const [items, total] = await service.findAll(Object.assign(new PaginationDto(), { search: question }));
        assert.equal(total, 1);
        assert.equal(items[0].id, faq.id);
        assert(!(await service.findAllActive()).some((item) => item.id === faq.id));
        const updated = await service.update(faq.id, { isActive: true, order: 0, answer: 'Updated verification' });
        assert.equal(updated.order, 0);
        assert.equal(updated.answer, 'Updated verification');
        assert((await service.findAllActive()).some((item) => item.id === faq.id));
        await service.remove(faq.id);
        assert.equal(await tx.faqs.findUnique({ where: { id: faq.id } }), null);
        throw rollback;
      }, { timeout: 20000 });
    } catch (error) {
      if (error !== rollback) throw error;
    }
    console.log('FAQ create, list, search, edit, visibility and delete checks passed. Test transaction rolled back.');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
})();
