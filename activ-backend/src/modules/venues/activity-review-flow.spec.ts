import { VenuesService } from './venues.service';
import { VenuesController } from './venues.controller';
import { BadRequestException } from '@nestjs/common';
import { ActivityReviewQueryDto } from './dto/activity-review-query.dto';
import { validate } from 'class-validator';

describe('post-onboarding activity review', () => {
  it.each(['all', 'pending', 'approved', 'rejected'] as const)('filters %s before pagination and counts the same set', async status => {
    const prisma = { partner_venue_services: { findMany: jest.fn().mockResolvedValue([]), count: jest.fn().mockResolvedValue(0) } };
    const service = Object.assign(Object.create(VenuesService.prototype), { prisma }) as VenuesService;
    await service.findPendingActivities({ skip: 15, limit: 15 } as any, status);
    const where = status === 'all'
      ? { status: { in: ['PENDING', 'APPROVED', 'REJECTED'] } }
      : { status: status.toUpperCase() };
    expect(prisma.partner_venue_services.findMany).toHaveBeenCalledWith(expect.objectContaining({ where, skip: 15, take: 15 }));
    expect(prisma.partner_venue_services.count).toHaveBeenCalledWith({ where });
  });

  it('rejects unsupported status filters and keeps pending as the legacy default', async () => {
    const query = new ActivityReviewQueryDto();
    expect(query.status).toBe('pending');
    Object.assign(query, { status: 'draft' });
    expect((await validate(query)).some(error => error.property === 'status')).toBe(true);
  });

  it('queues a draft, notifies admin, lists it for review, and approves it', async () => {
    const record = { id: 'activity', venue_id: 'venue', status: 'DRAFT', venues: { partner_id: 'partner', id: 'venue' } };
    const prisma = { partner_venue_services: {
      update: jest.fn(async ({ data }) => Object.assign(record, data)),
      findUnique: jest.fn(async () => record),
      findMany: jest.fn(async () => record.status === 'PENDING' ? [record] : []),
      count: jest.fn(async () => record.status === 'PENDING' ? 1 : 0),
    }, partner_venue_answers: { findMany: jest.fn(async () => [{ question_id: 'required' }]) } };
    const service = Object.assign(Object.create(VenuesService.prototype), {
      prisma,
      findOwnedActivity: jest.fn(async () => ({ id: 'activity', venueId: 'venue', name: 'Swimming', categoryId: 'swimming',
        status: record.status.toLowerCase(), imageUrls: ['1', '2', '3', '4'], amenities: ['Parking'] })),
      questionsService: { findByCategoryId: jest.fn(async () => [{ id: 'required', isRequired: true }]) },
      adminNotificationsService: { notify: jest.fn() }, notificationsService: { notify: jest.fn() },
      syncLegacyActivitySlots: jest.fn(),
    }) as VenuesService;
    await service.submitActivityForReview('activity', 'partner');
    expect(record.status).toBe('PENDING');
    expect((service as any).adminNotificationsService.notify).toHaveBeenCalledWith(
      'activity_submitted', expect.any(String), expect.any(String), { partnerId: 'partner', venueId: 'venue', serviceId: 'activity' });
    const [pending, total] = await service.findPendingActivities({ skip: 0, limit: 15 } as any);
    expect(total).toBe(1); expect(pending[0].id).toBe('activity');
    await service.processActivityApproval('activity', { status: 'approved' } as any, 'admin');
    expect(record).toMatchObject({ status: 'APPROVED', is_active: true, approved_by: 'admin' });
    expect((service as any).notificationsService.notify).toHaveBeenCalledWith(
      'partner', 'activity_approved', expect.any(String), expect.any(String), { serviceId: 'activity' });
    expect((await service.findPendingActivities({ skip: 0, limit: 15 } as any))[1]).toBe(0);
  });

  it('checks ownership and question type before uploading answer documents', async () => {
    const cloudinaryService = { uploadFile: jest.fn() };
    const controller = Object.assign(Object.create(VenuesController.prototype), {
      venuesService: { getActivityQuestions: jest.fn(async () => [{ id: 'other', questionType: 'file' }]) }, cloudinaryService,
    }) as VenuesController;
    await expect(controller.uploadActivityAnswerFile('activity', 'question', { id: 'partner' },
      { mimetype: 'application/pdf' } as Express.Multer.File)).rejects.toBeInstanceOf(BadRequestException);
    expect(cloudinaryService.uploadFile).not.toHaveBeenCalled();
  });
});
