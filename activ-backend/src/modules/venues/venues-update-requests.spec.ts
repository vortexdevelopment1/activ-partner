import { BadRequestException, ConflictException, ForbiddenException } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { VenuesService } from './venues.service';
import { SubmitVenueUpdateDto } from './dto/submit-venue-update.dto';

describe('post-approval venue updates', () => {
  const now = new Date('2026-10-06T10:30:00Z');
  const record = { id: 'request-1', venue_id: 'venue-1', partner_id: 'partner-1',
    status: 'PENDING', requested_changes: { name: 'Updated Arena', flatBuilding: '',
      locationUrl: 'https://maps.app.goo.gl/example' }, created_at: now, updated_at: now };
  let tx: any;
  let prisma: any;
  let service: VenuesService;
  let notify: jest.Mock;

  beforeEach(() => {
    tx = {
      $queryRaw: jest.fn().mockResolvedValue([]),
      venues: { findUnique: jest.fn().mockResolvedValue({ id: 'venue-1', partner_id: 'partner-1',
        status: 'PUBLISHED', metadata: { commission: 12, bookingAccept: false, availability: { badminton: [] } } }),
        update: jest.fn().mockResolvedValue({}) },
      partner_venue_profiles: { upsert: jest.fn().mockResolvedValue({}) },
      partner_venue_update_requests: {
        findFirst: jest.fn().mockResolvedValue(null), findUnique: jest.fn().mockResolvedValue(record),
        create: jest.fn().mockImplementation(({ data }) => Promise.resolve({ ...record, ...data })),
        update: jest.fn().mockImplementation(({ data }) => Promise.resolve({ ...record, ...data })),
      },
    };
    prisma = { $transaction: jest.fn((callback) => callback(tx)),
      partner_venue_update_requests: { findMany: jest.fn().mockResolvedValue([record]),
        findUnique: jest.fn().mockResolvedValue(record), count: jest.fn().mockResolvedValue(1) } };
    notify = jest.fn().mockResolvedValue(undefined);
    service = Object.assign(Object.create(VenuesService.prototype), {
      prisma, notificationsService: { notify },
      findOne: jest.fn().mockResolvedValue({ id: 'venue-1', partnerId: 'partner-1', name: 'Updated Arena' }),
    });
  });

  it('stores a pending request without modifying published venue data', async () => {
    const result = await service.submitVenueUpdateRequest('venue-1', 'partner-1', { name: 'Updated Arena' });
    expect(tx.$queryRaw).toHaveBeenCalled();
    expect(tx.partner_venue_update_requests.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      partner_id: 'partner-1', venue_id: 'venue-1', status: 'PENDING', requested_changes: { name: 'Updated Arena' },
    }) });
    expect(result).toMatchObject({ venueId: 'venue-1', status: 'pending', name: 'Updated Arena', createdAt: now });
    expect(tx.venues.update).not.toHaveBeenCalled();
    expect(tx.partner_venue_profiles.upsert).not.toHaveBeenCalled();
  });

  it('rejects duplicate pending requests', async () => {
    tx.partner_venue_update_requests.findFirst.mockResolvedValue(record);
    await expect(service.submitVenueUpdateRequest('venue-1', 'partner-1', { name: 'Updated' }))
      .rejects.toBeInstanceOf(ConflictException);
    expect(tx.partner_venue_update_requests.create).not.toHaveBeenCalled();
  });

  it('rejects another partner and an unapproved venue', async () => {
    await expect(service.submitVenueUpdateRequest('venue-1', 'other-partner', { name: 'Updated' }))
      .rejects.toBeInstanceOf(ForbiddenException);
    tx.venues.findUnique.mockResolvedValue({ id: 'venue-1', partner_id: 'partner-1', status: 'DRAFT' });
    await expect(service.submitVenueUpdateRequest('venue-1', 'partner-1', { name: 'Updated' }))
      .rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects empty requests and invalid phone numbers', async () => {
    await expect(service.submitVenueUpdateRequest('venue-1', 'partner-1', {})).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.submitVenueUpdateRequest('venue-1', 'partner-1', { venuePhone: null } as any))
      .rejects.toBeInstanceOf(BadRequestException);
    await expect(service.submitVenueUpdateRequest('venue-1', 'partner-1', { venuePhone: '123' }))
      .rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('loads only the authenticated partner requests and maps pending status', async () => {
    const result = await service.findMyVenueUpdateRequests('partner-1');
    expect(prisma.partner_venue_update_requests.findMany).toHaveBeenCalledWith({
      where: { partner_id: 'partner-1' }, orderBy: { created_at: 'desc' },
    });
    expect(result[0]).toMatchObject({ id: 'request-1', status: 'pending', name: 'Updated Arena' });
    await expect(service.findMyVenueUpdateRequests('')).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('applies approved fields atomically and preserves unrelated live metadata', async () => {
    await service.approveVenueUpdateRequest('request-1', 'admin-1');
    expect(tx.venues.update).toHaveBeenCalledWith({ where: { id: 'venue-1' }, data: {
      name: 'Updated Arena', metadata: { commission: 12, bookingAccept: false,
        availability: { badminton: [] }, locationUrl: 'https://maps.app.goo.gl/example' },
    } });
    expect(tx.partner_venue_profiles.upsert).toHaveBeenCalledWith(expect.objectContaining({
      where: { venue_id: 'venue-1' }, update: expect.objectContaining({ display_name: 'Updated Arena', address_line_2: '' }),
    }));
    expect(tx.partner_venue_update_requests.update).toHaveBeenCalledWith({ where: { id: 'request-1' },
      data: expect.objectContaining({ status: 'APPROVED', reviewed_by: 'admin-1', reviewed_at: expect.any(Date) }) });
    expect(notify).toHaveBeenCalled();
  });

  it('rejects a request without changing the live venue and keeps review notes', async () => {
    const result = await service.rejectVenueUpdateRequest('request-1', { adminNotes: 'Please correct the location' }, 'admin-1');
    expect(result).toMatchObject({ status: 'rejected', adminNotes: 'Please correct the location' });
    expect(tx.partner_venue_update_requests.update).toHaveBeenCalledWith({ where: { id: 'request-1' },
      data: expect.objectContaining({ status: 'REJECTED', reviewed_by: 'admin-1' }) });
    expect(tx.venues.update).not.toHaveBeenCalled();
    expect(tx.partner_venue_profiles.upsert).not.toHaveBeenCalled();
    expect(notify).toHaveBeenCalled();
  });

  it('cannot review an already approved or rejected request', async () => {
    tx.partner_venue_update_requests.findUnique.mockResolvedValue({ ...record, status: 'APPROVED' });
    await expect(service.approveVenueUpdateRequest('request-1')).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.rejectVenueUpdateRequest('request-1', {})).rejects.toBeInstanceOf(BadRequestException);
    expect(tx.partner_venue_update_requests.update).not.toHaveBeenCalled();
  });

  it('validates the description limit, pin code, and location link', async () => {
    const invalid = plainToInstance(SubmitVenueUpdateDto, { description: 'a'.repeat(201), zipCode: 'abc', locationUrl: 'not a link' });
    expect((await validate(invalid)).map((error) => error.property)).toEqual(expect.arrayContaining(['description', 'zipCode', 'locationUrl']));
    expect(await validate(plainToInstance(SubmitVenueUpdateDto, { name: 'New Arena', description: 'Description',
      zipCode: '452010', locationUrl: 'https://maps.app.goo.gl/example', venuePhone: '+919876543210' }))).toEqual([]);
  });
});
