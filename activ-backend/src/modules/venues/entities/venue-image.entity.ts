import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Venue } from './venue.entity';

@Entity('venue_images')
export class VenueImage {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'venue_id' })
  venueId: string;

  @ManyToOne(() => Venue, (venue) => venue.images, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'venue_id' })
  venue: Venue;

  @Column({ name: 'image_url' })
  imageUrl: string;

  @Column({ name: 'is_primary', default: false })
  isPrimary: boolean;

  @Column({ nullable: true })
  caption: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
