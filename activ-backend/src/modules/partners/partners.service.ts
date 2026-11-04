import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
  UnauthorizedException,
} from '@nestjs/common';
import { randomInt, randomUUID } from 'crypto';
import * as bcrypt from 'bcryptjs';
import type { PartnerRecord as Partner } from '../../common/domain-types';
import { GstVerificationRequestRecord as GstVerificationRequest, GstVerificationStatus } from '../../common/domain-types';
import { SubmitGstVerificationDto } from './dto/submit-gst-verification.dto';
import { ReviewGstVerificationDto } from './dto/review-gst-verification.dto';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { CreatePartnerDto } from './dto/create-partner.dto';
import { AdminUpdatePartnerDto } from './dto/admin-update-partner.dto';
import { UpdatePartnerDto } from './dto/update-partner.dto';
import { AdminNotificationsService } from '../admin-notifications/admin-notifications.service';
import { AdminNotificationType } from '../../common/domain-types';
import { PrismaService } from '../../prisma/prisma.service';
import { deletePartnerAccount } from './delete-partner-account';
import { MailService } from '../mail/mail.service';
import { PartnerKycStatus, PartnerRole, PartnerStatus, UserStatus } from '../../generated/prisma/client';

@Injectable()
export class PartnersService {
  constructor(
    private readonly adminNotificationsService: AdminNotificationsService,
    private readonly prisma: PrismaService,
    private readonly mailService: MailService,
  ) {}

  async create(createPartnerDto: CreatePartnerDto): Promise<any> {
    if (!createPartnerDto.phone?.trim()) {
      throw new BadRequestException('Partner phone number is required');
    }

    const phone = this.normalizePhone(createPartnerDto.phone);
    const email = createPartnerDto.email?.trim().toLowerCase() || null;
    const fullName = [createPartnerDto.firstName, createPartnerDto.lastName]
      .map((value) => value?.trim())
      .filter(Boolean)
      .join(' ');
    const legalName = createPartnerDto.businessName?.trim() || fullName || 'Partner User';
    const now = new Date();

    try {
      const created = await this.prisma.$transaction(async (tx) => {
        const userWithPhone = await tx.users.findUnique({ where: { phone_e164: phone } });
        const userWithEmail = email
          ? await tx.users.findFirst({ where: { email: { equals: email, mode: 'insensitive' } } })
          : null;

        if (userWithEmail && userWithEmail.id !== userWithPhone?.id) {
          throw new ConflictException('A user with this email already exists');
        }

        if (userWithPhone) {
          const existingPartner = await tx.partner_users.findFirst({
            where: { user_id: userWithPhone.id },
          });
          if (existingPartner) {
            throw new ConflictException('A partner with this phone number already exists');
          }
        }

        const temporaryPassword = !userWithPhone?.password_hash ? this.generatePassword() : undefined;
        const passwordHash = temporaryPassword ? await bcrypt.hash(temporaryPassword, 10) : undefined;

        const user = userWithPhone
          ? await tx.users.update({
              where: { id: userWithPhone.id },
              data: {
                name: fullName || userWithPhone.name,
                email: email || userWithPhone.email,
                ...(passwordHash ? { password_hash: passwordHash } : {}),
                status: UserStatus.ACTIVE,
                updated_at: now,
              },
            })
          : await tx.users.create({
              data: {
                id: randomUUID(),
                phone_e164: phone,
                name: fullName || null,
                email,
                ...(passwordHash ? { password_hash: passwordHash } : {}),
                status: UserStatus.ACTIVE,
                updated_at: now,
              },
            });

        const partnerId = randomUUID();
        const partner = await tx.partners.create({
          data: {
            id: partnerId,
            legal_name: legalName,
            status: PartnerStatus.PENDING,
            updated_at: now,
          },
        });
        await tx.partner_users.create({
          data: {
            id: randomUUID(),
            partner_id: partnerId,
            user_id: user.id,
            role: PartnerRole.PARTNER_ADMIN,
          },
        });
        await tx.partner_business_profiles.create({
          data: {
            id: randomUUID(),
            partner_id: partnerId,
            business_name: createPartnerDto.businessName?.trim() || null,
            owner_name: fullName || null,
            phone_e164: phone,
            email,
            pan_number: createPartnerDto.panNumber?.trim() || null,
            gst_number: createPartnerDto.gstNumber?.trim() || null,
            address_line_1: createPartnerDto.businessAddress?.trim() || null,
            city: createPartnerDto.city?.trim() || null,
            state: createPartnerDto.state?.trim() || null,
            postal_code: createPartnerDto.zipCode?.trim() || null,
            updated_at: now,
          },
        });

        return {
          id: partner.id,
          userId: user.id,
          firstName: createPartnerDto.firstName?.trim() || null,
          lastName: createPartnerDto.lastName?.trim() || null,
          email: user.email,
          phone: user.phone_e164,
          businessName: createPartnerDto.businessName?.trim() || partner.legal_name,
          status: partner.status.toLowerCase(),
          isActive: partner.status === PartnerStatus.ACTIVE,
          temporaryPassword,
          createdAt: partner.created_at,
          updatedAt: partner.updated_at,
        };
      });
      await this.adminNotificationsService.notify(
        AdminNotificationType.PARTNER_REGISTERED,
        'New partner created',
        `${created.businessName || 'A partner'} was added to ACTIV.`,
        { partnerId: created.id },
      );

      if (created.email?.trim()) {
        try {
          await this.mailService?.sendPartnerInvitationEmail({
            toEmail: created.email.trim(),
            partnerName: fullName || created.businessName || 'Partner',
            businessName: created.businessName,
            phone: created.phone,
            password: created.temporaryPassword,
            deliveryKey: `partner-invite:${created.id}`,
          });
        } catch {
          // Email dispatch error should not fail partner creation
        }
      }

      return created;
    } catch (error: any) {
      if (error instanceof ConflictException || error instanceof BadRequestException) throw error;
      if (error?.code === 'P2002') {
        throw new ConflictException('A partner with this phone number or email already exists');
      }
      throw error;
    }
  }

