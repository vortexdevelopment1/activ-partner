import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Venue } from './venue.entity';
import { Category } from '../../categories/entities/category.entity';
import { VenueServiceStatus } from '../../../common/enums/venue-service-status.enum';

@Entity('venue_services')
export class VenueService {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'venue_id' })
  venueId: string;

  @ManyToOne(() => Venue, (venue) => venue.services, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'venue_id' })
  venue: Venue;

  @Column({ name: 'category_id', nullable: true })
  categoryId: string;

  @ManyToOne(() => Category, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'category_id' })
  category: Category;

  @Column()
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @Column({ name: 'price_per_hour', type: 'decimal', precision: 10, scale: 2 })
  pricePerHour: number;

  @Column({ name: 'min_duration', default: 60, comment: 'Minimum booking duration in minutes' })
  minDuration: number;

  @Column({ name: 'max_duration', nullable: true, comment: 'Max booking duration in minutes' })
  maxDuration: number;

  @Column({ nullable: true })
  capacity: number;

  @Column({ name: 'image_url', nullable: true })
  imageUrl: string;

  @Column({ name: 'image_urls', type: 'jsonb', default: [] })
  imageUrls: string[];

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  // Per-activity approval lifecycle, independent of the parent Venue.status.
  // A Venue is approved once at onboarding; each Activity added afterward
  // goes through its own draft -> pending -> approved/rejected review.
  @Column({ type: 'enum', enum: VenueServiceStatus, default: VenueServiceStatus.DRAFT })
  status: VenueServiceStatus;

  @Column({ type: 'json', nullable: true })
  amenities: string[];

  @Column({ name: 'rejection_reason', nullable: true, type: 'text' })
  rejectionReason: string;

  @Column({ name: 'pause_reason', nullable: true, type: 'text' })
  pauseReason: string;

  @Column({ name: 'submitted_at', nullable: true, type: 'timestamp' })
  submittedAt: Date;

  @Column({ name: 'approved_at', nullable: true, type: 'timestamp' })
  approvedAt: Date;

  @Column({ name: 'approved_by', nullable: true })
  approvedBy: string;

  // Court names for activities that have multiple physical courts (e.g. Badminton, Football)
  // Null for activities without courts (e.g. Gym, Swimming)
  @Column({ type: 'json', nullable: true })
  courts: string[];

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
