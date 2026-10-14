import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Partner } from '../../partners/entities/partner.entity';

export enum BankAccountStatus {
  UNDER_REVIEW = 'under_review',
  APPROVED     = 'approved',
  REJECTED     = 'rejected',
}

@Entity('bank_accounts')
export class BankAccount {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'partner_id' })
  partnerId: string;

  @ManyToOne(() => Partner, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'partner_id' })
  partner: Partner;

  @Column({ name: 'account_holder_name' })
  accountHolderName: string;

  @Column({ name: 'bank_name' })
  bankName: string;

  @Column({ name: 'account_number' })
  accountNumber: string;

  @Column({ name: 'ifsc_code' })
  ifscCode: string;

  @Column({ name: 'account_type' })
  accountType: string;

  @Column({ name: 'branch_name', nullable: true })
  branchName: string;

  @Column({ name: 'cancelled_cheque_url', nullable: true })
  cancelledChequeUrl: string;

  @Column({
    type: 'enum',
    enum: BankAccountStatus,
    default: BankAccountStatus.UNDER_REVIEW,
  })
  status: BankAccountStatus;

  @Column({ name: 'rejection_reason', nullable: true, type: 'text' })
  rejectionReason: string;

  @Column({ name: 'reviewed_by', nullable: true })
  reviewedBy: string;

  @Column({ name: 'reviewed_at', nullable: true, type: 'timestamp' })
  reviewedAt: Date;

  @Column({ name: 'has_seen_verified_screen', default: false })
  hasSeenVerifiedScreen: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
