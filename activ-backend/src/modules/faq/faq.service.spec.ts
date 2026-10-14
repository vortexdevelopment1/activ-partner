import { NotFoundException } from '@nestjs/common';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { FaqService } from './faq.service';

describe('FAQ schema compatibility', () => {
  const now = new Date();
  const record = { id: 'faq-1', question: 'Question?', answer: 'Answer', sort_order: 2,
    status: 'PUBLISHED', published_at: now, created_at: now, updated_at: now };
  let table: any;
  let service: FaqService;

  beforeEach(() => {
    table = {
      create: jest.fn(async ({ data }) => ({ ...record, ...data })),
      update: jest.fn(async ({ data }) => ({ ...record, ...data })),
      findUnique: jest.fn().mockResolvedValue(record),
      findMany: jest.fn().mockResolvedValue([record]),
      count: jest.fn().mockResolvedValue(1),
      delete: jest.fn().mockResolvedValue(record),
    };
    service = new FaqService({ faqs: table } as any);
  });

  it('creates published FAQs using the existing database fields and API defaults', async () => {
    const result = await service.create({ question: 'New?', answer: 'Yes' });
    expect(table.create.mock.calls[0][0].data).toMatchObject({
      sort_order: 0, status: 'PUBLISHED', published_at: expect.any(Date), updated_at: expect.any(Date),
    });
    expect(result).toMatchObject({ order: 0, isActive: true, createdAt: now });
    expect(result).not.toHaveProperty('sort_order');
  });

  it('keeps inactive FAQs as unpublished drafts', async () => {
    const result = await service.create({ question: 'Hidden?', answer: 'Yes', isActive: false, order: 3 });
    expect(result).toMatchObject({ order: 3, isActive: false });
    expect(table.create.mock.calls[0][0].data).toMatchObject({ status: 'DRAFT', published_at: null });
  });

  it('uses the same search for paginated rows and count, ordered by sort_order', async () => {
    const pagination = Object.assign(new PaginationDto(), { page: 2, limit: 5, search: ' Answer ' });
    const [items, total] = await service.findAll(pagination);
    expect(total).toBe(1);
    expect(items[0]).toMatchObject({ order: 2, isActive: true });
    expect(table.findMany.mock.calls[0][0]).toMatchObject({ skip: 5, take: 5,
      orderBy: [{ sort_order: 'asc' }, { created_at: 'desc' }, { id: 'asc' }],
    });
    expect(table.count).toHaveBeenCalledWith({ where: table.findMany.mock.calls[0][0].where });
    expect(table.findMany.mock.calls[0][0].where.OR[1].answer).toEqual({ contains: 'Answer', mode: 'insensitive' });
  });

  it('limits public FAQs to published records', async () => {
    await service.findAllActive();
    expect(table.findMany.mock.calls[0][0].where).toEqual({ status: 'PUBLISHED' });
  });

  it('supports zero ordering and deactivation without overwriting other fields', async () => {
    const result = await service.update(record.id, { order: 0, isActive: false });
    expect(result).toMatchObject({ order: 0, isActive: false, question: record.question });
    expect(table.update.mock.calls[0][0].data).toMatchObject({ sort_order: 0, status: 'DRAFT', published_at: null });
    expect(table.update.mock.calls[0][0].data).not.toHaveProperty('question');
  });

  it('returns not-found errors before changing missing FAQs', async () => {
    table.findUnique.mockResolvedValue(null);
    await expect(service.update('missing', { answer: 'New' })).rejects.toBeInstanceOf(NotFoundException);
    await expect(service.remove('missing')).rejects.toBeInstanceOf(NotFoundException);
    expect(table.update).not.toHaveBeenCalled();
    expect(table.delete).not.toHaveBeenCalled();
  });
});