  private generatePassword(): string {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    const special = '@#$!';
    let password = '';
    for (let i = 0; i < 8; i++) {
      password += chars.charAt(randomInt(chars.length));
    }
    password += special.charAt(randomInt(special.length));
    password += randomInt(10, 100);
    return password;
  }

  private normalizePhone(phone: string): string {
    const digits = phone.replace(/\D/g, '');
    if (digits.length === 10) return `+91${digits}`;
    if (digits.length === 12 && digits.startsWith('91')) return `+${digits}`;
    if (digits.length < 10 || digits.length > 15) {
      throw new BadRequestException('Enter a valid phone number');
    }
    return `+${digits}`;
  }

  async findAll(pagination: PaginationDto) {
    const where: any = pagination.search
      ? {
          OR: [
            { legal_name: { contains: pagination.search, mode: 'insensitive' } },
            {
              partner_business_profiles: {
                is: {
                  OR: [
                    { business_name: { contains: pagination.search, mode: 'insensitive' } },
                    { city: { contains: pagination.search, mode: 'insensitive' } },
                    { email: { contains: pagination.search, mode: 'insensitive' } },
                  ],
                },
              },
            },
          ],
        }
      : {};

    const [partners, total] = await Promise.all([
      this.prisma.partners.findMany({
        where,
        include: {
          partner_business_profiles: true,
          partner_users: { where: { role: PartnerRole.PARTNER_ADMIN }, include: { users: true } },
          _count: { select: { venues: true } },
        },
        skip: pagination.skip,
        take: pagination.limit,
        orderBy: { created_at: 'desc' },
      }),
      this.prisma.partners.count({ where }),
    ]);

    const items = partners.map((partner) => {
      const profile = partner.partner_business_profiles;
      const owner = partner.partner_users[0]?.users;
      const names = (owner?.name || '').trim().split(/\s+/);
      return {
        id: partner.id,
        userId: owner?.id ?? null,
        firstName: names[0] || null,
        lastName: names.slice(1).join(' ') || null,
        email: owner?.email ?? profile?.email ?? null,
        phone: owner?.phone_e164 ?? profile?.phone_e164 ?? null,
        businessName: profile?.business_name ?? partner.legal_name,
        businessAddress: profile?.address_line_1 ?? null,
        city: profile?.city ?? null,
        state: profile?.state ?? null,
        zipCode: profile?.postal_code ?? null,
        gstNumber: profile?.gst_number ?? null,
        panNumber: profile?.pan_number ?? null,
        isVerified: profile?.kyc_status === 'APPROVED',
        isActive: partner.status === 'ACTIVE',
        status: partner.status.toLowerCase(),
        venueCount: partner._count.venues,
        createdAt: partner.created_at,
        updatedAt: partner.updated_at,
      };
    });

    return [items, total] as const;
  }

