import { Controller, Get, Param } from '@nestjs/common';
import { ApiOperation, ApiParam, ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { LocationService } from './location.service';

@ApiTags('Location')
@Controller('location')
export class LocationController {
  constructor(private readonly locationService: LocationService) {}

  @Get('pincode/:code')
  @Public()
  @ApiOperation({
    summary: 'Get city and state from pincode (Public)',
    description: 'Lookup city (district) and state for any valid 6-digit Indian pincode.',
  })
  @ApiParam({ name: 'code', example: '400708', description: '6-digit Indian pincode' })
  async lookupPincode(@Param('code') code: string) {
    const data = await this.locationService.lookupPincode(code);
    return { message: 'Pincode details fetched successfully', data };
  }
}
