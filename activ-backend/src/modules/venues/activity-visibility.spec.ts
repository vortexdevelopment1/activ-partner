import { syncLegacyActivityVisibility } from './activity-visibility';
import { VenuesService } from './venues.service';

describe('partner activity visibility in the consumer catalogue', () => {
  function setup(origin = 'in-app') {
    const venue = { id: 'venue', status: 'PUBLISHED', booking_accept: true };
    const rows = [{ id: 'service', venue_id: 'venue', facility_id: 'facility', activity_id: 'sport',
      status: 'APPROVED', is_active: true, origin }];
    const links = [{ venue_id: 'venue', activity_id: 'sport', status: 'APPROVED' }];
    const tx: any = {
      $queryRaw: jest.fn(), $queryRawUnsafe: jest.fn(),
      venues: { findUnique: jest.fn(async () => venue), updateMany: jest.fn().mockResolvedValue({ count: 0 }) },
      partner_venue_services: {
        findUniqueOrThrow: jest.fn(async () => rows[0]),
        findMany: jest.fn(async ({ where }) => rows.filter(row => row.status === where.status && row.is_active === where.is_active)),
        update: jest.fn(async ({ data }) => Object.assign(rows[0], data)),
        count: jest.fn(async ({ where }) => rows.filter(row =>
          row.venue_id === where.venue_id && (!where.facilities || row.activity_id === where.facilities.activity_id) &&
          (!where.status || (typeof where.status === 'object' ? row.status !== where.status.not : row.status === where.status)) &&
          (where.is_active === undefined || row.is_active === where.is_active)).length),
      },
      venue_activities: {
        findMany: jest.fn(async () => links),
        updateMany: jest.fn(async ({ where, data }) => { const link = links.find(link => link.activity_id === where.activity_id); if (link) Object.assign(link, data); }),
      },
      slots: { findMany: jest.fn().mockResolvedValue([{ id: 'slot' }]), updateMany: jest.fn(), createMany: jest.fn() },
      partner_service_paused_slots: { createMany: jest.fn(), findMany: jest.fn().mockResolvedValue([{ slot_id: 'slot' }]), deleteMany: jest.fn() },
      facilities: {}, activities: { findFirst: jest.fn() },
    };
    const prisma = { ...tx, $transaction: jest.fn(async callback => callback(tx)) };
    const service = Object.assign(Object.create(VenuesService.prototype), { prisma,
      findManagedActivity: jest.fn(async () => ({ ...rows[0], title: 'Sport', venues: { name: 'Arena' } })),
      adminNotificationsService: { notify: jest.fn() },
    }) as VenuesService;
    return { venue, rows, links, tx, prisma, service };
  }

  it.each(['onboarding', 'in-app'])('hides a paused %s activity and restores only its venue link on resume', async origin => {
    const { rows, links, tx, service } = setup(origin);
    await service.updateActivityManagement('service', 'partner', { isActive: false, reason: 'Maintenance' });
    expect(rows[0].is_active).toBe(false);
    expect(links[0].status).toBe('ARCHIVED');
    expect(tx.slots.updateMany).toHaveBeenCalledWith(expect.objectContaining({ data: { status: 'BLOCKED' } }));
    await service.updateActivityManagement('service', 'partner', { isActive: true });
    expect(rows[0].is_active).toBe(true);
    expect(links[0].status).toBe('APPROVED');
    expect(tx.activities).not.toHaveProperty('update');
  });

  it('retains the venue sport when another approved, active activity uses it', async () => {
    const { rows, links, service } = setup();
    rows.push({ ...rows[0], id: 'other-court' });
    await service.updateActivityManagement('service', 'partner', { isActive: false, reason: 'Maintenance' });
    expect(links[0].status).toBe('APPROVED');
    expect(rows[1].is_active).toBe(true);
  });

  it.each(['DRAFT', 'PENDING', 'REJECTED', 'ARCHIVED'])('does not publish %s activities even with is_active true', async status => {
    const { rows, links, tx } = setup();
    rows[0].status = status;
    await syncLegacyActivityVisibility(tx, 'venue');
    expect(links[0].status).toBe('ARCHIVED');
  });

  it('hides active activities while venue bookings are paused', async () => {
    const { venue, links, tx } = setup();
    venue.booking_accept = false;
    await syncLegacyActivityVisibility(tx, 'venue');
    expect(links[0].status).toBe('ARCHIVED');
  });

  it('schedule generation excludes inactive services and repairs their stale approved links', async () => {
    const { rows, links, tx, prisma, service } = setup();
    rows[0].is_active = false;
    await (service as any).syncLegacyActivitySlots('venue');
    expect(tx.partner_venue_services.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: {
      venue_id: 'venue', status: 'APPROVED', is_active: true,
    } }));
    expect(links[0].status).toBe('ARCHIVED');
    expect(tx.slots.createMany).not.toHaveBeenCalled();
    expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Function), { maxWait: 10000, timeout: 60000 });
    expect(tx.$queryRaw).toHaveBeenCalled();
  });

  it('leaves consumer-only activities without a partner service untouched', async () => {
    const { rows, links, tx } = setup(); rows.length = 0;
    await syncLegacyActivityVisibility(tx, 'venue');
    expect(links[0].status).toBe('APPROVED');
    expect(tx.venue_activities.updateMany).not.toHaveBeenCalled();
  });
});