  async findOne(id: string) {
    const partner = await this.prisma.partners.findUnique({
      where: { id },
      include: {
        partner_business_profiles: true,
        partner_bank_accounts: { orderBy: { created_at: 'desc' } },
        partner_users: {
          where: { role: PartnerRole.PARTNER_ADMIN },
          include: { users: true },
        },
        venues: {
          include: { partner_venue_legal_documents: true },
          take: 1,
        },
        _count: { select: { venues: true } },
      },
    });
    if (!partner) throw new NotFoundException(`Partner with id ${id} not found`);
    return this.mapPrismaPartner(partner);
  }

  private mapPrismaPartner(partner: any) {
    const profile = partner.partner_business_profiles;
    const owner = partner.partner_users?.[0]?.users;
    const legalDoc = partner.venues?.[0]?.partner_venue_legal_documents;
    const names = (owner?.name || '').trim().split(/\s+/);
    return {
      id: partner.id,
      legalName: partner.legal_name,
      avatarUrl: owner?.profile_photo ?? null,
      ownerName: profile?.owner_name ?? null,
      businessEmail: profile?.email ?? null,
      addressLine2: profile?.address_line_2 ?? null,
      kycStatus: profile?.kyc_status ?? PartnerKycStatus.PENDING,
      rejectionReason: profile?.rejection_reason ?? null,
      bankAccounts: (partner.partner_bank_accounts ?? []).map((bank: any) => ({
        id: bank.id, accountHolderName: bank.account_holder_name, bankName: bank.bank_name,
        accountNumber: bank.account_number, ifscCode: bank.ifsc_code, accountType: bank.account_type,
        branchName: bank.branch_name, cancelledChequeUrl: bank.cancelled_cheque_url, upiId: bank.upi_id,
        status: bank.status, isPrimary: bank.is_primary, rejectionReason: bank.rejection_reason,
      })),
      userId: owner?.id ?? null,
      firstName: names[0] || null,
      lastName: names.slice(1).join(' ') || null,
      email: owner?.email ?? profile?.email ?? null,
      phone: owner?.phone_e164 ?? profile?.phone_e164 ?? null,
      businessName: profile?.business_name ?? partner.legal_name,
      businessAddress: profile?.address_line_1 ?? null,
      city: profile?.city ?? null,
      state: profile?.state ?? null,
      zipCode: profile?.postal_code ?? null,
      gstNumber: profile?.gst_number ?? legalDoc?.gst_number ?? null,
      panNumber: profile?.pan_number ?? legalDoc?.pan_number ?? null,
      isVerified: profile?.kyc_status === 'APPROVED',
      isActive: partner.status === PartnerStatus.ACTIVE,
      status: partner.status.toLowerCase(),
      venueCount: partner._count?.venues ?? 0,
      createdAt: partner.created_at,
      updatedAt: partner.updated_at,
      // These fields existed only on the legacy entity. Keep stable keys for
      // old clients, but never invent values from unrelated tables.
      businessDescription: null,
      country: null,
      contactPhone: profile?.phone_e164 ?? owner?.phone_e164 ?? null,
      gstinDocUrl: profile?.gst_document_url ?? legalDoc?.gstin_doc_url ?? null,
      panCardUrl: profile?.pan_document_url ?? legalDoc?.pan_card_url ?? null,
      aadhaarName: legalDoc?.aadhaar_name ?? null,
      aadhaarNumber: legalDoc?.aadhaar_number ?? null,
      aadhaarCardUrl: legalDoc?.aadhaar_card_url ?? null,
      bankAccountNumber: null,
      bankIfscCode: null,
      bankAccountHolderName: null,
      logoUrl: null,
      documents: null,
    };
  }

  private mapPrismaGstVerification(request: any): GstVerificationRequest {
    return {
      id: request.id,
      partnerId: request.partner_id,
      gstNumber: request.gst_number,
      gstName: request.legal_name,
      gstDocUrl: request.document_url,
      status: String(request.status).toLowerCase() as GstVerificationStatus,
      adminNotes: request.rejection_reason,
      createdAt: request.created_at,
      updatedAt: request.updated_at,
    } as GstVerificationRequest;
  }

