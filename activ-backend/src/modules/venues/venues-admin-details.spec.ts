import { Injectable, INestApplication, NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { PassportModule, PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { VenuesController } from './venues.controller';
import { VenuesService } from './venues.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';

const secret = 'admin-venue-details-test-only';
const pendingId = 'fe9d8236-e7d7-47d1-9022-41e1fde9b2ec';
const approvedId = '11111111-1111-4111-8111-111111111111';
const missingId = '22222222-2222-4222-8222-222222222222';

@Injectable()
class TestJwtStrategy extends PassportStrategy(Strategy) {
  constructor() {
    super({ jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(), secretOrKey: secret });
  }
  validate(payload: { role: string }) {
    return { id: 'test-user', role: payload.role };
  }
}

describe('admin venue detail access', () => {
  let app: INestApplication;
  let url: string;
  let service: VenuesService;
  let reviews: Record<string, any>;
  const submitted = new Date('2026-10-08T12:55:40.731Z');
  const token = (role: string) => new JwtService({ secret }).sign({ role }, { expiresIn: '5m' });
  const request = (path: string, role?: string) => fetch(`${url}/venues/${path}`, {
    headers: role ? { Authorization: `Bearer ${token(role)}` } : {},
  });

  beforeAll(async () => {
    service = Object.assign(Object.create(VenuesService.prototype), {
      prisma: { venues: { findUnique: jest.fn(async ({ where }) => reviews[where.id] ?? null) } },
      findOne: jest.fn(async (id: string) => {
        const review = reviews[id];
        if (!review) throw new NotFoundException('Venue not found');
        return { id, partnerId: 'partner', name: 'Arena',
          status: review.status === 'PUBLISHED' ? 'approved' : 'draft', bookingAccept: true,
          partner: { email: 'owner@example.com' }, electronicSignature: 'private-signature',
          termsAccepted: true, termsAcceptedAt: submitted,
          services: [{ id: 'activity', categoryId: 'category', status: 'approved', isActive: true },
            { id: 'draft-activity', categoryId: 'draft-category', status: 'draft', isActive: true }],
          categories: [{ id: 'category' }, { id: 'draft-category' }],
          images: [{ venueServiceId: 'activity' }, { venueServiceId: 'draft-activity' }],
          availability: { category: [], 'draft-category': [] } };
      }),
      getVenueStats: jest.fn(async () => ({ total: 2 })),
    });
    const module = await Test.createTestingModule({
      imports: [PassportModule], controllers: [VenuesController],
      providers: [TestJwtStrategy, JwtAuthGuard, RolesGuard, { provide: VenuesService, useValue: service }],
    }).compile();
    app = module.createNestApplication();
    await app.listen(0, '127.0.0.1');
    url = await app.getUrl();
  });

  beforeEach(() => {
    reviews = {
      [pendingId]: { status: 'DRAFT', submitted_at: submitted, approved_at: null,
        approved_by: null, rejection_reason: null, review_status: null,
        partner_venue_legal_documents: { aadhaar_name: 'Owner', aadhaar_number: 'test-aadhaar',
          aadhaar_card_url: '/aadhaar.jpg', pan_number: 'test-pan', pan_card_url: '/pan.jpg',
          gst_number: 'test-gst', gst_name: 'Company', gstin_doc_url: '/gst.jpg' } },
      [approvedId]: { status: 'PUBLISHED', submitted_at: submitted, approved_at: submitted,
        approved_by: 'admin', rejection_reason: null, partner_venue_legal_documents: null },
    };
  });

  afterAll(async () => { await app?.close(); });

  it('returns submitted pending details and normalized legal documents to admins', async () => {
    const response = await request(`admin/${pendingId}`, 'admin');
    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body.data).toMatchObject({ id: pendingId, status: 'pending', submittedAt: submitted.toISOString(),
      electronicSignature: 'private-signature', termsAccepted: true,
      partner: { email: 'owner@example.com', aadhaarNumber: 'test-aadhaar', panCardUrl: '/pan.jpg', gstinDocUrl: '/gst.jpg' } });
    expect(reviews[pendingId].status).toBe('DRAFT');
  });

  it('keeps an unsubmitted draft a draft', async () => {
    reviews[pendingId].submitted_at = null;
    expect((await service.findAdminVenue(pendingId)).status).toBe('draft');
  });

  it('returns approval timestamps and permits venues without legal documents', async () => {
    const venue = await service.findAdminVenue(approvedId);
    expect(venue).toMatchObject({ status: 'approved', approvedAt: submitted, approvedBy: 'admin' });
    expect(venue.partner.panNumber).toBeNull();
  });

  it('returns rejected and suspended venues for admin review', async () => {
    reviews[pendingId].status = 'ARCHIVED';
    reviews[pendingId].review_status = 'suspended';
    reviews[pendingId].rejection_reason = 'Under review';
    expect(await service.findAdminVenue(pendingId)).toMatchObject({ status: 'suspended', rejectionReason: 'Under review' });
  });

  it('rejects unauthenticated access', async () => {
    expect((await request(`admin/${pendingId}`)).status).toBe(401);
  });

  it.each(['partner', 'team_member', 'user'])('rejects %s access', async (role) => {
    expect((await request(`admin/${pendingId}`, role)).status).toBe(403);
  });

  it('returns a genuine 404 for a missing venue', async () => {
    expect((await request(`admin/${missingId}`, 'admin')).status).toBe(404);
  });

  it('rejects an invalid venue UUID', async () => {
    expect((await request('admin/not-a-uuid', 'admin')).status).toBe(400);
  });

  it('does not shadow the existing static admin stats route', async () => {
    const response = await request('admin/stats', 'admin');
    expect(response.status).toBe(200);
    expect((await response.json()).data).toEqual({ total: 2 });
  });

  it('continues to hide pending venues on the public endpoint, even from admins', async () => {
    expect((await request(pendingId)).status).toBe(404);
    expect((await request(pendingId, 'admin')).status).toBe(404);
  });

  it('returns sanitized approved public details without private or draft activity data', async () => {
    const response = await request(approvedId);
    expect(response.status).toBe(200);
    const data = (await response.json()).data;
    expect(data).not.toHaveProperty('partner');
    expect(data).not.toHaveProperty('electronicSignature');
    expect(data).not.toHaveProperty('termsAcceptedAt');
    expect(data.services.map((activity) => activity.id)).toEqual(['activity']);
    expect(data.images).toHaveLength(1);
    expect(Object.keys(data.availability)).toEqual(['category']);
  });

  it('continues to hide venues not accepting bookings from public users', async () => {
    const findOne = service.findOne.bind(service);
    const publicService = Object.assign(Object.create(VenuesService.prototype), {
      findOne: async (id: string) => ({ ...await findOne(id), bookingAccept: false }),
    });
    await expect(publicService.findPublicVenue(approvedId)).rejects.toThrow('Venue not available');
  });
});
