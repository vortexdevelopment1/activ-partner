import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { randomUUID } from "crypto";
import { PaginationDto } from "../../common/dto/pagination.dto";
import { PrismaService } from "../../prisma/prisma.service";
import { CreateCityCommissionDto } from "./dto/create-city-commission.dto";
import { UpdateCityCommissionDto } from "./dto/update-city-commission.dto";
import { CityCommission } from "./entities/city-commission.entity";

const DEFAULT_COMMISSION = 10;

@Injectable()
export class CommissionService {
  constructor(private readonly prisma: PrismaService) {}

  private mapCommission(record: {
    id: string;
    city_code: string;
    state_code: string | null;
    commission_bps: number;
    effective_to: Date | null;
    created_at: Date;
    updated_at: Date;
  }): CityCommission {
    return {
      id: record.id,
      city: record.city_code,
      state: record.state_code,
      commissionPercentage: record.commission_bps / 100,
      isActive:
        record.effective_to === null || record.effective_to >= new Date(),
      createdAt: record.created_at,
      updatedAt: record.updated_at,
    };
  }

  async create(dto: CreateCityCommissionDto): Promise<CityCommission> {
    const normalizedCity = this.normalize(dto.city);
    const normalizedState = this.normalize(dto.state) || null;
    this.validateLocation(normalizedCity, normalizedState);

    const existing = await this.prisma.partner_city_commissions.findFirst({
      where: {
        partner_id: null,
        city_code: { equals: normalizedCity, mode: "insensitive" },
        state_code: normalizedState,
        effective_to: null,
      },
    });
    if (existing) {
      throw new ConflictException(
        `Commission for city '${dto.city}' already exists`,
      );
    }

    const now = new Date();
    const commission = await this.prisma.partner_city_commissions.create({
      data: {
        id: randomUUID(),
        partner_id: null,
        city_code: normalizedCity,
        state_code: normalizedState,
        commission_bps: Math.round(dto.commissionPercentage * 100),
        effective_from: now,
        updated_at: now,
      },
    });
    return this.mapCommission(commission);
  }

  async findAll(
    pagination: PaginationDto,
  ): Promise<[CityCommission[], number]> {
    const where = {
      partner_id: null,
      ...(pagination.search ? { OR: [
        { city_code: { contains: pagination.search, mode: 'insensitive' as const } },
        { state_code: { contains: pagination.search, mode: 'insensitive' as const } },
      ] } : {}),
    };
    const [items, total] = await Promise.all([
      this.prisma.partner_city_commissions.findMany({
        where,
        skip: pagination.skip,
        take: pagination.limit,
        orderBy: { city_code: "asc" },
      }),
      this.prisma.partner_city_commissions.count({
        where,
      }),
    ]);
    return [items.map((item) => this.mapCommission(item)), total];
  }

  async findOne(id: string): Promise<CityCommission> {
    const commission = await this.prisma.partner_city_commissions.findUnique({
      where: { id },
    });
    if (!commission) {
      throw new NotFoundException(`Commission with id ${id} not found`);
    }
    return this.mapCommission(commission);
  }

  async update(
    id: string,
    dto: UpdateCityCommissionDto,
  ): Promise<CityCommission> {
    const commission = await this.findOne(id);
    const normalizedCity =
      dto.city === undefined ? commission.city : this.normalize(dto.city);
    const normalizedState =
      dto.state === undefined
        ? commission.state
        : this.normalize(dto.state) || null;
    this.validateLocation(normalizedCity, normalizedState);
    if (
      normalizedCity !== commission.city ||
      normalizedState !== commission.state
    ) {
      const existing = await this.prisma.partner_city_commissions.findFirst({
        where: {
          id: { not: id },
          partner_id: null,
          city_code: { equals: normalizedCity, mode: "insensitive" },
          state_code: normalizedState,
          effective_to: null,
        },
      });
      if (existing) {
        throw new ConflictException(
          `Commission for city '${dto.city}' already exists`,
        );
      }
    }

    const updated = await this.prisma.partner_city_commissions.update({
      where: { id },
      data: {
        city_code: normalizedCity,
        state_code: normalizedState,
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

  private normalize(value?: string | null): string {
    return (value ?? "").trim().toLowerCase().replace(/\s+/g, " ");
  }

  private validateLocation(city: string, state: string | null): void {
    if (!city && !state)
      throw new BadRequestException("A city or state is required");
  }

  async getCommissionByCity(
    city: string,
    state?: string,
  ): Promise<{
    city: string;
    state: string | null;
    commissionPercentage: number;
    isDefault: boolean;
  }> {
    const normalizedCity = this.normalize(city);
    const normalizedState = this.normalize(state) || null;
    const now = new Date();
    const locations = [
      ...(normalizedState
        ? [{ city_code: normalizedCity, state_code: normalizedState }]
        : []),
      { city_code: normalizedCity, state_code: null },
      ...(normalizedState
        ? [{ city_code: "", state_code: normalizedState }]
        : []),
    ];
    // Prefer the most specific matching rule, then the existing city-only rule.
    for (const location of locations) {
      const record = await this.prisma.partner_city_commissions.findFirst({
        where: {
          partner_id: null,
          city_code: { equals: location.city_code, mode: "insensitive" },
          state_code:
            location.state_code === null
              ? null
              : { equals: location.state_code, mode: "insensitive" },
          effective_from: { lte: now },
          OR: [{ effective_to: null }, { effective_to: { gte: now } }],
        },
        orderBy: { effective_from: "desc" },
      });

      if (record) {
        return {
          city: record.city_code,
          state: record.state_code,
          commissionPercentage: record.commission_bps / 100,
          isDefault: false,
        };
      }
    }

    return {
      city: normalizedCity,
      state: normalizedState,
      commissionPercentage: DEFAULT_COMMISSION,
      isDefault: true,
    };
  }
}
