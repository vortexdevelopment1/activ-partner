import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum GstVerificationStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

@Entity('gst_verification_requests')
export class GstVerificationRequest {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  partnerId: string;

  @Column()
  gstNumber: string;

  @Column()
  gstName: string;

  @Column({ nullable: true })
  gstDocUrl: string;

  @Column({
    type: 'enum',
    enum: GstVerificationStatus,
    default: GstVerificationStatus.PENDING,
  })
  status: GstVerificationStatus;

  @Column({ type: 'text', nullable: true })
  adminNotes: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
