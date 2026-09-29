import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CommissionController } from './commission.controller';
import { CommissionService } from './commission.service';
import { CityCommission } from './entities/city-commission.entity';

@Module({
  imports: [TypeOrmModule.forFeature([CityCommission])],
  controllers: [CommissionController],
  providers: [CommissionService],
  exports: [CommissionService],
})
export class CommissionModule {}
