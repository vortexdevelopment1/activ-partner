import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateCityCommissionDto } from './dto/create-city-commission.dto';
import { UpdateCityCommissionDto } from './dto/update-city-commission.dto';
import { CityCommission } from './entities/city-commission.entity';

const DEFAULT_COMMISSION = 10;

@Injectable()
export class CommissionService {
  constructor(private readonly prisma: PrismaService) {}

  private mapCommission(record: {
    id: string;
    city_code: string;
    commission_bps: number;
    effective_to: Date | null;
    created_at: Date;
    updated_at: Date;
  }): CityCommission {
    return {
      id: record.id,
      city: record.city_code,
      commissionPercentage: record.commission_bps / 100,
      isActive: record.effective_to === null || record.effective_to >= new Date(),
      createdAt: record.created_at,
      updatedAt: record.updated_at,
    };
  }

  async create(dto: CreateCityCommissionDto): Promise<CityCommission> {
    const normalizedCity = dto.city.toLowerCase().trim();

    const existing = await this.prisma.partner_city_commissions.findFirst({
      where: {
        partner_id: null,
        city_code: { equals: normalizedCity, mode: 'insensitive' },
        effective_to: null,
      },
    });
    if (existing) {
      throw new ConflictException(`Commission for city '${dto.city}' already exists`);
    }

    const now = new Date();
    const commission = await this.prisma.partner_city_commissions.create({
      data: {
        id: randomUUID(),
        partner_id: null,
        city_code: normalizedCity,
        commission_bps: Math.round(dto.commissionPercentage * 100),
        effective_from: now,
        updated_at: now,
      },
    });
    return this.mapCommission(commission);
  }

  async findAll(pagination: PaginationDto): Promise<[CityCommission[], number]> {
    const [items, total] = await Promise.all([
      this.prisma.partner_city_commissions.findMany({
        where: { partner_id: null },
        skip: pagination.skip,
        take: pagination.limit,
        orderBy: { city_code: 'asc' },
      }),
      this.prisma.partner_city_commissions.count({ where: { partner_id: null } }),
    ]);
    return [items.map((item) => this.mapCommission(item)), total];
  }

  async findOne(id: string): Promise<CityCommission> {
    const commission = await this.prisma.partner_city_commissions.findUnique({ where: { id } });
    if (!commission) {
      throw new NotFoundException(`Commission with id ${id} not found`);
    }
    return this.mapCommission(commission);
  }

  async update(id: string, dto: UpdateCityCommissionDto): Promise<CityCommission> {
    const commission = await this.findOne(id);

    if (dto.city) {
      const normalizedCity = dto.city.toLowerCase().trim();
      if (normalizedCity !== commission.city) {
        const existing = await this.prisma.partner_city_commissions.findFirst({
          where: {
            id: { not: id },
            partner_id: null,
            city_code: { equals: normalizedCity, mode: 'insensitive' },
            effective_to: null,
          },
        });
        if (existing) {
          throw new ConflictException(`Commission for city '${dto.city}' already exists`);
        }
        dto.city = normalizedCity;
      } else {
        dto.city = normalizedCity;
      }
    }

    const updated = await this.prisma.partner_city_commissions.update({
      where: { id },
      data: {
        ...(dto.city !== undefined && { city_code: dto.city }),
        ...(dto.commissionPercentage !== undefined && {
          commission_bps: Math.round(dto.commissionPercentage * 100),
        }),
        updated_at: new Date(),
      },
    });
    return this.mapCommission(updated);
  }

  async remove(id: string): Promise<void> {
    await this.findOne(id);
    await this.prisma.partner_city_commissions.delete({ where: { id } });
  }

  async getCommissionByCity(city: string): Promise<{
    city: string;
    commissionPercentage: number;
    isDefault: boolean;
  }> {
    const normalizedCity = city.toLowerCase().trim();
    const now = new Date();
    const record = await this.prisma.partner_city_commissions.findFirst({
      where: {
        partner_id: null,
        city_code: { equals: normalizedCity, mode: 'insensitive' },
        effective_from: { lte: now },
        OR: [{ effective_to: null }, { effective_to: { gte: now } }],
      },
      orderBy: { effective_from: 'desc' },
    });

    if (record) {
      return {
        city: record.city_code,
        commissionPercentage: record.commission_bps / 100,
        isDefault: false,
      };
    }

    return {
      city: normalizedCity,
      commissionPercentage: DEFAULT_COMMISSION,
      isDefault: true,
    };
  }
}
