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
import { VenueService } from './venue-service.entity';
import { Question } from '../../questions/entities/question.entity';

@Entity('venue_answers')
export class VenueAnswer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'venue_id' })
  venueId: string;

  @ManyToOne(() => Venue, (venue) => venue.answers, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'venue_id' })
  venue: Venue;

  // Null for answers captured during the original venue-onboarding wizard.
  // Set for answers captured via the per-activity (VenueService) wizard so
  // two activities sharing a global question don't overwrite each other.
  @Column({ name: 'venue_service_id', nullable: true })
  venueServiceId: string;

  @ManyToOne(() => VenueService, { nullable: true, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'venue_service_id' })
  venueService: VenueService;

  @Column({ name: 'question_id' })
  questionId: string;

  @ManyToOne(() => Question)
  @JoinColumn({ name: 'question_id' })
  question: Question;

  @Column({ type: 'json' })
  answer: any;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
