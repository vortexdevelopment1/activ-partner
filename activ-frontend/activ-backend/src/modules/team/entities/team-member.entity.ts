import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  BeforeInsert,
  BeforeUpdate,
} from 'typeorm';
import { Exclude } from 'class-transformer';
import * as bcrypt from 'bcryptjs';
import { Partner } from '../../partners/entities/partner.entity';
import { TeamMemberRole } from '../../../common/enums/team-member-role.enum';

export enum TeamMemberStatus {
  INVITE_SENT = 'invite_sent',
  ACTIVE = 'active',
}

export interface TeamMemberPermissions {
  bookingManagement: boolean;
  pricingControl: boolean;
  analyticsView: boolean;
}

@Entity('team_members')
export class TeamMember {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'partner_id' })
  partnerId: string;

  @ManyToOne(() => Partner, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'partner_id' })
  partner: Partner;

  @Column({ name: 'full_name' })
  fullName: string;

  @Column({ nullable: true })
  email: string;

  @Column({ unique: true })
  phone: string;

  @Column({ name: 'phone_otp', nullable: true })
  @Exclude()
  phoneOtp: string;

  @Column({ name: 'otp_expires_at', nullable: true, type: 'timestamp' })
  @Exclude()
  otpExpiresAt: Date;

  @Column()
  @Exclude()
  password: string;

  @Column({ type: 'enum', enum: TeamMemberRole, default: TeamMemberRole.STAFF })
  role: TeamMemberRole;

  @Column({ type: 'jsonb', default: { bookingManagement: false, pricingControl: false, analyticsView: false } })
  permissions: TeamMemberPermissions;

  @Column({ type: 'enum', enum: TeamMemberStatus, default: TeamMemberStatus.INVITE_SENT })
  status: TeamMemberStatus;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @BeforeInsert()
  @BeforeUpdate()
  async hashPassword() {
    if (this.password && !this.password.startsWith('$2')) {
      this.password = await bcrypt.hash(this.password, 10);
    }
  }

  async validatePassword(password: string): Promise<boolean> {
    return bcrypt.compare(password, this.password);
  }

  // Non-DB field used by RolesGuard
  get roleForGuard(): string {
    return 'team_member';
  }
}
