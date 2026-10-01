import { randomUUID } from 'crypto';
import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';

import {
  ActivityType,
  CatalogueStatus,
  PartnerVenueServiceStatus,
} from '../../generated/prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';

const slugify = (name: string) =>
  name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');

const toActivityType = (type?: string): ActivityType => {
  const types: Record<string, ActivityType> = {
    single_booking: ActivityType.SINGLE,
    court_booking: ActivityType.COURT,
    turf_booking: ActivityType.TURF,
    table_booking: ActivityType.TABLE,
    cricket_nets_booking: ActivityType.CRICKET_NETS,
  };
  return types[type || ''] || ActivityType.SINGLE;
};

const fromActivityType = (type?: ActivityType): string => {
  const types: Record<ActivityType, string> = {
    SINGLE: 'single_booking',
    COURT: 'court_booking',
    TURF: 'turf_booking',
    TABLE: 'table_booking',
    CRICKET_NETS: 'cricket_nets_booking',
  };
  return types[type || ActivityType.SINGLE];
};

@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  private mapCategory(category: any, activity?: { type: ActivityType }) {
    return {
      id: category.id,
      name: category.name,
      description: category.description,
      icon: null,
      imageUrl: null,
      type: fromActivityType(activity?.type),
      isActive: category.status === PartnerVenueServiceStatus.APPROVED,
      order: category.sort_order,
      createdAt: category.created_at,
      updatedAt: category.updated_at,
    };
  }

  async create(dto: CreateCategoryDto) {
    const slug = slugify(dto.name);
    if (await this.prisma.partner_service_categories.findUnique({ where: { slug } })) {
      throw new ConflictException(`Category '${dto.name}' already exists`);
    }

    const now = new Date();
    const category = await this.prisma.partner_service_categories.create({
      data: {
        id: randomUUID(),
        slug,
        name: dto.name,
        description: dto.description,
        sort_order: dto.order ?? 0,
        status: dto.isActive === false
          ? PartnerVenueServiceStatus.ARCHIVED
          : PartnerVenueServiceStatus.APPROVED,
        updated_at: now,
      },
    });
    const activity = await this.prisma.activities.create({
      data: {
        id: randomUUID(),
        sport_code: slug,
        name: dto.name,
        type: toActivityType(dto.type),
        status: dto.isActive === false
          ? CatalogueStatus.ARCHIVED
          : CatalogueStatus.PUBLISHED,
      },
    });
    return this.mapCategory(category, activity);
  }

  async findAll(pagination: PaginationDto, activeOnly = false) {
    const where: any = {};
    if (activeOnly) where.status = PartnerVenueServiceStatus.APPROVED;
    if (pagination.search) {
      where.name = { contains: pagination.search, mode: 'insensitive' };
    }

    const [categories, total] = await Promise.all([
      this.prisma.partner_service_categories.findMany({
        where,
        skip: pagination.skip,
        take: pagination.limit,
        orderBy: [{ sort_order: 'asc' }, { created_at: 'desc' }],
      }),
      this.prisma.partner_service_categories.count({ where }),
    ]);
    const activities = await this.prisma.activities.findMany({
      where: { sport_code: { in: categories.map((category) => category.slug) } },
    });
    const byCode = new Map(activities.map((activity) => [activity.sport_code, activity]));
    return [
      categories.map((category) => this.mapCategory(category, byCode.get(category.slug))),
      total,
    ] as const;
  }

  async findAllActive() {
    const [items] = await this.findAll(
      Object.assign(new PaginationDto(), { page: 1, limit: 500 }),
      true,
    );
    return items;
  }

  async findOne(id: string) {
    const category = await this.prisma.partner_service_categories.findUnique({ where: { id } });
    if (!category) throw new NotFoundException(`Category with id ${id} not found`);
    const activity = await this.prisma.activities.findFirst({
      where: { sport_code: category.slug },
    });
    return this.mapCategory(category, activity || undefined);
  }

  async update(id: string, dto: UpdateCategoryDto) {
    const current = await this.prisma.partner_service_categories.findUnique({ where: { id } });
    if (!current) throw new NotFoundException(`Category with id ${id} not found`);

    const name = dto.name ?? current.name;
    const slug = dto.name ? slugify(dto.name) : current.slug;
    const status = dto.isActive === undefined
      ? current.status
      : dto.isActive
        ? PartnerVenueServiceStatus.APPROVED
        : PartnerVenueServiceStatus.ARCHIVED;

    const category = await this.prisma.partner_service_categories.update({
      where: { id },
      data: {
        name,
        slug,
        description: dto.description,
        sort_order: dto.order,
        status,
        updated_at: new Date(),
      },
    });

    const existingActivity = await this.prisma.activities.findFirst({
      where: { sport_code: current.slug },
    });
    const activityStatus = status === PartnerVenueServiceStatus.APPROVED
      ? CatalogueStatus.PUBLISHED
      : CatalogueStatus.ARCHIVED;
    const activity = existingActivity
      ? await this.prisma.activities.update({
          where: { id: existingActivity.id },
          data: {
            sport_code: slug,
            name,
            type: dto.type ? toActivityType(dto.type) : undefined,
            status: activityStatus,
          },
        })
      : await this.prisma.activities.create({
          data: {
            id: randomUUID(),
            sport_code: slug,
            name,
            type: toActivityType(dto.type),
            status: activityStatus,
          },
        });
    return this.mapCategory(category, activity);
  }

  async remove(id: string): Promise<void> {
    await this.findOne(id);
    await this.prisma.partner_service_categories.delete({ where: { id } });
  }

  async toggleStatus(id: string) {
    const category = await this.findOne(id);
    return this.update(id, { isActive: !category.isActive });
  }
}
