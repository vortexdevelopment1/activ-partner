import { Controller, Get, Optional } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { CACHE_TTL_SECONDS } from '../../common/redis/redis-cache.keys';
import { RedisCacheService } from '../../common/redis/redis-cache.service';
import { PrismaService } from '../../prisma/prisma.service';

@ApiTags('Amenities')
@Controller('amenities')
export class AmenitiesController {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly cache?: RedisCacheService,
  ) {}

  @Get('active')
  @Public()
  @ApiOperation({ summary: 'Get active venue amenities in display order' })
  async findActive() {
    const fetcher = () =>
      this.prisma.partner_amenity_catalog.findMany({
        where: { active: true },
        orderBy: { sort_order: 'asc' },
      });
    const data = this.cache
      ? await this.cache.getOrSet(
          this.cache.keys.masterAmenities(),
          CACHE_TTL_SECONDS.MASTER_AMENITIES,
          fetcher,
          ['amenities'],
        )
      : await fetcher();
    return { message: 'Amenities fetched successfully', data };
  }
}
