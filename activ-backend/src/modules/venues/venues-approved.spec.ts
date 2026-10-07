import { ForbiddenException } from '@nestjs/common';
import { VenuesService } from './venues.service';

describe('approved partner venues', () => {
  const category = { id: 'category-1', name: 'Badminton', description: '' };
  const now = new Date('2026-10-06T00:00:00Z');
  let service: VenuesService;
  let prisma: { venues: { findMany: jest.Mock; findUnique: jest.Mock } };
  let legacyFind: jest.Mock;

  beforeEach(() => {
    prisma = { venues: { findMany: jest.fn(), findUnique: jest.fn() } };
    legacyFind = jest.fn(() => { throw new Error('Legacy schema must not be queried'); });
    service = Object.assign(Object.create(VenuesService.prototype), {
      prisma, venueRepository: { find: legacyFind },
    });
    prisma.venues.findMany.mockResolvedValue([{ id: 'venue-1' }]);
    prisma.venues.findUnique.mockResolvedValue({
      id: 'venue-1', partner_id: 'partner-1', name: 'Arena', city_code: 'Indore',
      latitude: 22.75, longitude: 75.89, status: 'PUBLISHED', metadata: {},
      partners: { legal_name: 'Partner', partner_business_profiles: null,
        partner_users: [{ users: { name: 'Test Partner', email: 'partner@example.com' } }] },
      partner_venue_profiles: { display_name: 'Arena', amenities: ['WiFi'], created_at: now, updated_at: now },
      partner_venue_images: [{ id: 'photo', venue_id: 'venue-1', url: '/photo.png', is_primary: true }],
      partner_venue_services: [{ id: 'service-1', venue_id: 'venue-1', service_category_id: category.id,
        title: 'Court A', status: 'APPROVED', partner_service_categories: category }],
      partner_venue_answers: [
        { id: 'answer-1', venue_id: 'venue-1', venue_service_id: null, question_id: 'question-1', answer: '6',
          partner_service_questions: { id: 'question-1', question: 'Total Courts',
            service_category_id: category.id, partner_service_categories: category } },
        { id: 'answer-2', venue_id: 'venue-1', venue_service_id: 'service-1', question_id: 'question-2', answer: 'Indoor',
          partner_service_questions: { id: 'question-2', question: 'Environment',
            service_category_id: null, partner_service_categories: null } },
        { id: 'other-answer', venue_service_id: 'other-service', question_id: 'question-3', answer: 'Other',
          partner_service_questions: { id: 'question-3', question: 'Total Courts',
            service_category_id: category.id, partner_service_categories: category } },
      ],
    });
  });

  it('uses the current published venue schema and preserves the app response', async () => {
    const result = await service.findApprovedByPartner('partner-1');
    expect(prisma.venues.findMany).toHaveBeenCalledWith({
      where: { partner_id: 'partner-1', status: 'PUBLISHED' }, select: { id: true },
      orderBy: [{ partner_venue_profiles: { created_at: 'desc' } }, { id: 'asc' }],
    });
    expect(legacyFind).not.toHaveBeenCalled();
    expect(result[0]).toMatchObject({ id: 'venue-1', name: 'Arena', status: 'approved', amenities: ['WiFi'] });
    expect(result[0].images[0].imageUrl).toBe('/photo.png');
    expect(result[0].services[0].answers.map((answer) => answer.id)).toEqual(['answer-1', 'answer-2']);
    expect(result[0].answers[0].question.category).toMatchObject({ id: category.id, name: category.name });
  });

  it('returns an empty list when the partner has no approved venue', async () => {
    prisma.venues.findMany.mockResolvedValue([]);
    expect(await service.findApprovedByPartner('partner-1')).toEqual([]);
    expect(prisma.venues.findUnique).not.toHaveBeenCalled();
  });

  it('rejects missing partner identity instead of returning other partners venues', async () => {
    await expect(service.findApprovedByPartner(undefined as unknown as string))
      .rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.venues.findMany).not.toHaveBeenCalled();
  });
});
