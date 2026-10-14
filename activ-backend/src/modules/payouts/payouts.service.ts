import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';
import PDFDocument = require('pdfkit');
import { PrismaService } from '../../prisma/prisma.service';
import { PayoutQueryDto } from './dto/payout-query.dto';
import { RecordPayoutDto } from './dto/record-payout.dto';

export interface FileExport {
  base64: string;
  filename: string;
  mimeType: string;
}

@Injectable()
export class PayoutsService {
  constructor(private readonly prisma: PrismaService) {}

  private where(partnerId: string, query: PayoutQueryDto) {
    const start = query.startDate ? new Date(`${query.startDate}T00:00:00+05:30`) : null;
    const end = query.endDate ? new Date(`${query.endDate}T00:00:00+05:30`) : null;
    if ((start && isNaN(start.getTime())) || (end && isNaN(end.getTime())) || (start && end && start > end)) {
      throw new BadRequestException('Select a valid date range.');
    }
    return {
      partner_id: partnerId,
      ...(query.status && query.status !== 'all' ? { status: query.status.toUpperCase() as 'SUCCESS' | 'PENDING' | 'FAILED' } : {}),
      ...(start || end ? { payout_date: {
        ...(start ? { gte: start } : {}), ...(end ? { lt: new Date(end.getTime() + 86400000) } : {}),
      } } : {}),
    };
  }

  private map(record: any) {
    const number = record.bank_account?.account_number ?? '';
    return {
      id: record.id, reference: record.reference, amount: Number(record.amount_paise) / 100,
      status: record.status.toLowerCase(), payoutDate: record.payout_date,
      failureReason: record.failure_reason, bankName: record.bank_account?.bank_name ?? null,
      accountLast4: number ? number.slice(-4) : null,
    };
  }

  async history(partnerId: string, query: PayoutQueryDto) {
    const where = this.where(partnerId, query);
    const page = query.page ?? 1, limit = query.limit ?? 20;
    const [records, total] = await Promise.all([
      this.prisma.partner_payouts.findMany({ where, include: { bank_account: true },
        orderBy: [{ payout_date: 'desc' }, { id: 'desc' }], skip: (page - 1) * limit, take: limit }),
      this.prisma.partner_payouts.count({ where }),
    ]);
    return { items: records.map((record) => this.map(record)), total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  async record(dto: RecordPayoutDto) {
    if (!await this.prisma.partners.findUnique({ where: { id: dto.partnerId }, select: { id: true } })) {
      throw new NotFoundException('Partner not found');
    }
    if (dto.bankAccountId && !await this.prisma.partner_bank_accounts.findFirst({
      where: { id: dto.bankAccountId, partner_id: dto.partnerId, status: 'APPROVED' },
    })) throw new BadRequestException('Select an approved bank account belonging to this partner.');
    const reference = dto.reference.trim();
    if (!reference) throw new BadRequestException('A payout reference is required.');
    const paise = Math.round(dto.amount * 100);
    if (!Number.isSafeInteger(paise) || paise <= 0) throw new BadRequestException('Invalid payout amount.');
    try {
      const record = await this.prisma.partner_payouts.create({ data: {
        id: randomUUID(), partner_id: dto.partnerId, bank_account_id: dto.bankAccountId,
        reference, amount_paise: BigInt(paise), status: dto.status.toUpperCase() as 'SUCCESS' | 'PENDING' | 'FAILED',
        payout_date: new Date(dto.payoutDate), updated_at: new Date(),
        failure_reason: dto.status === 'failed' ? dto.failureReason : null,
      }, include: { bank_account: true } });
      return this.map(record);
    } catch (error) {
      if (error.code === 'P2002') throw new BadRequestException('This payout reference has already been recorded.');
      throw error;
    }
  }

  async generateExport(partnerId: string, query: PayoutQueryDto): Promise<FileExport> {
    const where = this.where(partnerId, query);
    const count = await this.prisma.partner_payouts.count({ where });
    if (count > 10000) throw new BadRequestException('Select a smaller date range to export up to 10,000 payouts.');
    const records = await this.prisma.partner_payouts.findMany({ where,
      include: { bank_account: true }, orderBy: [{ payout_date: 'desc' }, { id: 'desc' }], take: 10000 });
    const rows = records.map((record) => this.map(record));
    const format = query.format ?? 'pdf';
    const headings = ['Date', 'Transaction Reference', 'Bank', 'Account Last 4', 'Amount (INR)', 'Status', 'Failure Reason'];
    const values = rows.map((row) => [new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Kolkata' }).format(row.payoutDate),
      row.reference, row.bankName ?? '', row.accountLast4 ?? '', row.amount.toFixed(2), row.status, row.failureReason ?? '']);
    let buffer: Buffer;
    if (format === 'csv') {
      const cell = (value: string) => {
        const safe = /^[=+\-@\t\r]/.test(value) ? `'${value}` : value;
        return `"${safe.replace(/"/g, '""')}"`;
      };
      buffer = Buffer.from('\uFEFF' + [headings, ...values].map((row) => row.map(cell).join(',')).join('\r\n'), 'utf8');
    } else {
      buffer = await this.pdf(query, rows, values);
    }
    return { base64: buffer.toString('base64'), filename: `activ-payouts-${query.startDate ?? 'all'}-${query.endDate ?? 'all'}.${format}`,
      mimeType: format === 'csv' ? 'text/csv' : 'application/pdf' };
  }

  private pdf(query: PayoutQueryDto, rows: ReturnType<PayoutsService['map']>[], values: string[][]): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const doc = new PDFDocument({ size: 'A4', margin: 40 });
      const chunks: Buffer[] = [];
      doc.on('data', (chunk: Buffer) => chunks.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);
      doc.font('Helvetica-Bold').fontSize(22).text('ACTIV Payout History');
      doc.moveDown().font('Helvetica').fontSize(11).text(`Period: ${query.startDate ?? 'All dates'} - ${query.endDate ?? 'All dates'}`);
      doc.text(`Status: ${query.status ?? 'all'} | Records: ${rows.length}`);
      const successful = rows.filter((row) => row.status === 'success').reduce((sum, row) => sum + row.amount, 0);
      doc.text(`Successful payouts: INR ${successful.toFixed(2)}`).moveDown();
      if (!rows.length) doc.text('No payout records found');
      for (const [i, row] of rows.entries()) {
        const lines = [values[i][0], row.reference, `INR ${row.amount.toFixed(2)} | ${row.status}`, row.bankName ?? '',
          row.accountLast4 ? `Account ending ${row.accountLast4}` : '', row.failureReason ?? ''].filter(Boolean).join('\n');
        const height = doc.heightOfString(lines, { width: 515 }) + 20;
        if (doc.y + height > doc.page.height - 40) doc.addPage();
        doc.font('Helvetica').fontSize(11).text(lines, { width: 515 }).moveDown();
      }
      doc.end();
    });
  }
}
