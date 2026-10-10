import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  ManyToMany,
  JoinTable,
  OneToMany,
  JoinColumn,
} from 'typeorm';
import { VenueStatus } from '../../../common/enums/venue-status.enum';
import { Partner } from '../../partners/entities/partner.entity';
import { Category } from '../../categories/entities/category.entity';
import { VenueImage } from './venue-image.entity';
import { VenueService } from './venue-service.entity';
import { VenueAnswer } from './venue-answer.entity';

@Entity('venues')
export class Venue {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'partner_id' })
  partnerId: string;

  @ManyToOne(() => Partner)
  @JoinColumn({ name: 'partner_id' })
  partner: Partner;

  @ManyToMany(() => Category, { eager: false })
  @JoinTable({
    name: 'venue_categories',
    joinColumn: { name: 'venue_id', referencedColumnName: 'id' },
    inverseJoinColumn: { name: 'category_id', referencedColumnName: 'id' },
  })
  categories: Category[];

  @Column()
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @Column({ nullable: true })
  address: string;

  @Column({ nullable: true })
  city: string;

  @Column({ nullable: true })
  state: string;

  @Column({ default: 'India' })
  country: string;

  @Column({ name: 'zip_code', nullable: true })
  zipCode: string;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  latitude: number;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  longitude: number;

  @Column({ name: 'opening_time', nullable: true })
  openingTime: string;

  @Column({ name: 'closing_time', nullable: true })
  closingTime: string;

  // Per-category day-wise availability: { catId: [{ day, slots: [{ openTime, closeTime, capacity }] }] }
  @Column({ name: 'availability', type: 'jsonb', nullable: true })
  availability: Record<string, Array<{ day: string; slots: Array<{ openTime: string; closeTime: string; capacity: number; price: number; discountedPrice: number }> }>>;

  @Column({ type: 'json', nullable: true })
  amenities: string[];

  @Column({ type: 'text', nullable: true })
  rules: string;

  @Column({ name: 'phone', nullable: true })
  phone: string;

  @Column({ name: 'venue_phone', nullable: true })
  venuePhone: string;

  @Column({ name: 'location_url', nullable: true })
  locationUrl: string;

  @Column({ name: 'flat_building', nullable: true })
  flatBuilding: string;

  @Column({ name: 'venue_address', nullable: true })
  venueAddress: string;

  @Column({ name: 'terms_accepted', default: false })
  termsAccepted: boolean;

  @Column({ name: 'terms_accepted_at', nullable: true, type: 'timestamp' })
  termsAcceptedAt: Date;

  @Column({ name: 'electronic_signature', nullable: true })
  electronicSignature: string;

  @Column({ type: 'enum', enum: VenueStatus, default: VenueStatus.DRAFT })
  status: VenueStatus;

  @Column({ name: 'rejection_reason', nullable: true, type: 'text' })
  rejectionReason: string;

  @Column({ name: 'approved_at', nullable: true })
  approvedAt: Date;

  @Column({ name: 'approved_by', nullable: true })
  approvedBy: string;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @Column({ name: 'booking_accept', default: true })
  bookingAccept: boolean;

  @Column({ name: 'has_seen_welcome', default: false })
  hasSeenWelcome: boolean;

  @Column({ type: 'decimal', precision: 5, scale: 2, default: 10 })
  commission: number;

  @OneToMany(() => VenueImage, (image) => image.venue, { cascade: true })
  images: VenueImage[];

  @OneToMany(() => VenueService, (service) => service.venue, { cascade: true })
  services: VenueService[];

  @OneToMany(() => VenueAnswer, (answer) => answer.venue, { cascade: true })
  answers: VenueAnswer[];

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