  async update(id: string, updatePartnerDto: AdminUpdatePartnerDto, reviewerId?: string): Promise<any> {
    if (updatePartnerDto.isActive !== undefined && Object.keys(updatePartnerDto).length === 1) {
      const previous = updatePartnerDto.isActive === false
        ? await this.prisma.partners.findUnique({ where: { id }, select: { status: true } })
        : null;
      const partner = await this.prisma.partners.update({
        where: { id },
        data: {
          status: updatePartnerDto.isActive
            ? PartnerStatus.ACTIVE
            : PartnerStatus.SUSPENDED,
          updated_at: new Date(),
        },
        include: {
          partner_business_profiles: true,
          partner_users: { include: { users: true } },
          _count: { select: { venues: true } },
        },
      });
      const mapped = this.mapPrismaPartner(partner);
      if (updatePartnerDto.isActive === false && previous?.status !== PartnerStatus.SUSPENDED) {
        const owner = partner.partner_users?.find((link) => link.role === 'PARTNER_ADMIN')?.users;
        await this.mailService.sendSuspensionEmail({
          deliveryKey: `partner-suspended:${id}:${partner.updated_at.toISOString()}`,
          toEmail: owner?.email || mapped.email,
          partnerName: owner?.name || [mapped.firstName, mapped.lastName].filter(Boolean).join(' ') || mapped.businessName,
        });
      }
      return mapped;
    }

    const unsupported = [
      'businessDescription', 'country', 'bankAccountNumber',
      'bankIfscCode', 'bankAccountHolderName',
    ].filter((field) => (updatePartnerDto as any)[field] !== undefined);
    if (unsupported.length > 0) {
      throw new BadRequestException(`Unsupported partner profile fields: ${unsupported.join(', ')}`);
    }

    if (updatePartnerDto.phone !== undefined && !updatePartnerDto.phone?.trim()) {
      throw new BadRequestException('Partner phone number is required');
    }
    if (updatePartnerDto.legalName !== undefined && !updatePartnerDto.legalName?.trim()) {
      throw new BadRequestException('Legal name is required');
    }
    const result = await this.prisma.$transaction(async (tx) => {
      const current = await tx.partners.findUnique({
        where: { id },
        include: {
          partner_business_profiles: true,
          partner_users: { where: { role: PartnerRole.PARTNER_ADMIN }, include: { users: true } },
        },
      });
      if (!current) throw new NotFoundException(`Partner with id ${id} not found`);
      const ownerLink = current.partner_users[0];
      if (!ownerLink) throw new NotFoundException('Partner owner not found');

      const currentName = (ownerLink.users.name || '').trim().split(/\s+/).filter(Boolean);
      const firstName = updatePartnerDto.firstName?.trim() ?? currentName[0] ?? '';
      const lastName = updatePartnerDto.lastName?.trim() ?? currentName.slice(1).join(' ');
      const nextName = [firstName, lastName].filter(Boolean).join(' ') || null;
      const nextEmail = updatePartnerDto.email === undefined ? undefined : updatePartnerDto.email?.trim().toLowerCase() || null;
      const nextPhone = updatePartnerDto.phone ? this.normalizePhone(updatePartnerDto.phone) : undefined;

      if (nextEmail && nextEmail !== (ownerLink.users.email || '').toLowerCase()) {
        const emailOwner = await tx.users.findFirst({
          where: { email: { equals: nextEmail, mode: 'insensitive' }, id: { not: ownerLink.user_id } },
          select: { id: true },
        });
        if (emailOwner) throw new ConflictException('Email is already registered');
      }
      if (nextPhone && nextPhone !== ownerLink.users.phone_e164) {
        const phoneOwner = await tx.users.findUnique({ where: { phone_e164: nextPhone }, select: { id: true } });
        if (phoneOwner && phoneOwner.id !== ownerLink.user_id) throw new ConflictException('Phone number is already registered');
      }

      const profileFields: Record<string, any> = {};
      const fields = {
        gstNumber: 'gst_number', panNumber: 'pan_number', gstinDocUrl: 'gst_document_url',
        panCardUrl: 'pan_document_url', addressLine2: 'address_line_2', ownerName: 'owner_name',
        contactPhone: 'phone_e164', businessEmail: 'email', rejectionReason: 'rejection_reason',
      };
      for (const [key, column] of Object.entries(fields)) {
        if (updatePartnerDto[key] !== undefined) profileFields[column] = updatePartnerDto[key]?.trim() || null;
      }
      const kycStatus = updatePartnerDto.kycStatus ?? (updatePartnerDto.isVerified === undefined
        ? undefined : updatePartnerDto.isVerified ? PartnerKycStatus.APPROVED : PartnerKycStatus.PENDING);
      if (kycStatus !== undefined) {
        Object.assign(profileFields, { kyc_status: kycStatus, reviewed_by: reviewerId ?? null, reviewed_at: new Date() });
      }
      const user = await tx.users.update({
        where: { id: ownerLink.user_id },
        data: {
          name: nextName,
          ...(updatePartnerDto.avatarUrl !== undefined ? { profile_photo: updatePartnerDto.avatarUrl?.trim() || null } : {}),
          ...(nextEmail !== undefined ? { email: nextEmail } : {}),
          ...(nextPhone !== undefined ? { phone_e164: nextPhone } : {}),
          updated_at: new Date(),
        },
      });
      const profile = await tx.partner_business_profiles.upsert({
        where: { partner_id: id },
        create: {
          id: randomUUID(), partner_id: id,
          business_name: updatePartnerDto.businessName?.trim() || current.legal_name,
          owner_name: nextName, email: nextEmail ?? user.email, phone_e164: nextPhone ?? user.phone_e164,
          address_line_1: updatePartnerDto.businessAddress?.trim() || null,
          city: updatePartnerDto.city?.trim() || null, state: updatePartnerDto.state?.trim() || null,
          postal_code: updatePartnerDto.zipCode?.trim() || null, ...profileFields, updated_at: new Date(),
        },
        update: {
          ...(updatePartnerDto.businessName !== undefined ? { business_name: updatePartnerDto.businessName.trim() } : {}),
          ...(updatePartnerDto.firstName !== undefined || updatePartnerDto.lastName !== undefined ? { owner_name: nextName } : {}),
          ...(nextEmail !== undefined ? { email: nextEmail } : {}),
          ...(nextPhone !== undefined ? { phone_e164: nextPhone } : {}),
          ...(updatePartnerDto.businessAddress !== undefined ? { address_line_1: updatePartnerDto.businessAddress.trim() } : {}),
          ...(updatePartnerDto.city !== undefined ? { city: updatePartnerDto.city.trim() } : {}),
          ...(updatePartnerDto.state !== undefined ? { state: updatePartnerDto.state.trim() } : {}),
          ...(updatePartnerDto.zipCode !== undefined ? { postal_code: updatePartnerDto.zipCode.trim() } : {}),
          ...profileFields,
          updated_at: new Date(),
        },
      });
      const partner = await tx.partners.update({
        where: { id },
        data: {
          ...(updatePartnerDto.legalName !== undefined ? { legal_name: updatePartnerDto.legalName.trim() }
            : !reviewerId && updatePartnerDto.businessName?.trim() ? { legal_name: updatePartnerDto.businessName.trim() } : {}),
          ...(updatePartnerDto.status !== undefined ? { status: updatePartnerDto.status }
            : updatePartnerDto.isActive !== undefined ? { status: updatePartnerDto.isActive ? PartnerStatus.ACTIVE : PartnerStatus.SUSPENDED } : {}),
          updated_at: new Date(),
        },
      });
      if (tx.venues && (updatePartnerDto.aadhaarNumber !== undefined || updatePartnerDto.aadhaarCardUrl !== undefined || (updatePartnerDto as any).aadhaarName !== undefined || updatePartnerDto.panNumber !== undefined || updatePartnerDto.gstNumber !== undefined || updatePartnerDto.panCardUrl !== undefined || updatePartnerDto.gstinDocUrl !== undefined)) {
        const rawAadhaar = updatePartnerDto.aadhaarNumber !== undefined ? (updatePartnerDto.aadhaarNumber ? updatePartnerDto.aadhaarNumber.trim().replace(/-/g, '') : null) : undefined;
        const rawAadhaarUrl = updatePartnerDto.aadhaarCardUrl !== undefined ? (updatePartnerDto.aadhaarCardUrl ? updatePartnerDto.aadhaarCardUrl.trim() : null) : undefined;
        const rawAadhaarName = (updatePartnerDto as any).aadhaarName !== undefined ? ((updatePartnerDto as any).aadhaarName ? (updatePartnerDto as any).aadhaarName.trim() : null) : undefined;
        const partnerVenues = await tx.venues.findMany({
          where: { partner_id: id },
          select: { id: true },
        });
        const now = new Date();
        for (const venue of partnerVenues) {
          if (tx.partner_venue_legal_documents) {
            await tx.partner_venue_legal_documents.upsert({
              where: { venue_id: venue.id },
              create: {
                venue_id: venue.id,
                ...(rawAadhaar !== undefined ? { aadhaar_number: rawAadhaar } : {}),
                ...(rawAadhaarUrl !== undefined ? { aadhaar_card_url: rawAadhaarUrl } : {}),
                ...(rawAadhaarName !== undefined ? { aadhaar_name: rawAadhaarName } : {}),
                ...(updatePartnerDto.panNumber !== undefined ? { pan_number: updatePartnerDto.panNumber.trim() || null } : {}),
                ...(updatePartnerDto.gstNumber !== undefined ? { gst_number: updatePartnerDto.gstNumber.trim() || null } : {}),
                ...(updatePartnerDto.panCardUrl !== undefined ? { pan_card_url: updatePartnerDto.panCardUrl.trim() || null } : {}),
                ...(updatePartnerDto.gstinDocUrl !== undefined ? { gstin_doc_url: updatePartnerDto.gstinDocUrl.trim() || null } : {}),
                updated_at: now,
              },
              update: {
                ...(rawAadhaar !== undefined ? { aadhaar_number: rawAadhaar } : {}),
                ...(rawAadhaarUrl !== undefined ? { aadhaar_card_url: rawAadhaarUrl } : {}),
                ...(rawAadhaarName !== undefined ? { aadhaar_name: rawAadhaarName } : {}),
                ...(updatePartnerDto.panNumber !== undefined ? { pan_number: updatePartnerDto.panNumber.trim() || null } : {}),
                ...(updatePartnerDto.gstNumber !== undefined ? { gst_number: updatePartnerDto.gstNumber.trim() || null } : {}),
                ...(updatePartnerDto.panCardUrl !== undefined ? { pan_card_url: updatePartnerDto.panCardUrl.trim() || null } : {}),
                ...(updatePartnerDto.gstinDocUrl !== undefined ? { gstin_doc_url: updatePartnerDto.gstinDocUrl.trim() || null } : {}),
                updated_at: now,
              },
            });
          }
        }
      }
      if (updatePartnerDto.bankAccounts) {
        if (updatePartnerDto.bankAccounts.filter(bank => bank.isPrimary).length > 1) {
          throw new BadRequestException('Only one bank account can be primary');
        }
        if (new Set(updatePartnerDto.bankAccounts.filter(b => b.id).map(b => b.id)).size !== updatePartnerDto.bankAccounts.filter(b => b.id).length) {
          throw new BadRequestException('Duplicate bank account IDs');
        }
        for (const bank of updatePartnerDto.bankAccounts) {
          if (![bank.accountHolderName, bank.bankName, bank.accountNumber, bank.ifscCode].every(value => value?.trim())) {
            throw new BadRequestException('Bank account holder, bank name, account number and IFSC are required');
          }
          const existing = bank.id ? await tx.partner_bank_accounts.findFirst({ where: { id: bank.id, partner_id: id } }) : null;
          if (bank.id && !existing) {
            throw new BadRequestException('Bank account does not belong to this partner');
          }
          const data = {
            account_holder_name: bank.accountHolderName.trim(), bank_name: bank.bankName.trim(),
            account_number: bank.accountNumber.trim(), ifsc_code: bank.ifscCode.trim().toUpperCase(),
            account_type: bank.accountType?.trim() || null, branch_name: bank.branchName?.trim() || null,
            cancelled_cheque_url: bank.cancelledChequeUrl?.trim() || null, upi_id: bank.upiId?.trim() || null,
            status: bank.status, is_primary: bank.isPrimary, rejection_reason: bank.rejectionReason?.trim() || null,
            ...(existing?.status !== bank.status ? { reviewed_by: reviewerId ?? null, reviewed_at: new Date(), has_seen_verified_screen: false } : {}),
            updated_at: new Date(),
          };
          if (bank.isPrimary) await tx.partner_bank_accounts.updateMany({ where: { partner_id: id }, data: { is_primary: false } });
          if (bank.id) await tx.partner_bank_accounts.update({ where: { id: bank.id }, data });
          else await tx.partner_bank_accounts.create({ data: { ...data, id: randomUUID(), partner_id: id } });
        }
      }
      return { partner, user, profile, previousStatus: current.status };
    });

    const saved = await this.findOne(id);
    if (saved.status === 'suspended' && result.previousStatus !== PartnerStatus.SUSPENDED) {
      await this.mailService.sendSuspensionEmail({
        deliveryKey: `partner-suspended:${id}:${result.partner.updated_at.toISOString()}`,
        toEmail: saved.email, partnerName: [saved.firstName, saved.lastName].filter(Boolean).join(' ') || saved.businessName,
      });
    }
    return saved;
  }

