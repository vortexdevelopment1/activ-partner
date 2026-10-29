import { randomUUID } from 'crypto';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../../src/generated/prisma/client';
import { VenuesService } from '../../src/modules/venues/venues.service';

describe('real PostgreSQL activity category form saves', () => {
  let db: PrismaClient;
  let service: VenuesService;
  beforeAll(async () => {
    const url = new URL(process.env.ACTIV_PG_TEST_URL || '');
    if (url.hostname !== '127.0.0.1' || url.pathname !== '/activ_integration_test' || url.username !== 'activ_integration' || !process.env.ACTIV_PG_TEST_MARKER) throw new Error('Isolated test database required');
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: url.toString() }) });
    const guard = await db.$queryRaw<any[]>`SELECT marker FROM activ_integration_guard`;
    expect(guard[0]?.marker).toBe(process.env.ACTIV_PG_TEST_MARKER);
    service = Object.assign(Object.create(VenuesService.prototype), { prisma: db });
  });
  afterAll(async () => { await db?.$disconnect(); });
  async function fixture() {
    const partner = randomUUID(), venue = randomUUID(), category = randomUUID(), activity = randomUUID();
    await db.partners.create({ data: { id: partner, legal_name: 'Form Test Partner', updated_at: new Date() } });
    await db.venues.create({ data: { id: venue, partner_id: partner, name: 'Form Test Venue', city_code: 'TEST',
      latitude: 1, longitude: 1, policy_version: 'test' } });
    await db.partner_service_categories.create({ data: { id: category, slug: category, name: 'Basketball', updated_at: new Date() } });
    await db.partner_venue_services.create({ data: { id: activity, venue_id: venue, service_category_id: category,
      title: 'Basketball', status: 'APPROVED', description: 'Old', onboarding_data: { preserved: true }, updated_at: new Date() } });
    const questions = {} as Record<string, string>;
    for (const [key, label] of Object.entries({ description: 'Activity Description', arenas: 'Total Arenas', courts: 'Total Courts' })) {
      questions[key] = randomUUID();
      await db.partner_service_questions.create({ data: { id: questions[key], service_category_id: category,
        question: label, type: 'TEXT', updated_at: new Date() } });
    }
    await db.partner_venue_answers.create({ data: { id: randomUUID(), venue_id: venue,
      venue_service_id: activity, question_id: questions.description, answer: 'Old', updated_at: new Date() } });
    return { partner, venue, category, activity, questions };
  }
  it('saves all category fields and compatible summary values on the same activity', async () => {
    const f = await fixture();
    await service.updateActivityManagement(f.activity, f.partner, { answers: [
      { questionId: f.questions.description, answer: 'Updated' },
      { questionId: f.questions.arenas, answer: '52' },
      { questionId: f.questions.courts, answer: '3' },
    ] });
    const saved = await db.partner_venue_answers.findMany({ where: { venue_service_id: f.activity } });
    expect(saved).toHaveLength(3);
    expect(saved.find(answer => answer.question_id === f.questions.arenas).answer).toBe('52');
    expect((await db.partner_venue_services.findUnique({ where: { id: f.activity } })).onboarding_data)
      .toEqual({ preserved: true, numberOfCourt: '3' });
    expect(await service.getActivityManagement(f.activity, f.partner)).toMatchObject({ description: 'Updated', numberOfCourt: '3' });
  });
  it('rolls back answer updates/inserts when the final activity write fails', async () => {
    const f = await fixture();
    await db.$executeRawUnsafe("CREATE FUNCTION fail_test_activity_details() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'Injected activity write failure'; END; $$");
    await db.$executeRawUnsafe('CREATE TRIGGER fail_test_activity_details BEFORE UPDATE ON partner_venue_services FOR EACH ROW EXECUTE FUNCTION fail_test_activity_details()');
    try {
      await expect(service.updateActivityManagement(f.activity, f.partner, { answers: [
        { questionId: f.questions.description, answer: 'Must roll back' },
        { questionId: f.questions.arenas, answer: '52' },
      ] })).rejects.toThrow();
    } finally {
      await db.$executeRawUnsafe('DROP TRIGGER fail_test_activity_details ON partner_venue_services');
      await db.$executeRawUnsafe('DROP FUNCTION fail_test_activity_details()');
    }
    const saved = await db.partner_venue_answers.findMany({ where: { venue_service_id: f.activity } });
    expect(saved).toHaveLength(1);
    expect(saved[0].answer).toBe('Old');
    const activity = await db.partner_venue_services.findUnique({ where: { id: f.activity } });
    expect(activity.description).toBe('Old'); expect(activity.onboarding_data).toEqual({ preserved: true });
  });
  it('serializes concurrent form saves without creating duplicate question answers', async () => {
    const f = await fixture();
    await Promise.all(['First', 'Second'].map(answer => service.updateActivityManagement(f.activity, f.partner, {
      answers: [{ questionId: f.questions.arenas, answer }],
    })));
    expect(await db.partner_venue_answers.count({ where: { venue_service_id: f.activity, question_id: f.questions.arenas } })).toBe(1);
  });
});
