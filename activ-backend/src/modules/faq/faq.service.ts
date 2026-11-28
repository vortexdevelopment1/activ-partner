import { Injectable, NotFoundException, Optional } from '@nestjs/common';
import { randomUUID } from 'crypto';
import type { faqs } from '../../generated/prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CACHE_TTL_SECONDS } from '../../common/redis/redis-cache.keys';
import { RedisCacheService } from '../../common/redis/redis-cache.service';
import type { FaqRecord as Faq } from '../../common/domain-types';
import { CreateFaqDto } from './dto/create-faq.dto';
import { UpdateFaqDto } from './dto/update-faq.dto';
import { PaginationDto } from '../../common/dto/pagination.dto';

@Injectable()
export class FaqService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly cache?: RedisCacheService,
  ) {}

  private toFaq(record: faqs): Faq {
    return {
      id: record.id,
      question: record.question,
      answer: record.answer,
      order: record.sort_order,
      isActive: record.status === 'PUBLISHED',
      createdAt: record.created_at,
      updatedAt: record.updated_at,
    };
  }

  async create(dto: CreateFaqDto): Promise<Faq> {
    const now = new Date();
    const isActive = dto.isActive ?? true;
    const record = await this.prisma.faqs.create({ data: {
      id: randomUUID(), question: dto.question, answer: dto.answer,
      sort_order: dto.order ?? 0,
      status: isActive ? 'PUBLISHED' : 'DRAFT',
      published_at: isActive ? now : null, updated_at: now,
    } });
    await this.cache?.invalidateTags('faqs');
    return this.toFaq(record);
  }

  async findAll(pagination: PaginationDto): Promise<[Faq[], number]> {
    const fetcher = async (): Promise<[Faq[], number]> => {
      const search = pagination.search?.trim();
      const where = search ? { OR: [
        { question: { contains: search, mode: 'insensitive' as const } },
        { answer: { contains: search, mode: 'insensitive' as const } },
      ] } : {};
      const [records, total] = await Promise.all([
        this.prisma.faqs.findMany({ where, skip: pagination.skip, take: pagination.limit,
          orderBy: [{ sort_order: 'asc' }, { created_at: 'desc' }, { id: 'asc' }] }),
        this.prisma.faqs.count({ where }),
      ]);
      return [records.map((record) => this.toFaq(record)), total];
    };
    if (!this.cache) return fetcher();
    return this.cache.getOrSet(
      this.cache.keys.masterFaqList({
        page: pagination.page,
        limit: pagination.limit,
        search: pagination.search,
      }),
      CACHE_TTL_SECONDS.MASTER_FAQ,
      fetcher,
      ['faqs'],
    );
  }

  async findAllActive(): Promise<Faq[]> {
    const fetcher = async () => {
      const records = await this.prisma.faqs.findMany({
        where: { status: 'PUBLISHED' },
        orderBy: [{ sort_order: 'asc' }, { created_at: 'desc' }, { id: 'asc' }],
      });
      return records.map((record) => this.toFaq(record));
    };
    if (!this.cache) return fetcher();
    return this.cache.getOrSet(
      this.cache.keys.masterFaqActive(),
      CACHE_TTL_SECONDS.MASTER_FAQ,
      fetcher,
      ['faqs'],
    );
  }

  async findOne(id: string): Promise<Faq> {
    const faq = await this.prisma.faqs.findUnique({ where: { id } });
    if (!faq) throw new NotFoundException('FAQ not found');
    return this.toFaq(faq);
  }

  async update(id: string, dto: UpdateFaqDto): Promise<Faq> {
    const faq = await this.findOne(id);
    const now = new Date();
    const record = await this.prisma.faqs.update({ where: { id }, data: {
      ...(dto.question !== undefined ? { question: dto.question } : {}),
      ...(dto.answer !== undefined ? { answer: dto.answer } : {}),
      ...(dto.order !== undefined ? { sort_order: dto.order } : {}),
      ...(dto.isActive !== undefined ? {
        status: dto.isActive ? 'PUBLISHED' : 'DRAFT',
        ...(!dto.isActive || !faq.isActive ? { published_at: dto.isActive ? now : null } : {}),
      } : {}),
      updated_at: now,
    } });
    await this.cache?.invalidateTags('faqs');
    return this.toFaq(record);
  }

  async remove(id: string): Promise<void> {
    await this.findOne(id);
    await this.prisma.faqs.delete({ where: { id } });
    await this.cache?.invalidateTags('faqs');
  }
}
