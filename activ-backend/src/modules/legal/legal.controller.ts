import { Body, Controller, Get, Param, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiParam, ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { LegalContentType } from './entities/legal-content.entity';
import { LegalService } from './legal.service';
import { UpsertLegalContentDto } from './dto/upsert-legal-content.dto';

@ApiTags('Legal')
@Controller('legal')
export class LegalController {
  constructor(private readonly legalService: LegalService) {}

  @Put(':type')
  @ApiBearerAuth()
  @Roles(UserRole.ADMIN)
  @ApiOperation({ summary: 'Create or update Terms & Conditions / Privacy Policy (Admin only)' })
  @ApiParam({ name: 'type', enum: LegalContentType, example: LegalContentType.TERMS_AND_CONDITIONS })
  async upsert(
    @Param('type') type: LegalContentType,
    @Body() dto: UpsertLegalContentDto,
    @CurrentUser() user: any,
  ) {
    const data = await this.legalService.upsert(type, dto, user.id);
    return { message: 'Legal content saved successfully', data };
  }

  @Get()
  @Public()
  @ApiOperation({ summary: 'Get all legal content (Public)' })
  async findAll() {
    const data = await this.legalService.findAll();
    return { message: 'Legal content fetched successfully', data };
  }

  /**
   * Must be declared BEFORE `:type` so NestJS matches the literal "download"
   * segment and doesn't treat it as a type parameter.
   * Route: GET /legal/:type/download
   */
  @Get(':type/download')
  @Public()
  @ApiOperation({
    summary: 'Download legal document as PDF (base64)',
    description:
      'Returns the legal document as a base64-encoded PDF. ' +
      'Mobile apps should decode the base64 and open with the device PDF viewer. ' +
      'No authentication required — legal documents are public.',
  })
  @ApiParam({ name: 'type', enum: LegalContentType, example: LegalContentType.PRIVACY_POLICY })
  async downloadLegal(@Param('type') type: LegalContentType) {
    const data = await this.legalService.generateLegalPdfExport(type);
    return { message: 'Legal document generated successfully', data };
  }

  @Get(':type')
  @Public()
  @ApiOperation({ summary: 'Get Terms & Conditions or Privacy Policy by type (Public)' })
  @ApiParam({ name: 'type', enum: LegalContentType, example: LegalContentType.PRIVACY_POLICY })
  async findOne(@Param('type') type: LegalContentType) {
    const data = await this.legalService.findByType(type);
    return { message: 'Legal content fetched successfully', data };
  }
}
