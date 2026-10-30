import {
  Injectable,
  NotFoundException,
  ConflictException,
  Optional,
} from "@nestjs/common";
import { randomUUID } from "crypto";
import { randomInt } from "crypto";
import * as bcrypt from "bcryptjs";
import { PrismaService } from "../../prisma/prisma.service";
import { TeamMemberRecord as TeamMember, TeamMemberStatus } from '../../common/domain-types';
import { CreateTeamMemberDto } from "./dto/create-team-member.dto";
import { UpdateTeamMemberDto } from "./dto/update-team-member.dto";
import { MailService } from "../mail/mail.service";
import { PartnerRole } from "../../generated/prisma/client";

@Injectable()
export class TeamService {
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
    const settings = record.permissions as Record<string, any>;
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
    const row = await this.prisma.partner_staff_profiles.findFirst({
      where: { partner_users: { users: { phone_e164: phone } } },
      include: this.include,
    });
    return row ? this.toMember(row) : null;
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
      const temporaryPassword = `Activ@${randomInt(100000, 1000000)}`;
      const passwordHash = await bcrypt.hash(temporaryPassword, 12);
      const row = await this.prisma.$transaction(async (tx) => {
        const user = await tx.users.findUnique({
          where: { phone_e164: dto.phone },
        });
        if (
          user?.is_admin ||
          (user &&
            (await tx.partner_users.findFirst({ where: { user_id: user.id } })))
        ) {
          throw new ConflictException(
            "This phone number already belongs to a partner or team account",
          );
        }
        const now = new Date();
        const account =
          user ??
          (await tx.users.create({
            data: {
              id: randomUUID(),
              phone_e164: dto.phone,
              name: dto.fullName,
              password_hash: passwordHash,
              updated_at: now,
            },
          }));
        if (user && !user.password_hash) {
          await tx.users.update({
            where: { id: user.id },
            data: {
              password_hash: passwordHash,
              name: dto.fullName,
              updated_at: now,
            },
          });
        }
        const link = await tx.partner_users.create({
          data: {
            id: randomUUID(),
            partner_id: partnerId,
            user_id: account.id,
            role: "PARTNER_USER",
          },
        });
        return tx.partner_staff_profiles.create({
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
              setupStatus: TeamMemberStatus.INVITE_SENT,
              isActive: true,
            },
          },
          include: this.include,
        });
      });
      const member = this.toMember(row);
      await this.mailService?.sendTeamMemberInviteSms({
        phone: member.phone,
        fullName: member.fullName,
        role: member.role,
        password: temporaryPassword,
      });
      return member;
    } catch (error) {
      if ((error as { code?: string }).code === "P2002")
        throw new ConflictException("Phone number is already in use");
      throw error;
    }
  }

  async update(
    id: string,
    partnerId: string,
    dto: UpdateTeamMemberDto,
  ): Promise<TeamMember> {
    const current = await this.owned(id, partnerId);
    const settings = current.permissions as Record<string, any>;
    try {
      const row = await this.prisma.$transaction(async (tx) => {
        if (dto.phone && dto.phone !== current.partner_users.users.phone_e164) {
          const conflict = await tx.users.findUnique({
            where: { phone_e164: dto.phone },
          });
          if (conflict)
            throw new ConflictException("Phone number is already in use");
          await tx.users.update({
            where: { id: current.partner_users.user_id },
            data: { phone_e164: dto.phone, updated_at: new Date() },
          });
        }
        return tx.partner_staff_profiles.update({
          where: { id },
          data: {
            display_name: dto.fullName,
            contact_phone_e164: dto.phone,
            designation: dto.role,
            permissions: { ...settings, ...dto.permissions },
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
    const row = await this.prisma.partner_staff_profiles.findUnique({
      where: { id },
    });
    if (!row) throw new NotFoundException("Team member not found");
    await this.prisma.partner_staff_profiles.update({
      where: { id },
      data: {
        permissions: {
          ...(row.permissions as object),
          setupStatus: TeamMemberStatus.ACTIVE,
        },
        updated_at: new Date(),
      },
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
