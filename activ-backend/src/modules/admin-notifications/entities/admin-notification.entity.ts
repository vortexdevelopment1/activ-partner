import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
} from 'typeorm';

export enum AdminNotificationType {
  VENUE_AUTO_DEACTIVATED = 'venue_auto_deactivated',
  ACTIVITY_ADDED = 'activity_added',
  ACTIVITY_REMOVED = 'activity_removed',
  VENUE_UPDATED = 'venue_updated',
  PARTNER_PROFILE_UPDATED = 'partner_profile_updated',
  VENUE_BOOKINGS_PAUSED = 'venue_bookings_paused',
  VENUE_BOOKINGS_RESUMED = 'venue_bookings_resumed',
}

@Entity('admin_notifications')
export class AdminNotification {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'enum', enum: AdminNotificationType })
  type: AdminNotificationType;

  @Column()
  title: string;

  @Column({ type: 'text' })
  body: string;

  // Deep-link payload: partnerId / venueId / serviceId etc.
  @Column({ type: 'jsonb', nullable: true })
  data: Record<string, any> | null;

  @Index()
  @Column({ default: false })
  isRead: boolean;

  @CreateDateColumn()
  createdAt: Date;
}