  async updateOwnProfile(id: string, updatePartnerDto: UpdatePartnerDto): Promise<Partner> {
    if (['isActive', 'isVerified', 'status', 'kycStatus', 'bankAccounts', 'legalName', 'rejectionReason', 'avatarUrl', 'ownerName', 'contactPhone', 'businessEmail', 'addressLine2', 'gstinDocUrl', 'panCardUrl'].some(key => (updatePartnerDto as any)[key] !== undefined)) {
      throw new BadRequestException('Only admins can change partner status or verification');
    }
    const saved = await this.update(id, updatePartnerDto);

    await this.adminNotificationsService.notify(
      AdminNotificationType.PARTNER_PROFILE_UPDATED,
      'Partner profile updated',
      `${saved.fullName || saved.businessName || saved.email} updated their profile`,
      { partnerId: id, fields: Object.keys(updatePartnerDto) },
    );

    return saved;
  }

  async remove(id: string): Promise<void> {
    // Admin and self-service deletion share the normalized schema and guards.
    await this.deleteAccount(id);
  }

  async toggleStatus(id: string): Promise<any> {
    const current = await this.prisma.partners.findUnique({ where: { id } });
    if (!current) throw new NotFoundException(`Partner with id ${id} not found`);
    return this.update(id, {
      isActive: current.status !== PartnerStatus.ACTIVE,
    });
  }

