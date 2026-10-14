import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum LegalContentType {
  TERMS_AND_CONDITIONS = 'terms_and_conditions',
  PRIVACY_POLICY = 'privacy_policy',
  PARTNER_AGREEMENT = 'partner_agreement',
  REFUND_POLICY = 'refund_policy',
}

@Entity('legal_contents')
export class LegalContent {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'enum', enum: LegalContentType, unique: true })
  type: LegalContentType;

  @Column({ type: 'text' })
  content: string;

  @Column({ type: 'int', default: 1 })
  version: number;

  @Column({ type: 'uuid', nullable: true })
  updatedBy: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
