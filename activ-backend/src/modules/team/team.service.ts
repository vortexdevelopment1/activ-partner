import {
  Injectable,
  NotFoundException,
  ConflictException,
  Optional,
  BadRequestException,
  Logger,
  UnauthorizedException,
} from "@nestjs/common";
import { randomBytes, randomUUID } from "crypto";
import * as bcrypt from "bcryptjs";
import { PrismaService } from "../../prisma/prisma.service";
import { TeamMemberRecord as TeamMember, TeamMemberStatus } from '../../common/domain-types';
import { CreateTeamMemberDto } from "./dto/create-team-member.dto";
import { UpdateTeamMemberDto } from "./dto/update-team-member.dto";
import { MailService } from "../mail/mail.service";
import { PartnerRole } from "../../generated/prisma/client";

@Injectable()
export class TeamService {
  private readonly logger = new Logger(TeamService.name);
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly mailService?: MailService,
  ) {}

  private readonly include = {
    partner_users: { include: { users: true } },
  } as const;

  private toMember(record: any): TeamMember {
    const link = record.partner_users;
    const user = link.users;
    const settings = (record.permissions || {}) as Record<string, any>;
    return {
      id: record.id,
      partnerId: link.partner_id,
      fullName: record.display_name || user.name || "",
      email: user.email,
      phone: record.contact_phone_e164 || user.phone_e164,
      avatarUrl: user.profile_photo || '',
      role: record.designation || "staff",
      status: settings.setupStatus || TeamMemberStatus.INVITE_SENT,
      isActive: settings.isActive !== false,
      permissions: {
        bookingManagement: settings.bookingManagement === true,
        pricingControl: settings.pricingControl === true,
        analyticsView: settings.analyticsView === true,
      },
      createdAt: record.created_at,
      updatedAt: record.updated_at,
      invitationDelivery: settings.invitationDelivery,
    };
  }

  async findAll(partnerId: string): Promise<TeamMember[]> {
    const rows = await this.prisma.partner_staff_profiles.findMany({
      where: { partner_users: { partner_id: partnerId } },
      include: this.include,
      orderBy: { created_at: "desc" },
    });
    return rows
      .map((row) => this.toMember(row))
      .filter((member) => member.isActive);
  }

  private async owned(id: string, partnerId: string) {
    const row = await this.prisma.partner_staff_profiles.findFirst({
      where: { id, partner_users: { partner_id: partnerId } },
      include: this.include,
    });
    if (!row) throw new NotFoundException("Team member not found");
    return row;
  }

  async findOne(id: string, partnerId: string): Promise<TeamMember> {
    return this.toMember(await this.owned(id, partnerId));
  }

  async findByPhone(phone: string): Promise<TeamMember | null> {
    const candidates = await this.findLoginCandidates(phone, [phone]);
    if (candidates.length > 1) throw new UnauthorizedException('Ambiguous team account; contact support');
    const candidate = candidates[0];
    if (!candidate) return null;
    return { ...candidate.member, isActive: candidate.member.isActive &&
      candidate.userStatus === 'ACTIVE' && candidate.partnerStatus === 'ACTIVE' };
  }

  async findByEmail(email: string): Promise<TeamMember | null> {
    const row = await this.prisma.partner_staff_profiles.findFirst({
      where: { partner_users: { users: { email } } },
      include: this.include,
    });
    return row ? this.toMember(row) : null;
  }

  /**
   * Returns only normalized staff accounts.  A partner user is staff only when
   * it has the staff role and an associated staff profile.  The caller must
   * reject multiple matches rather than selecting one arbitrarily.
   */
  async findLoginCandidates(identifier: string, phoneValues: string[]) {
    const rows = await this.prisma.partner_staff_profiles.findMany({
      where: {
        partner_users: {
          role: PartnerRole.PARTNER_USER,
          users: {
            OR: [
              { email: { equals: identifier, mode: "insensitive" } },
              ...(phoneValues.length > 0
                ? [{ phone_e164: { in: phoneValues } }]
                : []),
            ],
          },
        },
      },
      include: {
        partner_users: {
          include: { users: true, partners: true },
        },
      },
    });

    return rows.map((row) => ({
      member: this.toMember(row),
      passwordHash: row.partner_users.users.password_hash,
      userStatus: row.partner_users.users.status,
      partnerStatus: row.partner_users.partners.status,
    }));
  }

  async create(
    partnerId: string,
    dto: CreateTeamMemberDto,
  ): Promise<TeamMember> {
    try {
      const temporaryPassword = `Activ@${randomBytes(18).toString('base64url')}`;
      const passwordHash = await bcrypt.hash(temporaryPassword, 12);
      const email = dto.email?.trim().toLowerCase();
      const prepared = await this.prisma.$transaction(async (tx) => {
        const user = await tx.users.findUnique({
          where: { phone_e164: dto.phone },
        });
        if (user) await tx.$queryRaw`SELECT id FROM users WHERE id = ${user.id}::uuid FOR UPDATE`;
        if (
          user?.is_admin ||
          (user &&
            (await tx.partner_users.findFirst({ where: { user_id: user.id } })))
        ) {
          throw new ConflictException(
            "This phone number already belongs to a partner or team account",
          );
        }
        if (user && user.status !== 'ACTIVE') throw new ConflictException('This account is unavailable for invitation');
        if (email) {
          await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`team-email:${email}`}, 0))`;
          const emailOwner = await tx.users.findFirst({ where: { email: { equals: email, mode: 'insensitive' } } });
          if (emailOwner && emailOwner.id !== user?.id) throw new ConflictException('Email address is already in use');
          if (user && user.email?.toLowerCase() !== email) throw new ConflictException('Use the registered email for this phone number');
        }
        const now = new Date();
        const account =
          user ??
          (await tx.users.create({
            data: {
              id: randomUUID(),
              phone_e164: dto.phone,
              name: dto.fullName,
              email,
              password_hash: passwordHash,
              updated_at: now,
            },
          }));
        const link = await tx.partner_users.create({
          data: {
            id: randomUUID(),
            partner_id: partnerId,
            user_id: account.id,
            role: "PARTNER_USER",
          },
        });
        const row = await tx.partner_staff_profiles.create({
          data: {
            id: randomUUID(),
            partner_user_id: link.id,
            display_name: dto.fullName,
            contact_phone_e164: dto.phone,
            designation: dto.role,
            updated_at: now,
            permissions: {
              bookingManagement: dto.permissions?.bookingManagement ?? false,
              pricingControl: dto.permissions?.pricingControl ?? false,
              analyticsView: dto.permissions?.analyticsView ?? false,
              setupStatus: TeamMemberStatus.INVITE_PENDING,
              lastInvitationAt: now.toISOString(),
              isActive: true,
              accountCreatedForTeam: !user,
            },
          },
          include: this.include,
        });
        const password = user ? undefined : temporaryPassword;
        const deliveryId = email ? await this.mailService.prepareTeamMemberInviteEmail({
          toEmail: email, phone: dto.phone, fullName: dto.fullName, role: dto.role, password,
          deliveryKey: `team-invite:${row.id}:${randomUUID()}`,
        }, tx) : undefined;
        return { row, password, deliveryId };
      });
      return this.deliverInvitation(prepared.row, prepared.password, prepared.deliveryId);
    } catch (error) {
      if ((error as { code?: string }).code === "P2002")
        throw new ConflictException("Phone number or email is already in use");
      throw error;
    }
  }

  private async deliverInvitation(row: any, password?: string, deliveryId?: string): Promise<TeamMember> {
    const member = this.toMember(row);
    const results = await Promise.allSettled([
      deliveryId ? this.mailService.deliverPreparedEmail(deliveryId) : Promise.resolve(false),
      this.mailService?.sendTeamMemberInviteSms({ phone: member.phone, fullName: member.fullName, role: member.role, password }),
    ]);
    const sent = (index: number) => {
      const result = results[index];
      return result.status === 'fulfilled' && result.value === true;
    };
    const invitationDelivery = { emailSent: sent(0), smsSent: sent(1) };
    let status = invitationDelivery.emailSent || invitationDelivery.smsSent
      ? TeamMemberStatus.INVITE_SENT : TeamMemberStatus.INVITE_PENDING;
    try {
      await this.prisma.$transaction(async tx => {
        await tx.$queryRaw`SELECT id FROM partner_staff_profiles WHERE id = ${row.id}::uuid FOR UPDATE`;
        const current = await tx.partner_staff_profiles.findUnique({ where: { id: row.id } });
        if (!current) return;
        const settings = (current.permissions || {}) as Record<string, any>;
        if (settings.setupStatus === TeamMemberStatus.ACTIVE) status = TeamMemberStatus.ACTIVE;
        await tx.partner_staff_profiles.update({ where: { id: row.id }, data: {
          permissions: { ...settings, invitationDelivery, setupStatus: status }, updated_at: new Date(),
        } });
      });
    } catch { this.logger.warn('Team account saved; invitation delivery metadata could not be updated'); }
    return { ...member, status, invitationDelivery };
  }

  async resendInvitation(id: string, partnerId: string): Promise<TeamMember> {
    const prepared = await this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM partner_staff_profiles WHERE id = ${id}::uuid FOR UPDATE`;
      const row = await tx.partner_staff_profiles.findFirst({
        where: { id, partner_users: { partner_id: partnerId } }, include: this.include,
      });
      if (!row) throw new NotFoundException('Team member not found');
      const settings = (row.permissions || {}) as Record<string, any>;
      if (settings.setupStatus === TeamMemberStatus.ACTIVE) throw new BadRequestException('This member has already joined');
      if (settings.lastInvitationAt && Date.parse(settings.lastInvitationAt) > Date.now() - 60000) {
        throw new BadRequestException('Wait one minute before resending the invitation');
      }
      const email = row.partner_users.users.email;
      const deliveryId = email ? await this.mailService.prepareTeamMemberInviteEmail({
        toEmail: email, phone: row.contact_phone_e164, fullName: row.display_name, role: row.designation,
        deliveryKey: `team-invite:${id}:${randomUUID()}`,
      }, tx) : undefined;
      await tx.partner_staff_profiles.update({ where: { id }, data: {
        permissions: { ...settings, lastInvitationAt: new Date().toISOString() }, updated_at: new Date(),
      } });
      return { row, deliveryId };
    });
    return this.deliverInvitation(prepared.row, undefined, prepared.deliveryId);
  }

  async update(
    id: string,
    partnerId: string,
    dto: UpdateTeamMemberDto,
  ): Promise<TeamMember> {
    try {
      const row = await this.prisma.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT id FROM partner_staff_profiles WHERE id = ${id}::uuid FOR UPDATE`;
        const latest = await tx.partner_staff_profiles.findFirst({
          where: { id, partner_users: { partner_id: partnerId } }, include: this.include,
        });
        if (!latest) throw new NotFoundException('Team member not found');
        const contactChanged = (dto.phone && dto.phone !== latest.partner_users.users.phone_e164) ||
          (dto.email && dto.email.trim().toLowerCase() !== latest.partner_users.users.email?.toLowerCase());
        if (contactChanged && (latest.permissions as Record<string, any>)?.accountCreatedForTeam !== true) {
          throw new BadRequestException('Existing account contact details must be changed by the member');
        }
        if (dto.email) {
          const email = dto.email.trim().toLowerCase();
          await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`team-email:${email}`}, 0))`;
          const conflict = await tx.users.findFirst({ where: { email: { equals: email, mode: 'insensitive' }, id: { not: latest.partner_users.user_id } } });
          if (conflict) throw new ConflictException('Email address is already in use');
          await tx.users.update({ where: { id: latest.partner_users.user_id }, data: { email, updated_at: new Date() } });
        }
        if (dto.phone && dto.phone !== latest.partner_users.users.phone_e164) {
          const conflict = await tx.users.findUnique({
            where: { phone_e164: dto.phone },
          });
          if (conflict)
            throw new ConflictException("Phone number is already in use");
          await tx.users.update({
            where: { id: latest.partner_users.user_id },
            data: { phone_e164: dto.phone, updated_at: new Date() },
          });
        }
        return tx.partner_staff_profiles.update({
          where: { id },
          data: {
            display_name: dto.fullName,
            contact_phone_e164: dto.phone,
            designation: dto.role,
            permissions: { ...(latest.permissions as object || {}), ...dto.permissions },
            updated_at: new Date(),
          },
          include: this.include,
        });
      });
      return this.toMember(row);
    } catch (error) {
      if ((error as { code?: string }).code === "P2002")
        throw new ConflictException("Phone number is already in use");
      throw error;
    }
  }

  async remove(id: string, partnerId: string): Promise<void> {
    const current = await this.owned(id, partnerId);
    await this.prisma.partner_users.delete({
      where: { id: current.partner_user_id },
    });
  }

  async markActive(id: string): Promise<void> {
    await this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM partner_staff_profiles WHERE id = ${id}::uuid FOR UPDATE`;
      const row = await tx.partner_staff_profiles.findUnique({ where: { id } });
      if (!row) throw new NotFoundException("Team member not found");
      await tx.partner_staff_profiles.update({
        where: { id },
        data: {
          permissions: {
            ...(row.permissions as object),
            setupStatus: TeamMemberStatus.ACTIVE,
          },
          updated_at: new Date(),
        },
      });
    });
  }

  async updateAvatar(id: string, avatarUrl: string | null): Promise<void> {
    const staff = await this.prisma.partner_staff_profiles.findUnique({
      where: { id },
    });
    if (!staff) throw new NotFoundException('Team member not found');
    const link = await this.prisma.partner_users.findUnique({
      where: { id: staff.partner_user_id },
    });
    if (!link) throw new NotFoundException('Team member account not found');
    await this.prisma.users.update({
      where: { id: link.user_id },
      data: { profile_photo: avatarUrl, updated_at: new Date() },
    });
  }

  async removeAvatar(id: string): Promise<void> {
    await this.updateAvatar(id, null);
  }
}
