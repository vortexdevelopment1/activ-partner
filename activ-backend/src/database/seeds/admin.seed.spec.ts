import * as bcrypt from 'bcryptjs';
import type { PrismaClient } from '../../generated/prisma/client';
import { seedAdmin } from './admin.seed';

describe('admin-only seed', () => {
  const originalEnvironment = process.env;
  const options = { verifyCredentials: true };
  const users = { findFirst: jest.fn(), create: jest.fn() };
  const prisma = { users } as unknown as PrismaClient;

  beforeEach(() => {
    jest.resetAllMocks();
    process.env = {
      ...originalEnvironment,
      ADMIN_EMAIL: 'admin@example.test',
      ADMIN_PASSWORD: 'test-password',
      ADMIN_PHONE_E164: '+919999999998',
    };
  });
  afterEach(() => { process.env = originalEnvironment; });

  it('requires an explicit non-default password before accessing users', async () => {
    process.env.ADMIN_PASSWORD = 'Admin@123';
    await expect(seedAdmin(prisma, options)).rejects.toThrow('non-default ADMIN_PASSWORD');
    expect(users.findFirst).not.toHaveBeenCalled();
  });

  it('creates an admin with a hashed password on an empty database', async () => {
    users.findFirst.mockResolvedValue(null);
    await seedAdmin(prisma, options);
    const { data } = users.create.mock.calls[0][0];
    expect(data).toMatchObject({ email: 'admin@example.test', is_admin: true });
    expect(await bcrypt.compare('test-password', data.password_hash)).toBe(true);
  });

  it('accepts the seed again for the same active admin and password', async () => {
    users.findFirst.mockResolvedValue({ status: 'ACTIVE', password_hash: await bcrypt.hash('test-password', 4) });
    await expect(seedAdmin(prisma, options)).resolves.toBeUndefined();
    expect(users.create).not.toHaveBeenCalled();
  });

  it('reports an existing password mismatch without writing to the database', async () => {
    users.findFirst.mockResolvedValue({ status: 'ACTIVE', password_hash: await bcrypt.hash('other-password', 4) });
    await expect(seedAdmin(prisma, options)).rejects.toThrow('its password differs');
    expect(users.create).not.toHaveBeenCalled();
  });

  it('refuses to take over an existing email or phone', async () => {
    users.findFirst.mockResolvedValueOnce(null).mockResolvedValueOnce({ id: 'other-user' });
    await expect(seedAdmin(prisma, options)).rejects.toThrow('belongs to another account');
    expect(users.create).not.toHaveBeenCalled();
  });
});
