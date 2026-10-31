import { ConflictException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { PartnersService } from './partners.service';

describe('PartnersService admin create', () => {
  const buildService = (tx: any, mailService?: any) => Object.assign(
    Object.create(PartnersService.prototype),
    { prisma: { $transaction: (callback: (client: any) => unknown) => callback(tx) },
      adminNotificationsService: { notify: jest.fn().mockResolvedValue(undefined) },
      mailService: mailService || { sendPartnerInvitationEmail: jest.fn().mockResolvedValue(true) } },
  ) as PartnersService;

  it('creates the current user, partner, owner link and profile schema with password and sends invitation email', async () => {
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
    const mailService = { sendPartnerInvitationEmail: jest.fn().mockResolvedValue(true) };

    const result = await buildService(tx, mailService).create({
      phone: '8085886381', firstName: 'Testing', lastName: 'Data', email: 'Testing@Yopmail.com', businessName: 'Testing Arena',
    });

    expect(tx.users.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      phone_e164: '+918085886381', name: 'Testing Data', email: 'testing@yopmail.com',
      password_hash: expect.any(String),
    }) });
    const createdPasswordHash = tx.users.create.mock.calls[0][0].data.password_hash;
    expect(await bcrypt.compare(result.temporaryPassword, createdPasswordHash)).toBe(true);

    expect(tx.partners.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      legal_name: 'Testing Arena', status: 'PENDING',
    }) });
    const createdPartnerId = tx.partners.create.mock.calls[0][0].data.id;
    expect(tx.partner_users.create).toHaveBeenCalledWith({ data: expect.objectContaining({
      partner_id: createdPartnerId, user_id: 'user-id', role: 'PARTNER_ADMIN',
    }) });
    expect(tx.partner_business_profiles.create).toHaveBeenCalled();
    expect(result).toEqual(expect.objectContaining({ id: createdPartnerId, phone: '+918085886381' }));

    expect(mailService.sendPartnerInvitationEmail).toHaveBeenCalledWith({
      toEmail: 'testing@yopmail.com',
      partnerName: 'Testing Data',
      businessName: 'Testing Arena',
      phone: '+918085886381',
      password: result.temporaryPassword,
      deliveryKey: `partner-invite:${createdPartnerId}`,
    });
  });

  it('updates existing user without password with a new temporary password and sends invite', async () => {
    const existingUser = { id: 'existing-id', phone_e164: '+918085886381', email: 'old@yopmail.com', password_hash: null };
    const tx = {
      users: {
        findUnique: jest.fn().mockResolvedValue(existingUser),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
        update: jest.fn().mockResolvedValue({ ...existingUser, email: 'new@yopmail.com' }),
      },
      partners: { create: jest.fn().mockImplementation(({ data }) => Promise.resolve({
        ...data, created_at: new Date(),
      })) },
      partner_users: { findFirst: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue({}) },
      partner_business_profiles: { create: jest.fn().mockResolvedValue({}) },
    };
    const mailService = { sendPartnerInvitationEmail: jest.fn().mockResolvedValue(true) };

    const result = await buildService(tx, mailService).create({
      phone: '8085886381', firstName: 'John', lastName: 'Doe', email: 'new@yopmail.com',
    });

    expect(tx.users.update).toHaveBeenCalledWith({
      where: { id: 'existing-id' },
      data: expect.objectContaining({
        password_hash: expect.any(String),
        email: 'new@yopmail.com',
      }),
    });
    expect(result.temporaryPassword).toBeDefined();
    expect(mailService.sendPartnerInvitationEmail).toHaveBeenCalledWith(expect.objectContaining({
      toEmail: 'new@yopmail.com',
      password: result.temporaryPassword,
    }));
  });

  it('preserves existing password if user already has a password_hash', async () => {
    const existingUser = { id: 'existing-id', phone_e164: '+918085886381', email: 'existing@yopmail.com', password_hash: '$2a$10$existingHash' };
    const tx = {
      users: {
        findUnique: jest.fn().mockResolvedValue(existingUser),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
        update: jest.fn().mockResolvedValue(existingUser),
      },
      partners: { create: jest.fn().mockImplementation(({ data }) => Promise.resolve({
        ...data, created_at: new Date(),
      })) },
      partner_users: { findFirst: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue({}) },
      partner_business_profiles: { create: jest.fn().mockResolvedValue({}) },
    };
    const mailService = { sendPartnerInvitationEmail: jest.fn().mockResolvedValue(true) };

    const result = await buildService(tx, mailService).create({
      phone: '8085886381', firstName: 'John', lastName: 'Doe', email: 'existing@yopmail.com',
    });

    expect(tx.users.update).toHaveBeenCalledWith({
      where: { id: 'existing-id' },
      data: expect.not.objectContaining({
        password_hash: expect.anything(),
      }),
    });
    expect(result.temporaryPassword).toBeUndefined();
    expect(mailService.sendPartnerInvitationEmail).toHaveBeenCalledWith(expect.objectContaining({
      toEmail: 'existing@yopmail.com',
      password: undefined,
    }));
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
