import { randomUUID } from 'crypto';
import * as bcrypt from 'bcryptjs';

import type { PrismaClient } from '../../generated/prisma/client';

export async function seedAdmin(prisma: PrismaClient) {
  const email = process.env.ADMIN_EMAIL || 'admin@activ.com';
  const password = process.env.ADMIN_PASSWORD || 'Admin@123';
  const phone = process.env.ADMIN_PHONE_E164 || '+910000000000';

  const existingAdmin = await prisma.users.findFirst({
    where: {
      is_admin: true,
      OR: [{ email }, { phone_e164: phone }],
    },
  });

  if (existingAdmin) {
    console.log(`Admin user already exists: ${email}`);
    return;
  }

  const conflictingUser = await prisma.users.findFirst({
    where: { OR: [{ email }, { phone_e164: phone }] },
  });

  if (conflictingUser) {
    throw new Error(
      `Cannot seed admin: ${email} or ${phone} belongs to a non-admin user.`,
    );
  }

  await prisma.users.create({
    data: {
      id: randomUUID(),
      phone_e164: phone,
      name: 'Super Admin',
      email,
      password_hash: await bcrypt.hash(password, 10),
      is_admin: true,
      updated_at: new Date(),
    },
  });

  console.log(`Admin user created: ${email}`);
}
