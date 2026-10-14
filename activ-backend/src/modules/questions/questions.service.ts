import { randomUUID } from 'crypto';
import { Injectable, NotFoundException } from '@nestjs/common';

import { PartnerServiceQuestionType } from '../../generated/prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { CreateQuestionDto } from './dto/create-question.dto';
import { UpdateQuestionDto } from './dto/update-question.dto';

@Injectable()
export class QuestionsService {
  constructor(private readonly prisma: PrismaService) {}

  private mapQuestion(question: any) {
    const category = question.partner_service_categories;
    return {
      id: question.id,
      categoryId: question.service_category_id,
      category: category
        ? {
            id: category.id,
            name: category.name,
            description: category.description,
            isActive: category.status === 'APPROVED',
            order: category.sort_order,
          }
        : null,
      questionText: question.question,
      questionType: question.type.toLowerCase(),
      options: question.options,
      isRequired: question.is_required,
      isActive: true,
      order: question.sort_order,
      placeholder: null,
      helperText: null,
      minLength: null,
      maxLength: null,
      createdAt: question.created_at,
      updatedAt: question.updated_at,
    };
  }

  async create(dto: CreateQuestionDto) {
    const question = await this.prisma.partner_service_questions.create({
      data: {
        id: randomUUID(),
        service_category_id: dto.categoryId || null,
        question: dto.questionText,
        type: dto.questionType.toUpperCase() as PartnerServiceQuestionType,
        options: dto.options || [],
        is_required: dto.isRequired ?? false,
        sort_order: dto.order ?? 0,
        updated_at: new Date(),
      },
      include: { partner_service_categories: true },
    });
    return this.mapQuestion(question);
  }

  async findAll(pagination: PaginationDto, categoryId?: string) {
    const where: any = {};
    if (categoryId) where.service_category_id = categoryId;
    if (pagination.search) {
      where.question = { contains: pagination.search, mode: 'insensitive' };
    }
    const [questions, total] = await Promise.all([
      this.prisma.partner_service_questions.findMany({
        where,
        include: { partner_service_categories: true },
        skip: pagination.skip,
        take: pagination.limit,
        orderBy: [{ sort_order: 'asc' }, { created_at: 'desc' }],
      }),
      this.prisma.partner_service_questions.count({ where }),
    ]);
    return [questions.map((question) => this.mapQuestion(question)), total] as const;
  }

  async findByCategoryId(categoryId: string) {
    const questions = await this.prisma.partner_service_questions.findMany({
      where: { OR: [{ service_category_id: categoryId }, { service_category_id: null }] },
      include: { partner_service_categories: true },
      orderBy: { sort_order: 'asc' },
    });
    return questions.map((question) => this.mapQuestion(question));
  }

  async findOne(id: string) {
    const question = await this.prisma.partner_service_questions.findUnique({
      where: { id },
      include: { partner_service_categories: true },
    });
    if (!question) throw new NotFoundException(`Question with id ${id} not found`);
    return this.mapQuestion(question);
  }

  async update(id: string, dto: UpdateQuestionDto) {
    await this.findOne(id);
    const question = await this.prisma.partner_service_questions.update({
      where: { id },
      data: {
        service_category_id: dto.categoryId === undefined ? undefined : dto.categoryId || null,
        question: dto.questionText,
        type: dto.questionType
          ? (dto.questionType.toUpperCase() as PartnerServiceQuestionType)
          : undefined,
        options: dto.options,
        is_required: dto.isRequired,
        sort_order: dto.order,
        updated_at: new Date(),
      },
      include: { partner_service_categories: true },
    });
    return this.mapQuestion(question);
  }

  async remove(id: string): Promise<void> {
    await this.findOne(id);
    await this.prisma.partner_service_questions.delete({ where: { id } });
  }

  async toggleStatus(id: string) {
    return this.findOne(id);
  }

  async reorder(questionOrders: { id: string; order: number }[]): Promise<void> {
    await this.prisma.$transaction(
      questionOrders.map(({ id, order }) =>
        this.prisma.partner_service_questions.update({
          where: { id },
          data: { sort_order: order, updated_at: new Date() },
        }),
      ),
    );
  }
}
