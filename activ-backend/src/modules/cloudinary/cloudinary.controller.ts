import { Controller, Get, Query, Res } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsUrl } from 'class-validator';
import type { Response } from 'express';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { CloudinaryService } from './cloudinary.service';

class ViewPdfQueryDto {
  @IsUrl({ protocols: ['https'], require_protocol: true })
  url: string;
}

@ApiTags('Admin Documents')
@ApiBearerAuth()
@Roles(UserRole.ADMIN)
@Controller('admin/documents')
export class CloudinaryController {
  constructor(private readonly cloudinaryService: CloudinaryService) {}

  @Get('pdf')
  @ApiOperation({ summary: 'Securely stream a Cloudinary PDF for admin viewing' })
  async viewPdf(@Query() query: ViewPdfQueryDto, @Res() response: Response) {
    const pdf = await this.cloudinaryService.downloadPdf(query.url);
    response.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': 'inline; filename="document.pdf"',
      'Content-Length': String(pdf.length),
      'Cache-Control': 'private, max-age=300',
      'X-Content-Type-Options': 'nosniff',
    });
    response.send(pdf);
  }
}
