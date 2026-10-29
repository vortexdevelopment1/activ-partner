import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { MailService } from './mail.service';
import { EmailData, EmailTemplateId } from './templates/partner-email';

/** Resolve only the owning partner's registered address, never a staff/customer address. */
@Injectable()
export class PartnerEmailService {
  private readonly logger = new Logger(PartnerEmailService.name);
  constructor(private readonly prisma: PrismaService, private readonly mail: MailService) {}

  async send(partnerId: string, template: EmailTemplateId, data: EmailData = {}): Promise<boolean> {
    try {
      const owner = await this.prisma.partner_users.findFirst({
        where: { partner_id: partnerId, role: 'PARTNER_ADMIN' },
        select: { users: { select: { email: true, name: true } } },
      });
      const profile = !owner?.users?.email
        ? await this.prisma.partner_business_profiles.findUnique({ where: { partner_id: partnerId }, select: { email: true, owner_name: true } })
        : null;
      return await this.mail.sendTemplateEmail(owner?.users?.email || profile?.email, template,
        { ...data, partnerName: data.partnerName || owner?.users?.name || profile?.owner_name || 'Partner' });
    } catch {
      this.logger.warn(`Partner notice could not be delivered (${template})`);
      return false;
    }
  }
}