  async updateAvatar(partnerId: string, avatarUrl: string): Promise<Partner> {
    const owner = await this.prisma.partner_users.findFirst({
      where: { partner_id: partnerId, role: 'PARTNER_ADMIN' },
    });
    if (!owner) throw new NotFoundException('Partner owner not found');
    await this.prisma.users.update({
      where: { id: owner.user_id }, data: { profile_photo: avatarUrl },
    });
    return { id: partnerId, avatarUrl } as Partner;
  }

  async removeAvatar(partnerId: string): Promise<Partner> {
    const owner = await this.prisma.partner_users.findFirst({
      where: { partner_id: partnerId, role: 'PARTNER_ADMIN' },
    });
    if (!owner) throw new NotFoundException('Partner owner not found');
    await this.prisma.users.update({
      where: { id: owner.user_id },
      data: { profile_photo: null },
    });
    return { id: partnerId, avatarUrl: '' } as Partner;
  }

  async deleteAccount(partnerId: string): Promise<void> {
    await this.prisma.$transaction(
      (tx) => deletePartnerAccount(tx, partnerId),
      { maxWait: 10000, timeout: 60000, isolationLevel: 'Serializable' },
    );
  }

  // ─── GST Verification ────────────────────────────────────────────────────

  async submitGstVerification(
    partnerId: string,
    dto: SubmitGstVerificationDto,
    gstDocFile?: Express.Multer.File,
  ): Promise<GstVerificationRequest> {
    const gstDocUrl = gstDocFile
      ? ((gstDocFile as Express.Multer.File & { cloudinaryUrl?: string }).cloudinaryUrl ?? null)
      : null;

    const saved = await this.prisma.$transaction(async (tx) => {
      const existing = await tx.partner_gst_verification_requests.findFirst({
        where: { partner_id: partnerId, status: PartnerKycStatus.PENDING },
      });
      if (existing) {
        throw new ConflictException(
          'You already have a pending GST verification request. Please wait for admin review.',
        );
      }
      return tx.partner_gst_verification_requests.create({
        data: {
          id: randomUUID(),
          partner_id: partnerId,
          gst_number: dto.gstNumber,
          legal_name: dto.gstName,
          document_url: gstDocUrl,
          status: PartnerKycStatus.PENDING,
          updated_at: new Date(),
        },
      });
    }, { isolationLevel: 'Serializable', maxWait: 10000, timeout: 30000 });
    await this.adminNotificationsService.notify(
      AdminNotificationType.GST_VERIFICATION_SUBMITTED,
      'GST verification submitted',
      'A partner submitted GST details for review.',
      { partnerId, gstVerificationId: saved.id },
    );
    return this.mapPrismaGstVerification(saved);
  }

