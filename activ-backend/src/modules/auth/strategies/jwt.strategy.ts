import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UsersService } from '../../users/users.service';
import { TeamMember } from '../../team/entities/team-member.entity';
import { PrismaService } from '../../../prisma/prisma.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    configService: ConfigService,
    private usersService: UsersService,
    private prisma: PrismaService,
    @InjectRepository(TeamMember)
    private teamMemberRepository: Repository<TeamMember>,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_SECRET'),
    });
  }

  async validate(payload: { sub: string; role: string; type?: string }) {
    if (payload.type === 'team_member') {
      const staff = await this.prisma.partner_staff_profiles.findUnique({ where: { id: payload.sub },
        include: { partner_users: { include: { users: true, partners: true } } } });
      if (!staff) throw new UnauthorizedException('Team member not found');
      const settings = staff.permissions as Record<string, any>;
      if (settings.isActive === false || staff.partner_users.users.status !== 'ACTIVE' || staff.partner_users.partners.status === 'SUSPENDED') {
        throw new UnauthorizedException('Account has been deactivated');
      }
      return { id: staff.id, partnerId: staff.partner_users.partner_id, role: 'team_member',
        permissions: { bookingManagement: settings.bookingManagement === true,
          pricingControl: settings.pricingControl === true, analyticsView: settings.analyticsView === true } };
    }

    if (payload.type === 'partner') {
      const partner = await this.prisma.partners.findUnique({
        where: { id: payload.sub },
        include: {
          partner_business_profiles: true,
          partner_users: { include: { users: true } },
        },
      });
      if (!partner) throw new UnauthorizedException('Partner not found');
      if (partner.status === 'SUSPENDED') {
        throw new UnauthorizedException('Account has been deactivated');
      }

      const partnerUser = partner.partner_users.find(
        (link) => link.users.status === 'ACTIVE',
      );
      if (!partnerUser) throw new UnauthorizedException('Partner user not found');

      const profile = partner.partner_business_profiles;
      return {
        id: partner.id,
        userId: partnerUser.user_id,
        email: partnerUser.users.email,
        phone: partnerUser.users.phone_e164,
        businessName: profile?.business_name || partner.legal_name,
        isActive: partner.status === 'ACTIVE',
        role: 'partner',
      };
    }

    // User (admin / user role)
    const user = await this.prisma.users.findUnique({
      where: { id: payload.sub },
    });

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    if (user.status !== 'ACTIVE') {
      throw new UnauthorizedException('Your account has been deactivated');
    }

    return {
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone_e164,
      role: user.is_admin ? 'admin' : 'user',
      isActive: true,
      profileImage: user.profile_photo,
    };
  }
}
