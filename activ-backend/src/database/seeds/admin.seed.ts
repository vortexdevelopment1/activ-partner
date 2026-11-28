import { randomUUID } from 'crypto';
import * as bcrypt from 'bcryptjs';

import type { PrismaClient } from '../../generated/prisma/client';

export async function seedAdmin(prisma: PrismaClient, { verifyCredentials = false } = {}) {
  if (verifyCredentials && (!process.env.ADMIN_EMAIL?.trim() || !process.env.ADMIN_PASSWORD || process.env.ADMIN_PASSWORD === 'Admin@123')) {
    throw new Error('Set ADMIN_EMAIL and a non-default ADMIN_PASSWORD before seeding.');
  }
  const email = process.env.ADMIN_EMAIL || 'admin@activ.com';
  const password = process.env.ADMIN_PASSWORD || 'Admin@123';
  const phone = process.env.ADMIN_PHONE_E164 || '+910000000000';
  const emailMatch = { email: { equals: email.trim(), mode: 'insensitive' as const } };
  const identity = { OR: [emailMatch, { phone_e164: phone }] };

  const existingAdmin = await prisma.users.findFirst({
    where: { is_admin: true, ...(verifyCredentials ? emailMatch : identity) },
    select: { status: true, password_hash: true },
  });

  if (existingAdmin) {
    if (verifyCredentials && (existingAdmin.status !== 'ACTIVE' || !existingAdmin.password_hash ||
        !await bcrypt.compare(password, existingAdmin.password_hash))) {
      throw new Error('The admin already exists, but is inactive or its password differs. No account changes were made.');
    }
    console.log('Admin user already exists.');
    return;
  }

  const conflictingUser = await prisma.users.findFirst({
    where: identity,
    select: { id: true },
  });

  if (conflictingUser) {
    throw new Error('Cannot seed admin: the configured email or phone belongs to another account.');
  }

  await prisma.users.create({
    data: {
      id: randomUUID(),
      phone_e164: phone,
      name: 'Super Admin',
      email: email.trim(),
      password_hash: await bcrypt.hash(password, 10),
      is_admin: true,
      updated_at: new Date(),
    },
  });

  console.log('Admin user created.');
}
