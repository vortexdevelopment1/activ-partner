import { ConflictException } from '@nestjs/common';
import { PartnersService } from './partners.service';

describe('PartnersService admin create', () => {
  const buildService = (tx: any) => Object.assign(
    Object.create(PartnersService.prototype),
    { prisma: { $transaction: (callback: (client: any) => unknown) => callback(tx) } },
  ) as PartnersService;

  it('creates the current user, partner, owner link and profile schema', async () => {
    const user = { id: 'user-id', phone_e164: '+918085886381', email: 'testing@yopmail.com' };
    const tx = {
      users: {
        findUnique: jest.fn().mockResolvedValue(null),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue(user),
        update: jest.fn(),
      },
      partners: { create: jest.fn().mockImplementation(({ data }) => Promise.resolve({
        ...data, created_at: new Date(),
      })) },
      partner_users: { findFirst: jest.fn(), create: jest.fn().mockResolvedValue({}) },
      partner_business_profiles: { create: jest.fn().mockResolvedValue({}) },
    };

    const result = await buildService(tx).create({
      phone: '8085886381', firstName: 'Testing', lastName: 'Data', email: 'Testing@Yopmail.com',
    });

    expect(tx.users.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      phone_e164: '+918085886381', name: 'Testing Data', email: 'testing@yopmail.com',
    }) });
    expect(tx.partners.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      legal_name: 'Testing Data', status: 'PENDING',
    }) });
    const createdPartnerId = tx.partners.create.mock.calls[0][0].data.id;
    expect(tx.partner_users.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      partner_id: createdPartnerId, user_id: 'user-id', role: 'PARTNER_ADMIN',
    }) });
    expect(tx.partner_business_profiles.create).toHaveBeenCalled();
    expect(result).toEqual(expect.objectContaining({ id: createdPartnerId, phone: '+918085886381' }));
  });

  it('returns a conflict when the phone already belongs to a partner', async () => {
    const tx = {
      users: {
        findUnique: jest.fn().mockResolvedValue({ id: 'user-id', phone_e164: '+918085886381' }),
        findFirst: jest.fn().mockResolvedValue(null),
      },
      partner_users: { findFirst: jest.fn().mockResolvedValue({ id: 'link-id' }) },
    };

    await expect(buildService(tx).create({ phone: '8085886381' }))
      .rejects.toBeInstanceOf(ConflictException);
  });
});
