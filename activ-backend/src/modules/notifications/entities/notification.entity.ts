import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
} from 'typeorm';

export enum NotificationType {
  BOOKING_RECEIVED = 'booking_received',
  PAYMENT_RECEIVED = 'payment_received',
  ACTIVITY_APPROVED = 'activity_approved',
  ACTIVITY_REJECTED = 'activity_rejected',
  ACTIVITY_UNDER_REVIEW = 'activity_under_review',
  ADMIN_UPDATE = 'admin_update',
  VENUE_APPROVED = 'venue_approved',
}

@Entity('notifications')
export class Notification {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ type: 'uuid' })
  partnerId: string;

  @Column({ type: 'enum', enum: NotificationType })
  type: NotificationType;

  @Column()
  title: string;

  @Column({ type: 'text' })
  body: string;

  // Deep-link payload: bookingId / serviceId / payoutId etc.
  @Column({ type: 'jsonb', nullable: true })
  data: Record<string, any> | null;

  @Column({ default: false })
  isRead: boolean;

  @CreateDateColumn()
  createdAt: Date;
}
