import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('city_commissions')
export class CityCommission {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  city: string;

  @Column({ name: 'commission_percentage', type: 'decimal', precision: 5, scale: 2 })
  commissionPercentage: number;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
