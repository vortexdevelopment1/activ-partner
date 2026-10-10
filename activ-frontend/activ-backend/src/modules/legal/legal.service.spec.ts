import { LegalService } from './legal.service';
import { LegalContentType } from './entities/legal-content.entity';

describe('legal content on the current database schema', () => {
  const type = LegalContentType.TERMS_AND_CONDITIONS;
  const document = {
    id: 'document-1', type, version: '1', title: 'Terms & Conditions',
    body: 'Saved terms and conditions.', status: 'PUBLISHED',
    created_at: new Date(), updated_at: new Date(), published_at: new Date(),
  };
  let prisma: any;
  let service: LegalService;

  beforeEach(() => {
    prisma = {
      content_documents: {
        findMany: jest.fn().mockResolvedValue([]),
        findFirst: jest.fn().mockResolvedValue(document),
        create: jest.fn().mockImplementation(async ({ data }) => ({ ...data, created_at: new Date() })),
      },
      audit_events: { create: jest.fn().mockResolvedValue({}) },
    };
    prisma.$transaction = jest.fn().mockImplementation((callback) => callback(prisma));
    service = new LegalService(prisma);
  });

  it.each(Object.values(LegalContentType))('publishes %s and preserves the app response shape', async (legalType) => {
    const result = await service.upsert(legalType, { content: document.body }, 'admin-1');
    expect(prisma.content_documents.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      type: legalType, body: document.body, status: 'PUBLISHED', version: '1',
    }) });
    expect(result).toMatchObject({ type: legalType, content: document.body, version: 1, updatedBy: 'admin-1' });
    expect(result.createdAt).toBeInstanceOf(Date);
    expect(result.updatedAt).toBeInstanceOf(Date);
    expect(prisma.audit_events.create).toHaveBeenCalledWith({ data: expect.objectContaining({ actor_id: 'admin-1' }) });
  });

  it('creates the next version without overwriting older documents', async () => {
    prisma.content_documents.findMany.mockResolvedValue([{ ...document, version: '2' }, document]);
    const result = await service.upsert(type, { content: 'Updated legal content.' }, 'admin-1');
    expect(result.version).toBe(3);
    expect(result.content).toBe('Updated legal content.');
  });

  it('retries a concurrent version conflict', async () => {
    prisma.$transaction.mockRejectedValueOnce({ code: 'P2034' });
    await service.upsert(type, { content: document.body }, 'admin-1');
    expect(prisma.$transaction).toHaveBeenCalledTimes(2);
  });

  it('returns only one latest published document per type', async () => {
    prisma.content_documents.findMany.mockResolvedValue([
      { ...document, version: '2', body: 'Latest published content.' }, document,
      { ...document, type: LegalContentType.PRIVACY_POLICY },
    ]);
    const result = await service.findAll();
    expect(result).toHaveLength(2);
    expect(result[0]).toMatchObject({ content: 'Latest published content.', version: 2 });
    expect(prisma.content_documents.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { type: { in: Object.values(LegalContentType) }, status: 'PUBLISHED' },
    }));
  });

  it('retrieves published content by type and handles missing content', async () => {
    expect(await service.findByType(type)).toMatchObject({ content: document.body, title: document.title });
    expect(prisma.content_documents.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { type, status: 'PUBLISHED' } }));
    prisma.content_documents.findFirst.mockResolvedValue(null);
    await expect(service.findByType(type)).rejects.toThrow('has not been set yet');
  });

  it('rejects unsupported document types without querying the database', async () => {
    await expect(service.upsert('invalid' as LegalContentType, { content: document.body }, 'admin-1')).rejects.toThrow('Invalid legal content type');
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('exports the saved published content as a PDF', async () => {
    const result = await service.generateLegalPdfExport(type);
    expect(result.filename).toBe('activ-terms-and-conditions.pdf');
    expect(Buffer.from(result.base64, 'base64').subarray(0, 5).toString()).toBe('%PDF-');
  });
});
