import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  BeforeInsert,
  BeforeUpdate,
} from 'typeorm';
import { Exclude } from 'class-transformer';
import * as bcrypt from 'bcryptjs';

@Entity('partners')
export class Partner {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  // ─── Auth Fields ───────────────────────────────────────────────────────────

  @Column({ name: 'first_name', nullable: true })
  firstName: string;

  @Column({ name: 'last_name', nullable: true })
  lastName: string;

  @Column({ unique: true, nullable: true })
  email: string;

  @Column({ nullable: true })
  @Exclude()
  password: string;

  @Column({ nullable: true })
  phone: string;

  @Column({ name: 'is_active', default: false })
  isActive: boolean;

  @Column({ name: 'phone_otp', nullable: true })
  @Exclude()
  phoneOtp: string;

  @Column({ name: 'otp_expires_at', nullable: true, type: 'timestamp' })
  @Exclude()
  otpExpiresAt: Date;

  @Column({ name: 'reset_password_code', nullable: true })
  @Exclude()
  resetPasswordCode: string;

  @Column({ name: 'reset_password_code_expires_at', nullable: true, type: 'timestamp' })
  @Exclude()
  resetPasswordCodeExpiresAt: Date;

  // Not a DB column — used by RolesGuard and JWT strategy
  role: string = 'partner';

  // ─── Business Fields ───────────────────────────────────────────────────────

  @Column({ name: 'business_name', nullable: true })
  businessName: string;

  @Column({ name: 'business_description', nullable: true, type: 'text' })
  businessDescription: string;

  @Column({ name: 'business_address', nullable: true })
  businessAddress: string;

  @Column({ nullable: true })
  city: string;

  @Column({ nullable: true })
  state: string;

  @Column({ nullable: true })
  country: string;

  @Column({ name: 'contact_phone', nullable: true })
  contactPhone: string;

  @Column({ name: 'zip_code', nullable: true })
  zipCode: string;

  @Column({ name: 'gst_number', nullable: true })
  gstNumber: string;

  @Column({ name: 'gst_name', nullable: true })
  gstName: string;

  @Column({ name: 'pan_number', nullable: true })
  panNumber: string;

  @Column({ name: 'bank_account_number', nullable: true })
  bankAccountNumber: string;

  @Column({ name: 'bank_ifsc_code', nullable: true })
  bankIfscCode: string;

  @Column({ name: 'bank_account_holder_name', nullable: true })
  bankAccountHolderName: string;

  @Column({ name: 'aadhaar_name', nullable: true })
  aadhaarName: string;

  @Column({ name: 'aadhaar_number', nullable: true })
  aadhaarNumber: string;

  @Column({ name: 'pan_card_url', nullable: true })
  panCardUrl: string;

  @Column({ name: 'aadhaar_card_url', nullable: true })
  aadhaarCardUrl: string;

  @Column({ name: 'gstin_doc_url', nullable: true })
  gstinDocUrl: string;

  @Column({ name: 'is_verified', default: false })
  isVerified: boolean;

  @Column({ type: 'json', nullable: true })
  documents: string[];

  @Column({ name: 'logo_url', nullable: true })
  logoUrl: string;

  @Column({ name: 'avatar_url', nullable: true })
  avatarUrl: string;

  @Column({ name: 'aadhaar_verified_at', type: 'timestamp', nullable: true })
  aadhaarVerifiedAt: Date;

  @Column({ name: 'pan_verified_at', type: 'timestamp', nullable: true })
  panVerifiedAt: Date;

  @Column({ name: 'gst_verified_at', type: 'timestamp', nullable: true })
  gstVerifiedAt: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @BeforeInsert()
  @BeforeUpdate()
  async hashPassword() {
    if (this.password && !this.password.startsWith('$2')) {
      this.password = await bcrypt.hash(this.password, 10);
    }
  }

  async validatePassword(password: string): Promise<boolean> {
    return bcrypt.compare(password, this.password);
  }

  get fullName(): string {
    return `${this.firstName || ''} ${this.lastName || ''}`.trim();
  }
}
