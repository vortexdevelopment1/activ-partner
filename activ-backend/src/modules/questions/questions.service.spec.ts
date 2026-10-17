import { QuestionsService } from './questions.service';

describe('partner activity question visibility', () => {
  it('excludes ABCD/ABCDE placeholders without removing real required questions', async () => {
    const row = { type: 'SELECT', options: ['a', 'b'], sort_order: 0, is_required: true };
    const prisma = {
      partner_service_questions: {
        findMany: jest.fn().mockResolvedValue([
          { ...row, id: 'test-category', question: 'ABCDE', service_category_id: 'badminton' },
          { ...row, id: 'test-global', question: ' abcd ', service_category_id: null },
          { ...row, id: 'test-placeholder-2', question: ' asdf2 ', service_category_id: 'badminton' },
          { ...row, id: 'courts', question: 'Total Courts', service_category_id: 'badminton' },
          { ...row, id: 'real-label', question: 'Court ABCDE layout', service_category_id: 'badminton' },
        ]),
      },
    };
    const service = new QuestionsService(prisma as any);
    const questions = await service.findByCategoryId('badminton');
    expect(questions.map((question) => question.id)).toEqual(['courts', 'real-label']);
    expect(questions.every((question) => question.isRequired)).toBe(true);
  });
});
