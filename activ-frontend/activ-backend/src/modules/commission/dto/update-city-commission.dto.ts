import { PartialType } from '@nestjs/swagger';
import { CreateCityCommissionDto } from './create-city-commission.dto';

export class UpdateCityCommissionDto extends PartialType(CreateCityCommissionDto) {}
