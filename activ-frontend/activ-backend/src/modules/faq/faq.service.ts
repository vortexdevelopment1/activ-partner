import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Faq } from './entities/faq.entity';
import { CreateFaqDto } from './dto/create-faq.dto';
import { UpdateFaqDto } from './dto/update-faq.dto';
import { PaginationDto } from '../../common/dto/pagination.dto';

@Injectable()
export class FaqService {
  constructor(
    @InjectRepository(Faq)
    private readonly faqRepo: Repository<Faq>,
  ) {}

  async create(dto: CreateFaqDto): Promise<Faq> {
    const faq = this.faqRepo.create(dto);
    return this.faqRepo.save(faq);
  }

  async findAll(pagination: PaginationDto): Promise<[Faq[], number]> {
    const qb = this.faqRepo.createQueryBuilder('faq').orderBy('faq.order', 'ASC').addOrderBy('faq.createdAt', 'DESC');

    if (pagination.search) {
      qb.andWhere('(faq.question ILIKE :search OR faq.answer ILIKE :search)', {
        search: `%${pagination.search}%`,
      });
    }

    qb.skip(pagination.skip).take(pagination.limit);
    return qb.getManyAndCount();
  }

  async findAllActive(): Promise<Faq[]> {
    return this.faqRepo.find({
      where: { isActive: true },
      order: { order: 'ASC', createdAt: 'DESC' },
    });
  }

  async findOne(id: string): Promise<Faq> {
    const faq = await this.faqRepo.findOne({ where: { id } });
    if (!faq) throw new NotFoundException('FAQ not found');
    return faq;
  }

  async update(id: string, dto: UpdateFaqDto): Promise<Faq> {
    const faq = await this.findOne(id);
    Object.assign(faq, dto);
    return this.faqRepo.save(faq);
  }

  async remove(id: string): Promise<void> {
    const faq = await this.findOne(id);
    await this.faqRepo.remove(faq);
  }
}
