import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';
import { CallbackStatus } from '../../../common/enums/callback-status.enum';

@Entity('callback_requests')
export class CallbackRequest {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid', nullable: true })
  partnerId: string;

  @Column()
  partnerName: string;

  @Column()
  email: string;

  @Column()
  phone: string;

  @Column()
  venueName: string;

  @Column()
  city: string;

  @Column({ type: 'date' })
  callbackDate: string;

  @Column()
  callbackTime: string;

  @Column({ type: 'text' })
  query: string;

  @Column({ type: 'enum', enum: CallbackStatus, default: CallbackStatus.PENDING })
  status: CallbackStatus;

  @Column({ type: 'text', nullable: true })
  adminNotes: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
