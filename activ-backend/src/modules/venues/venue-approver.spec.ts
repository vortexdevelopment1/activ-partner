import { VenuesService } from './venues.service';

describe('admin venue approver display', () => {
  let service: VenuesService;
  let users: any;
  let review: any;

  beforeEach(() => {
    review = { status: 'PUBLISHED', approved_by: 'admin-1', partner_venue_legal_documents: null };
    users = { findUnique: jest.fn().mockResolvedValue({ name: ' Super Admin ' }) };
    service = Object.assign(Object.create(VenuesService.prototype), {
      findOne: jest.fn().mockResolvedValue({ id: 'venue-1', status: 'approved', partner: {} }),
      prisma: { venues: { findUnique: jest.fn(async () => review) }, users },
    });
  });

  it('includes the display name while preserving the audit ID', async () => {
    expect(await service.findAdminVenue('venue-1')).toMatchObject({ approvedBy: 'admin-1', approvedByName: 'Super Admin' });
    expect(users.findUnique).toHaveBeenCalledWith({ where: { id: 'admin-1' }, select: { name: true } });
  });

  it('handles deleted or unnamed approving admins without using their ID as a name', async () => {
    users.findUnique.mockResolvedValue(null);
    expect((await service.findAdminVenue('venue-1')).approvedByName).toBeNull();
    users.findUnique.mockResolvedValue({ name: ' ' });
    expect((await service.findAdminVenue('venue-1')).approvedByName).toBeNull();
  });

  it('does not fetch an admin when the venue has no approval', async () => {
    review.approved_by = null;
    expect((await service.findAdminVenue('venue-1')).approvedByName).toBeNull();
    expect(users.findUnique).not.toHaveBeenCalled();
  });
});
