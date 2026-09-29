import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { CreateCityCommissionDto } from './dto/create-city-commission.dto';
import { UpdateCityCommissionDto } from './dto/update-city-commission.dto';
import { CityCommission } from './entities/city-commission.entity';

const DEFAULT_COMMISSION = 10;

@Injectable()
export class CommissionService {
  constructor(
    @InjectRepository(CityCommission)
    private readonly commissionRepository: Repository<CityCommission>,
  ) {}

  async create(dto: CreateCityCommissionDto): Promise<CityCommission> {
    const normalizedCity = dto.city.toLowerCase().trim();

    const existing = await this.commissionRepository.findOne({
      where: { city: normalizedCity },
    });
    if (existing) {
      throw new ConflictException(`Commission for city '${dto.city}' already exists`);
    }

    const commission = this.commissionRepository.create({
      ...dto,
      city: normalizedCity,
    });
    return this.commissionRepository.save(commission);
  }

  async findAll(pagination: PaginationDto): Promise<[CityCommission[], number]> {
    return this.commissionRepository.findAndCount({
      skip: pagination.skip,
      take: pagination.limit,
      order: { city: 'ASC' },
    });
  }

  async findOne(id: string): Promise<CityCommission> {
    const commission = await this.commissionRepository.findOne({ where: { id } });
    if (!commission) {
      throw new NotFoundException(`Commission with id ${id} not found`);
    }
    return commission;
  }

  async update(id: string, dto: UpdateCityCommissionDto): Promise<CityCommission> {
    const commission = await this.findOne(id);

    if (dto.city) {
      const normalizedCity = dto.city.toLowerCase().trim();
      if (normalizedCity !== commission.city) {
        const existing = await this.commissionRepository.findOne({
          where: { city: normalizedCity },
        });
        if (existing) {
          throw new ConflictException(`Commission for city '${dto.city}' already exists`);
        }
        dto.city = normalizedCity;
      } else {
        dto.city = normalizedCity;
      }
    }

    Object.assign(commission, dto);
    return this.commissionRepository.save(commission);
  }

  async remove(id: string): Promise<void> {
    const commission = await this.findOne(id);
    await this.commissionRepository.remove(commission);
  }

  async getCommissionByCity(city: string): Promise<{
    city: string;
    commissionPercentage: number;
    isDefault: boolean;
  }> {
    const normalizedCity = city.toLowerCase().trim();
    const record = await this.commissionRepository.findOne({
      where: { city: normalizedCity, isActive: true },
    });

    if (record) {
      return {
        city: record.city,
        commissionPercentage: Number(record.commissionPercentage),
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
