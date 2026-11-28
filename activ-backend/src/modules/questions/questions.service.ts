import { randomUUID } from "crypto";
import { Injectable, NotFoundException, Optional } from "@nestjs/common";

import { PartnerServiceQuestionType } from "../../generated/prisma/client";
import { PrismaService } from "../../prisma/prisma.service";
import { CACHE_TTL_SECONDS } from "../../common/redis/redis-cache.keys";
import { RedisCacheService } from "../../common/redis/redis-cache.service";
import { PaginationDto } from "../../common/dto/pagination.dto";
import { CreateQuestionDto } from "./dto/create-question.dto";
import { UpdateQuestionDto } from "./dto/update-question.dto";

@Injectable()
export class QuestionsService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly cache?: RedisCacheService,
  ) {}

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
            isActive: category.status === "APPROVED",
            order: category.sort_order,
          }
        : null,
      questionText: question.question,
      questionType: question.type.toLowerCase(),
      options: question.options,
      isRequired: question.is_required,
      isActive: true,
      order: question.sort_order,
      unit: question.unit ?? null,
      placeholder: question.placeholder ?? null,
      helperText: question.helper_text ?? null,
      minLength: question.min_length ?? null,
      maxLength: question.max_length ?? null,
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
        unit: dto.unit ?? null,
        placeholder: dto.placeholder ?? null,
        helper_text: dto.helperText ?? null,
        min_length: dto.minLength ?? null,
        max_length: dto.maxLength ?? null,
        is_required: dto.isRequired ?? false,
        sort_order: dto.order ?? 0,
        updated_at: new Date(),
      },
      include: { partner_service_categories: true },
    });
    await this.cache?.invalidateTags('questions');
    return this.mapQuestion(question);
  }

  async findAll(pagination: PaginationDto, categoryId?: string) {
    const where: any = {};
    if (categoryId) where.service_category_id = categoryId;
    if (pagination.search) {
      where.question = { contains: pagination.search, mode: "insensitive" };
    }
    const [questions, total] = await Promise.all([
      this.prisma.partner_service_questions.findMany({
        where,
        include: { partner_service_categories: true },
        skip: pagination.skip,
        take: pagination.limit,
        orderBy: [{ sort_order: "asc" }, { created_at: "desc" }],
      }),
      this.prisma.partner_service_questions.count({ where }),
    ]);
    return [
      questions.map((question) => this.mapQuestion(question)),
      total,
    ] as const;
  }

  async findByCategoryId(categoryId: string) {
    const fetcher = async () => {
      const questions = await this.prisma.partner_service_questions.findMany({
        where: {
          OR: [
            { service_category_id: categoryId },
            { service_category_id: null },
          ],
        },
        include: { partner_service_categories: true },
        orderBy: { sort_order: "asc" },
      });
      return questions
        .filter(
          (question) =>
            !["abcd", "abcde", "asdf2", "equipment available"].includes(
              question.question.trim().toLowerCase().replace(/\s+/g, " "),
            ),
        )
        .map((question) => this.mapQuestion(question));
    };
    if (!this.cache) return fetcher();
    return this.cache.getOrSet(
      this.cache.keys.masterQuestions(categoryId),
      CACHE_TTL_SECONDS.MASTER_QUESTIONS,
      fetcher,
      ['questions'],
    );
  }

  async findOne(id: string) {
    const question = await this.prisma.partner_service_questions.findUnique({
      where: { id },
      include: { partner_service_categories: true },
    });
    if (!question)
      throw new NotFoundException(`Question with id ${id} not found`);
    return this.mapQuestion(question);
  }

  async update(id: string, dto: UpdateQuestionDto) {
    await this.findOne(id);
    const question = await this.prisma.partner_service_questions.update({
      where: { id },
      data: {
        service_category_id:
          dto.categoryId === undefined ? undefined : dto.categoryId || null,
        question: dto.questionText,
        type: dto.questionType
          ? (dto.questionType.toUpperCase() as PartnerServiceQuestionType)
          : undefined,
        options: dto.options,
        unit: dto.unit,
        placeholder: dto.placeholder,
        helper_text: dto.helperText,
        min_length: dto.minLength,
        max_length: dto.maxLength,
        is_required: dto.isRequired,
        sort_order: dto.order,
        updated_at: new Date(),
      },
      include: { partner_service_categories: true },
    });
    await this.cache?.invalidateTags('questions');
    return this.mapQuestion(question);
  }

  async remove(id: string): Promise<void> {
    await this.findOne(id);
    await this.prisma.partner_service_questions.delete({ where: { id } });
    await this.cache?.invalidateTags('questions');
  }

  async toggleStatus(id: string) {
    return this.findOne(id);
  }

  async reorder(
    questionOrders: { id: string; order: number }[],
  ): Promise<void> {
    await this.prisma.$transaction(
      questionOrders.map(({ id, order }) =>
        this.prisma.partner_service_questions.update({
          where: { id },
          data: { sort_order: order, updated_at: new Date() },
        }),
      ),
    );
    await this.cache?.invalidateTags('questions');
  }
}
