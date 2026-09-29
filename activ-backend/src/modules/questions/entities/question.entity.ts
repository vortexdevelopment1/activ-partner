import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { QuestionType } from '../../../common/enums/question-type.enum';
import { Category } from '../../categories/entities/category.entity';

@Entity('questions')
export class Question {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'category_id', nullable: true })
  categoryId: string;

  @ManyToOne(() => Category, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'category_id' })
  category: Category;

  @Column({ name: 'question_text' })
  questionText: string;

  @Column({ name: 'question_type', type: 'enum', enum: QuestionType, default: QuestionType.TEXT })
  questionType: QuestionType;

  @Column({ type: 'json', nullable: true })
  options: string[];

  @Column({ name: 'is_required', default: false })
  isRequired: boolean;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @Column({ default: 0 })
  order: number;

  @Column({ nullable: true })
  placeholder: string;

  @Column({ name: 'helper_text', nullable: true })
  helperText: string;

  @Column({ name: 'min_length', type: 'int', nullable: true })
  minLength: number | null;

  @Column({ name: 'max_length', type: 'int', nullable: true })
  maxLength: number | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
