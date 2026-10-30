import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { randomUUID } from "crypto";
import { City, State } from "country-state-city";
import { PaginationDto } from "../../common/dto/pagination.dto";
import { PrismaService } from "../../prisma/prisma.service";
import { CreateCityCommissionDto } from "./dto/create-city-commission.dto";
import { UpdateCityCommissionDto } from "./dto/update-city-commission.dto";
import type { CityCommissionRecord as CityCommission } from '../../common/domain-types';

export const DEFAULT_COMMISSION = 5;

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
      NOT: { city_code: "", state_code: null },
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

  async findAllIndianCities(
    pagination: PaginationDto,
    stateFilter?: string,
  ): Promise<[Array<{
    city: string;
    state: string;
    commissionPercentage: number;
    source: "city" | "state" | "default";
    overrideId: string | null;
  }>, number]> {
    const states = State.getStatesOfCountry("IN");
    const stateNames = new Map(states.map((state) => [state.isoCode, state.name]));
    const search = this.normalize(pagination.search);
    const stateSearch = this.normalize(stateFilter);
    const seen = new Set<string>();
    const cities = (City.getCitiesOfCountry("IN") ?? [])
      .map((city) => ({
        city: city.name,
        state: stateNames.get(city.stateCode) ?? city.stateCode,
      }))
      .filter((location) => {
        const key = `${this.normalize(location.city)}|${this.normalize(location.state)}`;
        if (seen.has(key)) return false;
        seen.add(key);
        if (stateSearch && !this.normalize(location.state).includes(stateSearch)) return false;
        return !search || this.normalize(`${location.city} ${location.state}`).includes(search);
      })
      .sort((a, b) =>
        a.state.localeCompare(b.state) || a.city.localeCompare(b.city),
      );

    const now = new Date();
    const rules = await this.prisma.partner_city_commissions.findMany({
      where: {
        partner_id: null,
        effective_from: { lte: now },
        OR: [{ effective_to: null }, { effective_to: { gte: now } }],
      },
      orderBy: { effective_from: "desc" },
    });
    const exactRules = new Map<string, (typeof rules)[number]>();
    const cityOnlyRules = new Map<string, (typeof rules)[number]>();
    const stateRules = new Map<string, (typeof rules)[number]>();
    let defaultRule: (typeof rules)[number] | undefined;

    for (const rule of rules) {
      const city = this.normalize(rule.city_code);
      const state = this.normalize(rule.state_code);
      if (city && state && !exactRules.has(`${city}|${state}`)) {
        exactRules.set(`${city}|${state}`, rule);
      } else if (city && !state && !cityOnlyRules.has(city)) {
        cityOnlyRules.set(city, rule);
      } else if (!city && state && !stateRules.has(state)) {
        stateRules.set(state, rule);
      } else if (!city && !state && !defaultRule) {
        defaultRule = rule;
      }
    }

    const items = cities.slice(pagination.skip, pagination.skip + (pagination.limit || 20)).map((location) => {
      const city = this.normalize(location.city);
      const state = this.normalize(location.state);
      const exact = exactRules.get(`${city}|${state}`) ?? cityOnlyRules.get(city);
      const stateRule = stateRules.get(state);
      const rule = exact ?? stateRule ?? defaultRule;
      return {
        ...location,
        commissionPercentage: rule ? rule.commission_bps / 100 : DEFAULT_COMMISSION,
        source: exact ? "city" as const : stateRule ? "state" as const : "default" as const,
        overrideId: exact?.id ?? null,
      };
    });

    return [items, cities.length];
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

  async getDefaultCommission(): Promise<{
    commissionPercentage: number;
    isPersisted: boolean;
  }> {
    const record = await this.findActiveDefault();
    return {
      commissionPercentage: record
        ? record.commission_bps / 100
        : DEFAULT_COMMISSION,
      isPersisted: Boolean(record),
    };
  }

  async updateDefaultCommission(commissionPercentage: number): Promise<{
    commissionPercentage: number;
    isPersisted: boolean;
  }> {
    const existing = await this.findActiveDefault();
    const now = new Date();
    const data = {
      commission_bps: Math.round(commissionPercentage * 100),
      updated_at: now,
    };

    if (existing) {
      await this.prisma.partner_city_commissions.update({
        where: { id: existing.id },
        data,
      });
    } else {
      await this.prisma.partner_city_commissions.create({
        data: {
          id: randomUUID(),
          partner_id: null,
          city_code: "",
          state_code: null,
          effective_from: now,
          ...data,
        },
      });
    }

    return { commissionPercentage, isPersisted: true };
  }

  private findActiveDefault() {
    const now = new Date();
    return this.prisma.partner_city_commissions.findFirst({
      where: {
        partner_id: null,
        city_code: "",
        state_code: null,
        effective_from: { lte: now },
        OR: [{ effective_to: null }, { effective_to: { gte: now } }],
      },
      orderBy: { effective_from: "desc" },
    });
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

    const defaultRule = await this.findActiveDefault();
    if (defaultRule) {
      return {
        city: normalizedCity,
        state: normalizedState,
        commissionPercentage: defaultRule.commission_bps / 100,
        isDefault: true,
      };
    }

    return {
      city: normalizedCity,
      state: normalizedState,
      commissionPercentage: DEFAULT_COMMISSION,
      isDefault: true,
    };
  }
}
