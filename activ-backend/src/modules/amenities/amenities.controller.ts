import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { PrismaService } from '../../prisma/prisma.service';

@ApiTags('Amenities')
@Controller('amenities')
export class AmenitiesController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('active')
  @Public()
  @ApiOperation({ summary: 'Get active venue amenities in display order' })
  async findActive() {
    const data = await this.prisma.partner_amenity_catalog.findMany({
      where: { active: true }, orderBy: { sort_order: 'asc' },
    });
    return { message: 'Amenities fetched successfully', data };
  }
}
