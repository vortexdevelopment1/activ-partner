import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like } from 'typeorm';
import { Category } from './entities/category.entity';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { PaginationDto } from '../../common/dto/pagination.dto';

@Injectable()
export class CategoriesService {
  constructor(
    @InjectRepository(Category)
    private readonly categoryRepository: Repository<Category>,
  ) {}

  async create(createCategoryDto: CreateCategoryDto): Promise<Category> {
    const existing = await this.categoryRepository.findOne({
      where: { name: createCategoryDto.name },
    });

    if (existing) {
      throw new ConflictException(`Category '${createCategoryDto.name}' already exists`);
    }

    const category = this.categoryRepository.create(createCategoryDto);
    return this.categoryRepository.save(category);
  }

  async findAll(pagination: PaginationDto, activeOnly = false) {
    const where: any = {};
    if (activeOnly) where.isActive = true;

    if (pagination.search) {
      return this.categoryRepository.findAndCount({
        where: { ...where, name: Like(`%${pagination.search}%`) },
        skip: pagination.skip,
        take: pagination.limit,
        order: { order: 'ASC', createdAt: 'DESC' },
      });
    }

    return this.categoryRepository.findAndCount({
      where,
      skip: pagination.skip,
      take: pagination.limit,
      order: { order: 'ASC', createdAt: 'DESC' },
    });
  }

  async findAllActive(): Promise<Category[]> {
    return this.categoryRepository.find({
      where: { isActive: true },
      order: { order: 'ASC' },
    });
  }

  async findOne(id: string): Promise<Category> {
    const category = await this.categoryRepository.findOne({ where: { id } });
    if (!category) {
      throw new NotFoundException(`Category with id ${id} not found`);
    }
    return category;
  }

  async update(id: string, updateCategoryDto: UpdateCategoryDto): Promise<Category> {
    const category = await this.findOne(id);

    if (updateCategoryDto.name && updateCategoryDto.name !== category.name) {
      const existing = await this.categoryRepository.findOne({
        where: { name: updateCategoryDto.name },
      });
      if (existing) {
        throw new ConflictException(`Category '${updateCategoryDto.name}' already exists`);
      }
    }

    Object.assign(category, updateCategoryDto);
    return this.categoryRepository.save(category);
  }

  async remove(id: string): Promise<void> {
    const category = await this.findOne(id);
    await this.categoryRepository.remove(category);
  }

  async toggleStatus(id: string): Promise<Category> {
    const category = await this.findOne(id);
    category.isActive = !category.isActive;
    return this.categoryRepository.save(category);
  }
}
