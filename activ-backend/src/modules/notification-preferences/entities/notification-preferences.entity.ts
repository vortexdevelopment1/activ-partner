import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Partner } from '../../partners/entities/partner.entity';

@Entity('partner_notification_preferences')
export class NotificationPreferences {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'partner_id', unique: true })
  partnerId: string;

  @ManyToOne(() => Partner, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'partner_id' })
  partner: Partner;

  @Column({ name: 'enable_all_notifications', default: true })
  enableAllNotifications: boolean;

  @Column({ name: 'booking_notifications', default: true })
  bookingNotifications: boolean;

  @Column({ name: 'payment_updates', default: false })
  paymentUpdates: boolean;

  @Column({ name: 'approval_updates', default: false })
  approvalUpdates: boolean;

  @Column({ name: 'promotional_messages', default: false })
  promotionalMessages: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