  async findMyGstVerification(partnerId: string): Promise<GstVerificationRequest> {
    const request = await this.prisma.partner_gst_verification_requests.findFirst({
      where: { partner_id: partnerId },
      orderBy: { created_at: 'desc' },
    });
    return request ? this.mapPrismaGstVerification(request) : null;
  }

  async findAllGstVerifications(
    pagination: PaginationDto,
    status?: GstVerificationStatus,
  ): Promise<[GstVerificationRequest[], number]> {
    const where: any = {};
    if (status) where.status = status.toUpperCase();
    if (pagination.search) {
      where.OR = [
        { gst_number: { contains: pagination.search, mode: 'insensitive' } },
        { legal_name: { contains: pagination.search, mode: 'insensitive' } },
      ];
    }
    const [requests, total] = await Promise.all([
      this.prisma.partner_gst_verification_requests.findMany({
        where,
        orderBy: { created_at: 'desc' },
        skip: pagination.skip,
        take: pagination.limit,
      }),
      this.prisma.partner_gst_verification_requests.count({ where }),
    ]);
    return [requests.map((request) => this.mapPrismaGstVerification(request)), total];
  }

  async findOneGstVerification(id: string): Promise<GstVerificationRequest> {
    const request = await this.prisma.partner_gst_verification_requests.findUnique({
      where: { id },
    });
    if (!request) throw new NotFoundException('GST verification request not found');
    return this.mapPrismaGstVerification(request);
  }

