import { seedQuestions } from './questions.seed';

describe('Pickle Ball question catalogue', () => {
  it('restores its seven expected questions without duplicates on rerun', async () => {
    const questions: any[] = [];
    const prisma = {
      partner_service_categories: { findUnique: jest.fn().mockResolvedValue({ id: 'pickle-ball' }) },
      partner_service_questions: {
        count: jest.fn(async () => questions.length),
        findMany: jest.fn(async () => questions),
        createMany: jest.fn(async ({ data }) => { questions.push(...data); return { count: data.length }; }),
        update: jest.fn(async ({ where, data }) => Object.assign(questions.find(q => q.id === where.id), data)),
      },
    };
    const log = jest.spyOn(console, 'log').mockImplementation(() => {});
    try {
      await seedQuestions(prisma as any, ['Pickle Ball']);
      await seedQuestions(prisma as any, ['Pickle Ball']);
      expect(prisma.partner_service_categories.findUnique).toHaveBeenCalledWith({ where: { slug: 'pickle-ball' } });
      expect(questions).toHaveLength(6);
      expect(questions.map(q => q.question)).toEqual(['Activity Description', 'Total Courts', 'Court Surface', 'Playing Environment', 'Coaching Available', 'Recommended For']);
      expect(questions[0]).toMatchObject({ type: 'TEXTAREA', is_required: true });
      expect(questions.every(q => q.service_category_id === 'pickle-ball')).toBe(true);
      expect(prisma.partner_service_questions.createMany).toHaveBeenCalledTimes(1);
    } finally { log.mockRestore(); }
  });
});

describe('Basketball question catalogue', () => {
  it('adds missing fields, preserves existing IDs and options, and is repeatable', async () => {
    const questions: any[] = [
      { id: 'description', question: 'Activity Description', options: [], sort_order: 1 },
      { id: 'court-type', question: 'Court Type', options: ['Custom Court'], sort_order: 3 },
      { id: 'environment', question: 'Playing Environment', options: [], sort_order: 4 },
    ];
    const prisma = {
      partner_service_categories: {
        findUnique: jest.fn().mockResolvedValue({ id: 'basketball-category' }),
      },
      partner_service_questions: {
        count: jest.fn(async () => questions.length),
        findMany: jest.fn(async () => questions),
        update: jest.fn(async ({ where, data }) => {
          Object.assign(questions.find((question) => question.id === where.id), data);
        }),
        createMany: jest.fn(async ({ data }) => {
          questions.push(...data);
          return { count: data.length };
        }),
      },
    };
    const log = jest.spyOn(console, 'log').mockImplementation(() => {});
    try {
      await seedQuestions(prisma as any, ['Basketball']);
      await seedQuestions(prisma as any, ['Basketball']);
      expect(prisma.partner_service_categories.findUnique).toHaveBeenCalledTimes(2);
      expect(questions.filter((question) => question.question === 'Activity Description'))
        .toEqual([expect.objectContaining({ id: 'description' })]);
      expect(questions.filter((question) => question.question === 'Playing Environment'))
        .toEqual([expect.objectContaining({ id: 'environment', options: [
          'Indoor', 'Outdoor', 'Air Conditioned', 'Covered', 'Floodlights', 'Spectator Seating',
        ] })]);
      expect(questions.find((question) => question.question === 'Court Type').options)
        .toEqual(['Custom Court']);
      expect(questions.find((question) => question.question === 'Pitch Surface').options.length)
        .toBeGreaterThan(0);
      expect(questions.some((question) => question.question === 'Total Arenas')).toBe(true);
      expect(questions.some((question) => question.question === 'Total Courts')).toBe(true);
      expect(prisma.partner_service_questions.createMany).toHaveBeenCalledTimes(1);
      expect(new Set(questions.map((question) => question.question)).size).toBe(questions.length);
    } finally {
      log.mockRestore();
    }
  });
});

describe('Cricket question catalogue', () => {
  it('adds pitch type options to existing cricket turf questions with empty options', async () => {
    const questions: any[] = [
      { id: 'description', question: 'Activity Description', options: [], sort_order: 1 },
      { id: 'total-turfs', question: 'Total Turfs', options: [], sort_order: 2 },
      { id: 'pitch-type', question: 'Pitch Type', options: [], sort_order: 3 },
    ];
    const prisma = {
      partner_service_categories: {
        findUnique: jest.fn().mockResolvedValue({ id: 'cricket-turf-category' }),
      },
      partner_service_questions: {
        count: jest.fn(async () => questions.length),
        findMany: jest.fn(async () => questions),
        update: jest.fn(async ({ where, data }) => {
          Object.assign(questions.find((question) => question.id === where.id), data);
        }),
        createMany: jest.fn(async ({ data }) => {
          questions.push(...data);
          return { count: data.length };
        }),
      },
    };
    const log = jest.spyOn(console, 'log').mockImplementation(() => {});
    try {
      await seedQuestions(prisma as any, ['Cricket Turf']);

      expect(questions.find((question) => question.question === 'Pitch Type').options)
        .toEqual(['Natural Turf', 'Artificial Turf', 'Matting', 'Concrete']);
      expect(prisma.partner_service_questions.createMany).toHaveBeenCalledTimes(1);
    } finally {
      log.mockRestore();
    }
  });
});
