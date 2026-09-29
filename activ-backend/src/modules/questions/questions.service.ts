import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like, IsNull } from 'typeorm';
import { Question } from './entities/question.entity';
import { CreateQuestionDto } from './dto/create-question.dto';
import { UpdateQuestionDto } from './dto/update-question.dto';
import { PaginationDto } from '../../common/dto/pagination.dto';

@Injectable()
export class QuestionsService {
  constructor(
    @InjectRepository(Question)
    private readonly questionRepository: Repository<Question>,
  ) {}

  async create(createQuestionDto: CreateQuestionDto): Promise<Question> {
    const question = this.questionRepository.create(createQuestionDto);
    return this.questionRepository.save(question);
  }

  async findAll(pagination: PaginationDto, categoryId?: string) {
    const where: any = {};
    if (categoryId) where.categoryId = categoryId;

    if (pagination.search) {
      return this.questionRepository.findAndCount({
        where: { ...where, questionText: Like(`%${pagination.search}%`) },
        relations: ['category'],
        skip: pagination.skip,
        take: pagination.limit,
        order: { order: 'ASC', createdAt: 'DESC' },
      });
    }

    return this.questionRepository.findAndCount({
      where,
      relations: ['category'],
      skip: pagination.skip,
      take: pagination.limit,
      order: { order: 'ASC', createdAt: 'DESC' },
    });
  }

  async findByCategoryId(categoryId: string): Promise<Question[]> {
    // Returns questions specific to category + global questions (no category)
    const [categoryQuestions, globalQuestions] = await Promise.all([
      this.questionRepository.find({
        where: { categoryId, isActive: true },
        order: { order: 'ASC' },
      }),
      this.questionRepository.find({
        where: { categoryId: IsNull(), isActive: true },
        order: { order: 'ASC' },
      }),
    ]);

    return [...globalQuestions, ...categoryQuestions];
  }

  async findOne(id: string): Promise<Question> {
    const question = await this.questionRepository.findOne({
      where: { id },
      relations: ['category'],
    });

    if (!question) {
      throw new NotFoundException(`Question with id ${id} not found`);
    }

    return question;
  }

  async update(id: string, updateQuestionDto: UpdateQuestionDto): Promise<Question> {
    const question = await this.findOne(id);
    Object.assign(question, updateQuestionDto);
    return this.questionRepository.save(question);
  }

  async remove(id: string): Promise<void> {
    const question = await this.findOne(id);
    await this.questionRepository.remove(question);
  }

  async toggleStatus(id: string): Promise<Question> {
    const question = await this.findOne(id);
    question.isActive = !question.isActive;
    return this.questionRepository.save(question);
  }

  async reorder(questionOrders: { id: string; order: number }[]): Promise<void> {
    await Promise.all(
      questionOrders.map(({ id, order }) =>
        this.questionRepository.update(id, { order }),
      ),
    );
  }
}
