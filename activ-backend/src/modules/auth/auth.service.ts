import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcryptjs';
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
import { ResetPasswordDto } from './dto/reset-password.dto';
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
    const { phone } = dto;
    const resendCooldown = new Date(Date.now() + 60 * 1000);

    // Check team member first — if this phone belongs to an invited team member,
    // send the OTP for the team member record and return early
    const teamMember = await this.teamMemberRepository.findOne({ where: { phone } });

    if (teamMember) {
      if (teamMember.otpExpiresAt && teamMember.otpExpiresAt > new Date()) {
        throw new BadRequestException('Please wait before requesting another OTP.');
      }
      await this.otpService.sendOtp(phone);
      teamMember.otpExpiresAt = resendCooldown;
      await this.teamMemberRepository.save(teamMember);
      return { phone };
    }

    // Otherwise treat as partner onboarding flow
    let partner = await this.partnerRepository.findOne({ where: { phone } });

    if (partner?.otpExpiresAt && partner.otpExpiresAt > new Date()) {
      throw new BadRequestException('Please wait before requesting another OTP.');
    }

    if (!partner) {
      partner = this.partnerRepository.create({
        phone,
        firstName: 'Partner',
        lastName: 'User',
        password: Math.random().toString(36).slice(-8) + 'A1!',
        isActive: false,
      });
    }

    await this.otpService.sendOtp(phone);
    partner.otpExpiresAt = resendCooldown;
    await this.partnerRepository.save(partner);

    return { phone };
  }

  async resendOtp(dto: RequestOtpDto) {
    const { phone } = dto;
    const resendCooldown = new Date(Date.now() + 60 * 1000);

    const teamMember = await this.teamMemberRepository.findOne({ where: { phone } });
    if (teamMember) {
      if (teamMember.otpExpiresAt && teamMember.otpExpiresAt > new Date()) {
        throw new BadRequestException('Please wait before requesting another OTP.');
      }
      await this.otpService.resendOtp(phone);
      teamMember.otpExpiresAt = resendCooldown;
      await this.teamMemberRepository.save(teamMember);
      return { phone };
    }

    const partner = await this.partnerRepository.findOne({ where: { phone } });
    if (!partner) {
      throw new BadRequestException('Phone number not found. Please request OTP first.');
    }
    if (partner.otpExpiresAt && partner.otpExpiresAt > new Date()) {
      throw new BadRequestException('Please wait before requesting another OTP.');
    }

    await this.otpService.resendOtp(phone);
    partner.otpExpiresAt = resendCooldown;
    await this.partnerRepository.save(partner);

    return { phone };
  }

  async verifyOtp(dto: VerifyOtpDto) {
    const { phone, otp } = dto;

    const teamMember = await this.teamMemberRepository.findOne({ where: { phone } });
    if (teamMember) {
      const isValid = await this.otpService.verifyOtp(phone, otp);
      if (!isValid) {
        throw new BadRequestException('Invalid or expired OTP.');
      }
      return this.completeTeamMemberLogin(teamMember);
    }

    const partner = await this.partnerRepository.findOne({ where: { phone } });
    if (!partner) {
      throw new BadRequestException('Phone number not found. Please request OTP first.');
    }

    const isValid = await this.otpService.verifyOtp(phone, otp);
    if (!isValid) {
      throw new BadRequestException('Invalid or expired OTP.');
    }

    return this.completePartnerLogin(partner);
  }

  private async completeTeamMemberLogin(teamMember: TeamMember) {
    teamMember.otpExpiresAt = null;
    teamMember.status = TeamMemberStatus.ACTIVE;
    await this.teamMemberRepository.save(teamMember);

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

    let venue = await this.venueRepository.findOne({
      where: { partnerId: teamMember.partnerId, status: VenueStatus.APPROVED },
      order: { createdAt: 'DESC' },
    });
    if (!venue) {
      venue = await this.venueRepository.findOne({
        where: { partnerId: teamMember.partnerId },
        order: { createdAt: 'DESC' },
      });
    }

    return {
      jwt_token,
      userType: 'team_member',
      role: teamMember.role,
      permissions: teamMember.permissions,
      venueId: venue?.id ?? null,
      venueName: venue?.name ?? null,
    };
  }

  private async completePartnerLogin(partner: Partner) {
    partner.otpExpiresAt = null;
    await this.partnerRepository.save(partner);

    const tokens = await this.generatePartnerTokens(partner);

    return {
      jwt_token: tokens.accessToken,
      userType: 'partner',
      is_profile_completed: !!partner.email,
      is_partner_active: partner.isActive,
    };
  }

  async completePartnerProfile(partnerId: string, dto: CompletePartnerProfileDto) {
    const partner = await this.partnerRepository.findOne({ where: { id: partnerId } });

    if (!partner) {
      throw new NotFoundException('Partner not found');
    }

    // Check email is not taken by another partner
    if (dto.email) {
      const existingEmail = await this.partnerRepository.findOne({
        where: { email: dto.email },
      });

      if (existingEmail && existingEmail.id !== partnerId) {
        throw new ConflictException('Email is already in use by another account');
      }
    }

    partner.firstName = dto.firstName;
    partner.lastName = dto.lastName;
    partner.email = dto.email;
    if (dto.businessName) partner.businessName = dto.businessName;
    if (dto.contactPhone) partner.contactPhone = dto.contactPhone;

    const saved = await this.partnerRepository.save(partner);
    const { password, phoneOtp, otpExpiresAt, resetPasswordCode, resetPasswordCodeExpiresAt, ...partnerWithoutSensitive } = saved as any;

    return { partner: partnerWithoutSensitive };
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
    const { email } = dto;
    const partner = await this.partnerRepository.findOne({ where: { email } });

    // Always return a generic success response so this endpoint can't be used to enumerate registered emails
    if (!partner) {
      return { message: 'If an account exists for this email, a reset code has been sent.' };
    }

    if (partner.resetPasswordCodeExpiresAt && partner.resetPasswordCodeExpiresAt > new Date()) {
      throw new BadRequestException('Please wait before requesting another reset code.');
    }

    const code = Math.floor(1000 + Math.random() * 9000).toString();
    partner.resetPasswordCode = code;
    partner.resetPasswordCodeExpiresAt = new Date(Date.now() + 10 * 60 * 1000);
    await this.partnerRepository.save(partner);

    await this.mailService.sendPasswordResetEmail({
      toEmail: partner.email,
      firstName: partner.firstName || 'there',
      code,
    });

    return { message: 'If an account exists for this email, a reset code has been sent.' };
  }

  async resetPassword(dto: ResetPasswordDto) {
    const { email, code, newPassword } = dto;
    const partner = await this.partnerRepository.findOne({ where: { email } });

    if (!partner || !partner.resetPasswordCode) {
      throw new BadRequestException('Invalid or expired reset code.');
    }

    if (
      partner.resetPasswordCode !== code ||
      !partner.resetPasswordCodeExpiresAt ||
      partner.resetPasswordCodeExpiresAt < new Date()
    ) {
      throw new BadRequestException('Invalid or expired reset code.');
    }

    // Assigning triggers the @BeforeUpdate hook which hashes the new value
    partner.password = newPassword;
    partner.resetPasswordCode = null;
    partner.resetPasswordCodeExpiresAt = null;
    await this.partnerRepository.save(partner);

    return { message: 'Password reset successfully' };
  }

  async getProfile(userId: string) {
    const user = await this.usersService.findOne(userId);
    const { password, ...userWithoutPassword } = user as any;
    return userWithoutPassword;
  }

  async getPartnerAuthProfile(partner: Partner) {
    const fresh = await this.partnerRepository.findOne({ where: { id: partner.id } });
    const tokens = await this.generatePartnerTokens(fresh);
    const { password, phoneOtp, otpExpiresAt, resetPasswordCode, resetPasswordCodeExpiresAt, ...partnerWithoutSensitive } = fresh as any;

    return {
      partner: partnerWithoutSensitive,
      ...tokens,
      isProfileComplete: !!fresh.email,
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