  async approveGstVerification(id: string, reviewerId: string) {
    if (!reviewerId) throw new UnauthorizedException('Authenticated reviewer is required');
    const approvedAt = new Date();
    const result = await this.prisma.$transaction(async (tx) => {
      const request = await tx.partner_gst_verification_requests.findUnique({ where: { id } });
      if (!request) throw new NotFoundException('GST verification request not found');
      if (request.status !== PartnerKycStatus.PENDING) {
        throw new BadRequestException('Only pending requests can be approved');
      }
      const profile = await tx.partner_business_profiles.findUnique({
        where: { partner_id: request.partner_id },
        select: { partner_id: true, business_name: true, kyc_status: true },
      });
      if (!profile) throw new NotFoundException('Partner business profile not found');

      const claimed = await tx.partner_gst_verification_requests.updateMany({
        where: { id, status: PartnerKycStatus.PENDING },
        data: {
          status: PartnerKycStatus.APPROVED,
          reviewed_by: reviewerId,
          reviewed_at: approvedAt,
          updated_at: approvedAt,
        },
      });
      if (claimed.count !== 1) {
        throw new BadRequestException('GST verification request is no longer pending');
      }

      const updatedProfile = await tx.partner_business_profiles.update({
        where: { partner_id: request.partner_id },
        data: {
          gst_number: request.gst_number,
          gst_document_url: request.document_url,
          updated_at: approvedAt,
        },
        select: { partner_id: true, business_name: true, kyc_status: true, gst_number: true, gst_document_url: true },
      });
      return { request, updatedProfile, reviewedAt: approvedAt };
    }, { isolationLevel: 'Serializable', maxWait: 10000, timeout: 30000 });

    return {
      request: {
        ...this.mapPrismaGstVerification({
        ...result.request,
        status: PartnerKycStatus.APPROVED,
        reviewed_by: reviewerId,
        reviewed_at: result.reviewedAt,
        }),
        reviewedBy: reviewerId,
        reviewedAt: result.reviewedAt,
      },
      businessProfile: {
        partnerId: result.updatedProfile.partner_id,
        businessName: result.updatedProfile.business_name,
        gstNumber: result.updatedProfile.gst_number,
        gstDocumentUrl: result.updatedProfile.gst_document_url,
        kycStatus: String(result.updatedProfile.kyc_status).toLowerCase(),
      },
    };
  }

  async rejectGstVerification(
    id: string,
    dto: ReviewGstVerificationDto,
  ): Promise<GstVerificationRequest> {
    const updated = await this.prisma.partner_gst_verification_requests.updateMany({
      where: { id, status: PartnerKycStatus.PENDING },
      data: {
        status: PartnerKycStatus.REJECTED,
        rejection_reason: dto.adminNotes ?? null,
        updated_at: new Date(),
      },
    });
    if (updated.count === 0) {
      const request = await this.prisma.partner_gst_verification_requests.findUnique({ where: { id } });
      if (!request) throw new NotFoundException('GST verification request not found');
      throw new BadRequestException('Only pending requests can be rejected');
    }
    return this.findOneGstVerification(id);
  }
}
