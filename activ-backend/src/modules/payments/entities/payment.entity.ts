import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToOne,
} from 'typeorm';
import { PaymentStatus } from '../../../common/enums/booking-status.enum';
import { User } from '../../users/entities/user.entity';
import { Booking } from '../../bookings/entities/booking.entity';

@Entity('payments')
export class Payment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'booking_id' })
  bookingId: string;

  @OneToOne(() => Booking)
  @JoinColumn({ name: 'booking_id' })
  booking: Booking;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  amount: number;

  @Column({ default: 'INR' })
  currency: string;

  @Column({ name: 'payment_method', nullable: true })
  paymentMethod: string;

  @Column({ name: 'payment_gateway', nullable: true, default: 'razorpay' })
  paymentGateway: string;

  @Column({ name: 'transaction_id', nullable: true, unique: true })
  transactionId: string;

  @Column({ name: 'gateway_order_id', nullable: true })
  gatewayOrderId: string;

  @Column({ name: 'gateway_payment_id', nullable: true })
  gatewayPaymentId: string;

  @Column({ name: 'gateway_signature', nullable: true })
  gatewaySignature: string;

  @Column({
    type: 'enum',
    enum: PaymentStatus,
    default: PaymentStatus.PENDING,
  })
  status: PaymentStatus;

  @Column({ name: 'refund_amount', type: 'decimal', precision: 10, scale: 2, nullable: true })
  refundAmount: number;

  @Column({ name: 'refund_status', nullable: true })
  refundStatus: string;

  @Column({ name: 'refund_id', nullable: true })
  refundId: string;

  @Column({ type: 'json', nullable: true })
  metadata: any;

  @Column({ name: 'failure_reason', nullable: true })
  failureReason: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
