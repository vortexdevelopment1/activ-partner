import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { VenueService } from './venue-service.entity';
import { Venue } from './venue.entity';

@Entity('walk_in_reservations')
export class WalkInReservation {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'venue_service_id' })
  venueServiceId: string;

  @ManyToOne(() => VenueService, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'venue_service_id' })
  venueService: VenueService;

  @Column({ name: 'venue_id' })
  venueId: string;

  @ManyToOne(() => Venue, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'venue_id' })
  venue: Venue;

  // partner user ID (matches venue.partnerId)
  @Column({ name: 'partner_id' })
  partnerId: string;

  // Only set for activities that have courts configured
  @Column({ nullable: true })
  court: string;

  // YYYY-MM-DD
  @Column({ type: 'date' })
  date: string;

  // Array of { startTime: "HH:mm", endTime: "HH:mm" }
  @Column({ type: 'json' })
  slots: Array<{ startTime: string; endTime: string }>;

  @Column({ name: 'participant_name' })
  participantName: string;

  @Column({ name: 'participant_phone' })
  participantPhone: string;

  @Column({ name: 'participant_email', nullable: true })
  participantEmail: string;

  // 'reserved' = active block; 'released' = freed back to ACTIV
  @Column({ type: 'varchar', length: 10, default: 'reserved' })
  status: 'reserved' | 'released';

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
