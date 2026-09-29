import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UsersService } from '../../users/users.service';
import { Partner } from '../../partners/entities/partner.entity';
import { TeamMember } from '../../team/entities/team-member.entity';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    configService: ConfigService,
    private usersService: UsersService,
    @InjectRepository(Partner)
    private partnerRepository: Repository<Partner>,
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
      const member = await this.teamMemberRepository.findOne({ where: { id: payload.sub } });
      if (!member) throw new UnauthorizedException('Team member not found');
      if (!member.isActive) throw new UnauthorizedException('Account has been deactivated');
      // Attach role string so RolesGuard can read it
      (member as any).role = 'team_member';
      return member;
    }

    if (payload.type === 'partner') {
      const partner = await this.partnerRepository.findOne({ where: { id: payload.sub } });
      if (!partner) throw new UnauthorizedException('Partner not found');
      // Inactive partners are allowed during onboarding
      return partner;
    }

    // User (admin / user role)
    const user = await this.usersService.findOne(payload.sub);

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    if (!user.isActive) {
      throw new UnauthorizedException('Your account has been deactivated');
    }

    return user;
  }
}
