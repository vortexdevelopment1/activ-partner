import { randomUUID } from 'crypto';
import * as bcrypt from 'bcryptjs';

import {
  PartnerRole,
  PartnerStatus,
  UserStatus,
  type PrismaClient,
} from '../../generated/prisma/client';

export async function seedPartner(prisma: PrismaClient) {
  const email = process.env.PARTNER_EMAIL || 'partner@activ.com';
  const password = process.env.PARTNER_PASSWORD || 'Partner@123';
  const phone = process.env.PARTNER_PHONE_E164 || '+919999999999';
  const businessName = process.env.PARTNER_BUSINESS_NAME || 'Activ Demo Partner';
  const now = new Date();

  let user = await prisma.users.findFirst({
    where: { OR: [{ email }, { phone_e164: phone }] },
  });

  if (user && user.email !== email && user.phone_e164 !== phone) {
    throw new Error('Partner seed email or phone conflicts with another user.');
  }

  if (user) {
    user = await prisma.users.update({
      where: { id: user.id },
      data: {
        email,
        phone_e164: phone,
        name: 'Demo Partner',
        password_hash: await bcrypt.hash(password, 10),
        status: UserStatus.ACTIVE,
        updated_at: now,
      },
    });
  } else {
    user = await prisma.users.create({
      data: {
        id: randomUUID(),
        email,
        phone_e164: phone,
        name: 'Demo Partner',
        password_hash: await bcrypt.hash(password, 10),
        status: UserStatus.ACTIVE,
        updated_at: now,
      },
    });
  }

  const existingLink = await prisma.partner_users.findFirst({
    where: { user_id: user.id },
    include: { partners: true },
  });

  let partnerId: string;
  if (existingLink) {
    partnerId = existingLink.partner_id;
    await prisma.partners.update({
      where: { id: partnerId },
      data: { legal_name: businessName, status: PartnerStatus.ACTIVE, updated_at: now },
    });
    await prisma.partner_users.update({
      where: { id: existingLink.id },
      data: { role: PartnerRole.PARTNER_ADMIN },
    });
  } else {
    partnerId = randomUUID();
    await prisma.partners.create({
      data: {
        id: partnerId,
        legal_name: businessName,
        status: PartnerStatus.ACTIVE,
        updated_at: now,
      },
    });
    await prisma.partner_users.create({
      data: {
        id: randomUUID(),
        partner_id: partnerId,
        user_id: user.id,
        role: PartnerRole.PARTNER_ADMIN,
      },
    });
  }

  await prisma.partner_business_profiles.upsert({
    where: { partner_id: partnerId },
    create: {
      id: randomUUID(),
      partner_id: partnerId,
      business_name: businessName,
      owner_name: user.name,
      phone_e164: phone,
      email,
      updated_at: now,
    },
    update: {
      business_name: businessName,
      owner_name: user.name,
      phone_e164: phone,
      email,
      updated_at: now,
    },
  });

  console.log(`Partner login ready: ${email}`);
}
