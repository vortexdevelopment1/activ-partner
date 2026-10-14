import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum VenueUpdateRequestStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

@Entity('venue_update_requests')
export class VenueUpdateRequest {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', name: 'venue_id' })
  venueId: string;

  @Column({ type: 'uuid', name: 'partner_id' })
  partnerId: string;

  @Column({ nullable: true })
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @Column({ nullable: true })
  address: string;

  @Column({ nullable: true })
  city: string;

  @Column({ nullable: true })
  state: string;

  @Column({ name: 'zip_code', nullable: true })
  zipCode: string;

  @Column({ name: 'flat_building', nullable: true })
  flatBuilding: string;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  latitude: number;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  longitude: number;

  @Column({ name: 'location_url', nullable: true })
  locationUrl: string;

  @Column({ name: 'venue_phone', nullable: true })
  venuePhone: string;

  @Column({
    type: 'enum',
    enum: VenueUpdateRequestStatus,
    default: VenueUpdateRequestStatus.PENDING,
  })
  status: VenueUpdateRequestStatus;

  @Column({ name: 'admin_notes', type: 'text', nullable: true })
  adminNotes: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
