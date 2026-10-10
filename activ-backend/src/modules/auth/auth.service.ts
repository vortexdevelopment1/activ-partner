import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  BadRequestException,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import { randomInt, randomUUID } from 'crypto';
import { UsersService } from '../users/users.service';
import { TeamService } from '../team/team.service';
import { OtpService } from '../otp/otp.service';
import { MailService } from '../mail/mail.service';
import { User } from '../users/entities/user.entity';
import { Partner } from '../partners/entities/partner.entity';
import { TeamMember, TeamMemberStatus } from '../team/entities/team-member.entity';
import { Venue } from '../venues/entities/venue.entity';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { RegisterPartnerDto } from './dto/register-partner.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { RequestOtpDto } from './dto/request-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { CompletePartnerProfileDto } from './dto/complete-partner-profile.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { ResetPasswordDto, VerifyPasswordResetCodeDto } from './dto/reset-password.dto';
import { UserRole } from '../../common/enums/user-role.enum';
import { VenueStatus } from '../../common/enums/venue-status.enum';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
    private configService: ConfigService,
    private teamService: TeamService,
    private otpService: OtpService,
    private mailService: MailService,
    private prisma: PrismaService,
    @InjectRepository(Partner)
    private partnerRepository: Repository<Partner>,
    @InjectRepository(TeamMember)
    private teamMemberRepository: Repository<TeamMember>,
    @InjectRepository(Venue)
    private venueRepository: Repository<Venue>,
  ) {}

  // ─── User Auth ─────────────────────────────────────────────────────────────

  async login(loginDto: LoginDto) {
    const user = await this.prisma.users.findFirst({
      where: {
        email: { equals: loginDto.email.trim(), mode: 'insensitive' },
      },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid email or password');
    }

    if (user.status !== 'ACTIVE') {
      throw new UnauthorizedException('Your account has been deactivated');
    }

    if (!user.password_hash) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const isPasswordValid = await bcrypt.compare(
      loginDto.password,
      user.password_hash,
    );
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const role = user.is_admin ? UserRole.ADMIN : UserRole.USER;
    const tokens = await this.generateUserTokens({
      id: user.id,
      email: user.email,
      role,
    });

    return {
      user: {
        id: user.id,
        firstName: user.name?.split(/\s+/)[0] || null,
        lastName: user.name?.split(/\s+/).slice(1).join(' ') || null,
        name: user.name,
        email: user.email,
        phone: user.phone_e164,
        role,
        isActive: true,
        profileImage: user.profile_photo,
      },
      ...tokens,
    };
  }

  async registerUser(registerDto: RegisterDto) {
    const user = await this.usersService.create({
      ...registerDto,
      role: UserRole.USER,
    });

    const tokens = await this.generateUserTokens(user);
    const { password, ...userWithoutPassword } = user as any;

    return {
      user: userWithoutPassword,
      ...tokens,
    };
  }

  // ─── Partner Auth ──────────────────────────────────────────────────────────

  async partnerLogin(loginDto: LoginDto) {
    const identifier = loginDto.email.trim();
    const phoneValues = this.getPhoneLookupValues(identifier);

    const user = await this.prisma.users.findFirst({
      where: {
        OR: [
          { email: { equals: identifier, mode: 'insensitive' } },
          ...(phoneValues.length > 0
            ? [{ phone_e164: { in: phoneValues } }]
            : []),
        ],
      },
      include: {
        partner_users: {
          include: {
            partners: { include: { partner_business_profiles: true } },
          },
        },
      },
    });

    const partnerUser = user?.partner_users[0];
    const partner = partnerUser?.partners;

    // Team members still use the legacy login path until that module is migrated.
    if (!user || !partnerUser || !partner) {
      const member = await this.findTeamMemberByIdentifier(identifier, phoneValues);

      if (!member) throw new UnauthorizedException('Invalid email or password');
      if (!member.isActive) throw new UnauthorizedException('Your account has been deactivated. Please contact support');

      const isPasswordValid = await member.validatePassword(loginDto.password);
      if (!isPasswordValid) throw new UnauthorizedException('Invalid email or password');

      await this.teamService.markActive(member.id);

      const accessToken = this.jwtService.sign(
        { sub: member.id, role: 'team_member', type: 'team_member', partnerId: member.partnerId, permissions: member.permissions },
        { secret: this.configService.get<string>('JWT_SECRET'), expiresIn: this.configService.get<string>('JWT_EXPIRY') || '7d' },
      );

      const { password, ...memberWithoutPassword } = member as any;
      return { member: memberWithoutPassword, accessToken };
    }

    if (!user.password_hash) {
      throw new UnauthorizedException(
        'No password is set for this account. Please use OTP login.',
      );
    }

    if (user.status !== 'ACTIVE' || partner.status !== 'ACTIVE') {
      throw new UnauthorizedException('Your account has been deactivated. Please contact support');
    }

    const isPasswordValid = await bcrypt.compare(
      loginDto.password,
      user.password_hash,
    );
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const staffMember = await this.teamService.findByPhone(user.phone_e164);
    if (staffMember) return this.completeTeamMemberLogin(staffMember);
    const tokens = await this.generatePartnerTokens(partner);
    const profile = partner.partner_business_profiles;
    const names = (user.name || '').trim().split(/\s+/);

    return {
      partner: {
        id: partner.id,
        firstName: names[0] || null,
        lastName: names.slice(1).join(' ') || null,
        email: user.email,
        phone: user.phone_e164,
        avatarUrl: user.profile_photo ?? null,
        businessName: profile?.business_name || partner.legal_name,
        isActive: true,
        role: partnerUser.role,
      },
      userType: 'partner',
      ...tokens,
    };
  }

  private getPhoneLookupValues(identifier: string): string[] {
    const digits = identifier.replace(/\D/g, '');
    if (!digits) return [];

    const values = new Set<string>([identifier, digits]);
    if (digits.length === 10) {
      values.add(`+91${digits}`);
      values.add(`91${digits}`);
      values.add(`IND (+91)${digits}`);
    }
    if (digits.length === 12 && digits.startsWith('91')) {
      values.add(digits.slice(2));
      values.add(`+${digits}`);
      values.add(`IND (+91)${digits.slice(2)}`);
    }
    return [...values];
  }

  private async findTeamMemberByIdentifier(identifier: string, phoneValues: string[]): Promise<TeamMember | null> {
    const query = this.teamMemberRepository
      .createQueryBuilder('member')
      .where('LOWER(member.email) = LOWER(:identifier)', { identifier });

    if (phoneValues.length > 0) {
      query.orWhere('member.phone IN (:...phoneValues)', { phoneValues });
    }

    return query.getOne();
  }

  async registerPartner(registerPartnerDto: RegisterPartnerDto) {
    const existing = await this.partnerRepository.findOne({
      where: { email: registerPartnerDto.email },
    });

    if (existing) {
      throw new ConflictException('Email is already registered');
    }

    const partner = this.partnerRepository.create({
      firstName: registerPartnerDto.firstName,
      lastName: registerPartnerDto.lastName,
      email: registerPartnerDto.email,
      password: registerPartnerDto.password,
      phone: registerPartnerDto.phone,
      businessName: registerPartnerDto.businessName,
      businessDescription: registerPartnerDto.businessDescription,
      businessAddress: registerPartnerDto.businessAddress,
      city: registerPartnerDto.city,
      state: registerPartnerDto.state,
      zipCode: registerPartnerDto.zipCode,
      isActive: false,
    });

    const saved = await this.partnerRepository.save(partner);
    const tokens = await this.generatePartnerTokens(saved);
    const { password, phoneOtp, otpExpiresAt, resetPasswordCode, resetPasswordCodeExpiresAt, ...partnerWithoutSensitive } = saved as any;

    return {
      partner: partnerWithoutSensitive,
      ...tokens,
    };
  }

  // ─── Phone OTP Flow ────────────────────────────────────────────────────────

  async requestOtp(dto: RequestOtpDto) {
    const phone = this.normalizePhone(dto.phone);
    const now = new Date();
    const latestChallenge = await this.prisma.otp_challenges.findFirst({
      where: { phone_e164: phone, consumed_at: null },
      orderBy: { created_at: 'desc' },
    });

    if (
      latestChallenge &&
      latestChallenge.created_at.getTime() > now.getTime() - 60 * 1000
    ) {
      throw new BadRequestException('Please wait before requesting another OTP.');
    }

    await this.otpService.sendOtp(phone);
    await this.prisma.otp_challenges.create({
      data: {
        id: randomUUID(),
        phone_e164: phone,
        code_hash: 'managed-by-msg91',
        expires_at: new Date(now.getTime() + 10 * 60 * 1000),
      },
    });

    return { phone };
  }

  async resendOtp(dto: RequestOtpDto) {
    const phone = this.normalizePhone(dto.phone);
    const challenge = await this.prisma.otp_challenges.findFirst({
      where: { phone_e164: phone, consumed_at: null },
      orderBy: { created_at: 'desc' },
    });

    if (!challenge || challenge.expires_at <= new Date()) {
      throw new BadRequestException('Phone number not found. Please request OTP first.');
    }
    if (challenge.created_at.getTime() > Date.now() - 60 * 1000) {
      throw new BadRequestException('Please wait before requesting another OTP.');
    }

    await this.otpService.resendOtp(phone);
    await this.prisma.otp_challenges.create({
      data: {
        id: randomUUID(),
        phone_e164: phone,
        code_hash: 'managed-by-msg91',
        expires_at: new Date(Date.now() + 10 * 60 * 1000),
      },
    });

    return { phone };
  }

  async verifyOtp(dto: VerifyOtpDto) {
    const phone = this.normalizePhone(dto.phone);
    const challenge = await this.prisma.otp_challenges.findFirst({
      where: {
        phone_e164: phone,
        consumed_at: null,
        expires_at: { gt: new Date() },
      },
      orderBy: { created_at: 'desc' },
    });
    if (!challenge) throw new BadRequestException('Invalid or expired OTP.');

    const isValid = await this.otpService.verifyOtp(phone, dto.otp);
    if (!isValid) {
      throw new BadRequestException('Invalid or expired OTP.');
    }

    const account = await this.prisma.$transaction(async (tx) => {
      await tx.otp_challenges.update({
        where: { id: challenge.id },
        data: { consumed_at: new Date() },
      });

      let user = await tx.users.findUnique({ where: { phone_e164: phone } });
      if (!user) {
        user = await tx.users.create({
          data: {
            id: randomUUID(),
            phone_e164: phone,
            updated_at: new Date(),
          },
        });
      }

      let link = await tx.partner_users.findFirst({
        where: { user_id: user.id },
        include: { partners: { include: { partner_business_profiles: true } } },
      });

      if (!link) {
        const partnerId = randomUUID();
        await tx.partners.create({
          data: {
            id: partnerId,
            legal_name: user.name || 'Partner User',
            updated_at: new Date(),
          },
        });
        link = await tx.partner_users.create({
          data: {
            id: randomUUID(),
            partner_id: partnerId,
            user_id: user.id,
            role: 'PARTNER_ADMIN',
          },
          include: { partners: { include: { partner_business_profiles: true } } },
        });
      }

      return { user, link };
    });

    const staffMember = await this.teamService.findByPhone(phone);
    if (staffMember) return this.completeTeamMemberLogin(staffMember);
    return this.buildPartnerAuthResponse(
      account.link.partners,
      account.user,
      account.link.role,
    );
  }

  private async completeTeamMemberLogin(teamMember: TeamMember) {
    if (!teamMember.isActive) throw new UnauthorizedException('Account has been deactivated');
    teamMember.status = TeamMemberStatus.ACTIVE;
    await this.teamService.markActive(teamMember.id);

    const jwt_token = this.jwtService.sign(
      {
        sub: teamMember.id,
        role: 'team_member',
        type: 'team_member',
        partnerId: teamMember.partnerId,
        permissions: teamMember.permissions,
      },
      {
        secret: this.configService.get<string>('JWT_SECRET'),
        expiresIn: this.configService.get<string>('JWT_EXPIRY') || '7d',
      },
    );

    let venue = await this.prisma.venues.findFirst({
      where: { partner_id: teamMember.partnerId, status: 'PUBLISHED' },
    });
    if (!venue) {
      venue = await this.prisma.venues.findFirst({
        where: { partner_id: teamMember.partnerId },
      });
    }

    return {
      jwt_token,
      userType: 'team_member',
      role: teamMember.role,
      permissions: teamMember.permissions,
      member: teamMember,
      venueId: venue?.id ?? null,
      venueName: venue?.name ?? null,
    };
  }

  async completePartnerProfile(partnerId: string, dto: CompletePartnerProfileDto) {
    const partner = await this.prisma.partners.findUnique({
      where: { id: partnerId },
      include: {
        partner_users: {
          include: { users: true },
          orderBy: { role: 'desc' },
        },
      },
    });

    if (!partner) {
      throw new NotFoundException('Partner not found');
    }

    const owner = partner.partner_users[0];
    if (!owner) throw new NotFoundException('Partner user not found');

    const existingEmail = await this.prisma.users.findFirst({
      where: {
        email: { equals: dto.email, mode: 'insensitive' },
        id: { not: owner.user_id },
      },
    });
    if (existingEmail) {
      throw new ConflictException('Email is already in use by another account');
    }

    const name = `${dto.firstName} ${dto.lastName}`.trim();
    const businessName = dto.businessName?.trim() || partner.legal_name;
    const now = new Date();
    const result = await this.prisma.$transaction(async (tx) => {
      const user = await tx.users.update({
        where: { id: owner.user_id },
        data: { name, email: dto.email.trim(), updated_at: now },
      });
      const updatedPartner = await tx.partners.update({
        where: { id: partnerId },
        data: { legal_name: businessName, updated_at: now },
      });
      const profile = await tx.partner_business_profiles.upsert({
        where: { partner_id: partnerId },
        create: {
          id: randomUUID(),
          partner_id: partnerId,
          business_name: dto.businessName?.trim() || null,
          owner_name: name,
          phone_e164: dto.contactPhone
            ? this.normalizePhone(dto.contactPhone)
            : user.phone_e164,
          email: dto.email.trim(),
          updated_at: now,
        },
        update: {
          business_name: dto.businessName?.trim() || null,
          owner_name: name,
          phone_e164: dto.contactPhone
            ? this.normalizePhone(dto.contactPhone)
            : user.phone_e164,
          email: dto.email.trim(),
          updated_at: now,
        },
      });
      return {
        user,
        partner: { ...updatedPartner, partner_business_profiles: profile },
      };
    });

    return this.buildPartnerAuthResponse(result.partner, result.user, owner.role);
  }

  // ─── Shared ────────────────────────────────────────────────────────────────

  async changePassword(userId: string, changePasswordDto: ChangePasswordDto) {
    const user = await this.prisma.users.findUnique({ where: { id: userId } });
    if (!user?.password_hash) {
      throw new BadRequestException('Current password is incorrect');
    }

    const isCurrentValid = await bcrypt.compare(
      changePasswordDto.currentPassword,
      user.password_hash,
    );
    if (!isCurrentValid) {
      throw new BadRequestException('Current password is incorrect');
    }

    await this.usersService.updatePassword(userId, changePasswordDto.newPassword);

    return { message: 'Password changed successfully' };
  }

  async changePartnerPassword(partnerId: string, dto: ChangePasswordDto) {
    const partner = await this.partnerRepository.findOne({ where: { id: partnerId } });

    if (!partner) {
      throw new NotFoundException('Partner not found');
    }

    if (!partner.password) {
      throw new BadRequestException('No password set on this account. Please use OTP login.');
    }

    const isCurrentValid = await partner.validatePassword(dto.currentPassword);
    if (!isCurrentValid) {
      throw new BadRequestException('Current password is incorrect');
    }

    // Assigning triggers the @BeforeUpdate hook which hashes the new value
    partner.password = dto.newPassword;
    await this.partnerRepository.save(partner);

    return { message: 'Password changed successfully' };
  }

  async forgotPassword(dto: ForgotPasswordDto) {
    const user = await this.findPasswordResetUser(dto.email);

    // Always return a generic success response so this endpoint can't be used to enumerate registered emails
    if (!user) {
      return { message: 'If an account exists for this email, a reset code has been sent.' };
    }

    // Namespace email recovery challenges so they cannot be used for phone OTP login.
    const challengeKey = `password-reset:${user.id}`;
    const latest = await this.prisma.otp_challenges.findFirst({
      where: { phone_e164: challengeKey },
      orderBy: { created_at: 'desc' },
    });
    if (latest && latest.created_at.getTime() > Date.now() - 60000) {
      throw new BadRequestException('Please wait before requesting another reset code.');
    }

    const code = randomInt(1000, 10000).toString();
    const challenge = await this.prisma.otp_challenges.create({
      data: {
        id: randomUUID(), phone_e164: challengeKey,
        code_hash: await bcrypt.hash(code, 10),
        expires_at: new Date(Date.now() + 10 * 60 * 1000),
      },
    });
    try {
      const sent = await this.mailService.sendPasswordResetEmail({
        toEmail: user.email,
        firstName: user.name?.trim().split(/\s+/)[0] || 'there',
        code,
      });
      if (!sent) {
        throw new ServiceUnavailableException('Unable to send the reset email. Please try again.');
      }
    } catch (error) {
      await this.prisma.otp_challenges.delete({ where: { id: challenge.id } });
      throw error;
    }

    return { message: 'If an account exists for this email, a reset code has been sent.' };
  }

  private findPasswordResetUser(email: string) {
    return this.prisma.users.findFirst({
      where: {
        email: { equals: email.trim(), mode: 'insensitive' },
        partner_users: { some: {} },
      },
    });
  }

  private async findUserWithResetCode(email: string, code: string) {
    const user = await this.findPasswordResetUser(email);
    if (!user) {
      throw new BadRequestException('Invalid or expired reset code.');
    }
    const challenge = await this.prisma.otp_challenges.findFirst({
      where: { phone_e164: `password-reset:${user.id}` },
      orderBy: { created_at: 'desc' },
    });
    if (
      !challenge || challenge.consumed_at || challenge.attempts >= 5 ||
      challenge.expires_at <= new Date()
    ) {
      throw new BadRequestException('Invalid or expired reset code.');
    }
    if (!await bcrypt.compare(code, challenge.code_hash)) {
      await this.prisma.otp_challenges.updateMany({
        where: { id: challenge.id, attempts: { lt: 5 }, consumed_at: null },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException('Invalid or expired reset code.');
    }
    return { user, challenge };
  }

  async verifyPasswordResetCode(dto: VerifyPasswordResetCodeDto) {
    await this.findUserWithResetCode(dto.email, dto.code);
    return { message: 'Reset code verified successfully' };
  }

  async resetPassword(dto: ResetPasswordDto) {
    const { email, code, newPassword } = dto;
    const { user, challenge } = await this.findUserWithResetCode(email, code);
    const passwordHash = await bcrypt.hash(newPassword, 10);
    await this.prisma.$transaction(async (tx) => {
      const claimed = await tx.otp_challenges.updateMany({
        where: { id: challenge.id, consumed_at: null,
          expires_at: { gt: new Date() }, attempts: { lt: 5 } },
        data: { consumed_at: new Date() },
      });
      if (claimed.count !== 1) {
        throw new BadRequestException('Invalid or expired reset code.');
      }
      await tx.users.update({
        where: { id: user.id },
        data: { password_hash: passwordHash, updated_at: new Date() },
      });
    });

    return { message: 'Password reset successfully' };
  }

  async getProfile(userId: string) {
    const user = await this.usersService.findOne(userId);
    const { password, ...userWithoutPassword } = user as any;
    return userWithoutPassword;
  }

  async getPartnerAuthProfile(partner: Partner) {
    if ((partner as any).role === 'team_member') {
      const member = await this.teamService.findOne(partner.id, (partner as any).partnerId);
      return { member, userType: 'team_member', partner: undefined };
    }
    const fresh = await this.prisma.partners.findUnique({
      where: { id: partner.id },
      include: {
        partner_business_profiles: true,
        partner_users: { include: { users: true } },
        venues: {
          select: {
            id: true,
            status: true,
            approved_at: true,
            review_status: true,
            partner_venue_legal_documents: true,
          },
          orderBy: { id: 'asc' },
        },
      },
    });
    if (!fresh) throw new NotFoundException('Partner not found');

    const owner = fresh.partner_users[0];
    if (!owner) throw new NotFoundException('Partner user not found');
    const response = await this.buildPartnerAuthResponse(fresh, owner.users, owner.role);
    const business = fresh.partner_business_profiles;
    return {
      ...response,
      partner: {
        ...response.partner,
        isVerified: business?.kyc_status === 'APPROVED',
        panCardUrl: business?.pan_document_url ?? null,
        gstNumber: business?.gst_number ?? null,
        gstinDocUrl: business?.gst_document_url ?? null,
        gstIsVerified: business?.kyc_status === 'APPROVED' && Boolean(business?.gst_document_url),
        legalDocuments: (fresh.venues ?? []).map((venue) => {
          const legal = venue.partner_venue_legal_documents;
          const verified = venue.review_status === VenueStatus.APPROVED ||
            (!venue.review_status && venue.status === 'PUBLISHED');
          return {
            venueId: venue.id,
            isVerified: verified,
            aadhaarCardUrl: legal?.aadhaar_card_url ?? null,
            panCardUrl: legal?.pan_card_url ?? null,
            gstNumber: legal?.gst_number ?? null,
            gstName: legal?.gst_name ?? null,
            gstinDocUrl: legal?.gstin_doc_url ?? null,
            gstIsVerified: verified && Boolean(legal?.gstin_doc_url),
            documentsUpdatedAt: legal?.updated_at ?? null,
            aadhaarVerifiedAt: verified && legal?.aadhaar_card_url ? venue.approved_at : null,
            panVerifiedAt: verified && legal?.pan_card_url ? venue.approved_at : null,
            gstVerifiedAt: verified && legal?.gstin_doc_url ? venue.approved_at : null,
          };
        }),
      },
    };
  }

  private normalizePhone(phone: string): string {
    const digits = phone.replace(/\D/g, '');
    if (digits.length === 10) return `+91${digits}`;
    if (digits.length === 12 && digits.startsWith('91')) return `+${digits}`;
    if (digits.length < 10) throw new BadRequestException('Invalid phone number');
    return `+${digits}`;
  }

  private async buildPartnerAuthResponse(partner: any, user: any, role: any) {
    const tokens = await this.generatePartnerTokens(partner);
    const profile = partner.partner_business_profiles;
    const names = (user.name || '').trim().split(/\s+/);
    const isProfileComplete = Boolean(user.name && user.email);
    const isActive = partner.status === 'ACTIVE';

    return {
      partner: {
        id: partner.id,
        firstName: names[0] || null,
        lastName: names.slice(1).join(' ') || null,
        email: user.email,
        phone: user.phone_e164,
        businessName: profile?.business_name || partner.legal_name,
        isActive,
        avatarUrl: user.profile_photo ?? null,
        role,
      },
      userType: 'partner',
      ...tokens,
      jwt_token: tokens.accessToken,
      isProfileComplete,
      is_profile_completed: isProfileComplete,
      is_partner_active: isActive,
    };
  }

  // ─── Token Generation ──────────────────────────────────────────────────────

  private async generateUserTokens(user: {
    id: string;
    email: string | null;
    role: UserRole;
  }) {
    const payload = { sub: user.id, email: user.email, role: user.role, type: 'user' };

    const accessToken = this.jwtService.sign(payload, {
      secret: this.configService.get<string>('JWT_SECRET'),
      expiresIn: this.configService.get<string>('JWT_EXPIRY') || '7d',
    });

    return { accessToken };
  }

  private async generatePartnerTokens(partner: { id: string }) {
    const payload = { sub: partner.id, role: 'partner', type: 'partner' };

    const accessToken = this.jwtService.sign(payload, {
      secret: this.configService.get<string>('JWT_SECRET'),
      expiresIn: this.configService.get<string>('JWT_EXPIRY') || '7d',
    });

    return { accessToken };
  }
}
