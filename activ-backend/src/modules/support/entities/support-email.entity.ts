import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';
import { CallbackStatus } from '../../../common/enums/callback-status.enum';

@Entity('support_emails')
export class SupportEmail {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  partnerId: string;

  @Column()
  subject: string;

  @Column({ type: 'text' })
  message: string;

  @Column({ nullable: true })
  attachmentUrl: string;

  @Column({ nullable: true })
  attachmentOriginalName: string;

  @Column({ type: 'enum', enum: CallbackStatus, default: CallbackStatus.PENDING })
  status: CallbackStatus;

  @Column({ type: 'text', nullable: true })
  adminNotes: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
