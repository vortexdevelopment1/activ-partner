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

@Entity('partner_gst_verification_requests')
export class GstVerificationRequest {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'partner_id', type: 'uuid' })
  partnerId: string;

  @Column({ name: 'gst_number', type: 'text' })
  gstNumber: string;

  @Column({ name: 'legal_name', type: 'text', nullable: true })
  gstName: string;

  @Column({ name: 'document_url', type: 'text', nullable: true })
  gstDocUrl: string;

  @Column({
    type: 'enum',
    enum: ['PENDING', 'APPROVED', 'REJECTED'],
    enumName: 'PartnerKycStatus',
    default: 'PENDING',
    // Keep the public API lowercase while using the shared database enum.
    transformer: {
      to: (value: GstVerificationStatus | null | undefined) => value?.toUpperCase() ?? value,
      from: (value: string | null) => value?.toLowerCase() ?? value,
    },
  })
  status: GstVerificationStatus;

  @Column({ name: 'rejection_reason', type: 'text', nullable: true })
  adminNotes: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
