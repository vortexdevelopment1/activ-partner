import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TeamMember, TeamMemberStatus } from './entities/team-member.entity';
import { CreateTeamMemberDto } from './dto/create-team-member.dto';
import { UpdateTeamMemberDto } from './dto/update-team-member.dto';

@Injectable()
export class TeamService {
  constructor(
    @InjectRepository(TeamMember)
    private teamMemberRepository: Repository<TeamMember>,
  ) {}

  async findAll(partnerId: string): Promise<TeamMember[]> {
    return this.teamMemberRepository.find({
      where: { partnerId, isActive: true },
      order: { createdAt: 'DESC' },
    });
  }

  async findOne(id: string, partnerId: string): Promise<TeamMember> {
    const member = await this.teamMemberRepository.findOne({ where: { id, partnerId } });
    if (!member) throw new NotFoundException('Team member not found');
    return member;
  }

  async findByPhone(phone: string): Promise<TeamMember | null> {
    return this.teamMemberRepository.findOne({ where: { phone } });
  }

  // Kept for backward-compat with existing JWT strategy lookup
  async findByEmail(email: string): Promise<TeamMember | null> {
    return this.teamMemberRepository.findOne({ where: { email } });
  }

  async create(partnerId: string, dto: CreateTeamMemberDto): Promise<TeamMember> {
    const existing = await this.teamMemberRepository.findOne({ where: { phone: dto.phone } });
    if (existing) throw new ConflictException('A team member with this phone number already exists');

    const member = this.teamMemberRepository.create({
      partnerId,
      fullName: dto.fullName,
      phone: dto.phone,
      role: dto.role,
      // Random password — not used for login (team members authenticate via phone OTP)
      password: Math.random().toString(36).slice(-8) + 'A1!',
      permissions: {
        bookingManagement: dto.permissions?.bookingManagement ?? false,
        pricingControl: dto.permissions?.pricingControl ?? false,
        analyticsView: dto.permissions?.analyticsView ?? false,
      },
      status: TeamMemberStatus.INVITE_SENT,
    });

    const saved = await this.teamMemberRepository.save(member);

    // TODO: Send SMS/WhatsApp invite to dto.phone with app download link
    // await smsService.sendInvite({ phone: dto.phone, name: dto.fullName });

    return saved;
  }

  async update(id: string, partnerId: string, dto: UpdateTeamMemberDto): Promise<TeamMember> {
    const member = await this.findOne(id, partnerId);

    if (dto.phone && dto.phone !== member.phone) {
      const existing = await this.teamMemberRepository.findOne({ where: { phone: dto.phone } });
      if (existing) throw new ConflictException('Phone number is already in use by another team member');
    }

    if (dto.fullName) member.fullName = dto.fullName;
    if (dto.phone) member.phone = dto.phone;
    if (dto.role) member.role = dto.role;
    if (dto.permissions) {
      member.permissions = {
        bookingManagement: dto.permissions.bookingManagement ?? member.permissions.bookingManagement,
        pricingControl: dto.permissions.pricingControl ?? member.permissions.pricingControl,
        analyticsView: dto.permissions.analyticsView ?? member.permissions.analyticsView,
      };
    }

    return this.teamMemberRepository.save(member);
  }

  async remove(id: string, partnerId: string): Promise<void> {
    const member = await this.findOne(id, partnerId);
    await this.teamMemberRepository.remove(member);
  }

  async markActive(id: string): Promise<void> {
    await this.teamMemberRepository.update(id, { status: TeamMemberStatus.ACTIVE });
  }
}
