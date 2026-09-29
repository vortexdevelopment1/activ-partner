import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import PDFDocument = require('pdfkit');

import { LegalContent, LegalContentType } from './entities/legal-content.entity';
import { UpsertLegalContentDto } from './dto/upsert-legal-content.dto';
import { FileExport } from '../payouts/payouts.service';

const LEGAL_TITLES: Record<LegalContentType, string> = {
  [LegalContentType.TERMS_AND_CONDITIONS]: 'Terms & Conditions',
  [LegalContentType.PRIVACY_POLICY]:       'Privacy Policy',
  [LegalContentType.PARTNER_AGREEMENT]:    'Partner Agreement',
  [LegalContentType.REFUND_POLICY]:        'Refund Policy',
};

@Injectable()
export class LegalService {
  constructor(
    @InjectRepository(LegalContent)
    private readonly legalRepository: Repository<LegalContent>,
  ) {}

  async upsert(type: LegalContentType, dto: UpsertLegalContentDto, adminId: string): Promise<LegalContent> {
    const existing = await this.legalRepository.findOne({ where: { type } });

    if (existing) {
      existing.content = dto.content;
      existing.version += 1;
      existing.updatedBy = adminId;
      return this.legalRepository.save(existing);
    }

    const record = this.legalRepository.create({
      type,
      content: dto.content,
      version: 1,
      updatedBy: adminId,
    });
    return this.legalRepository.save(record);
  }

  async findByType(type: LegalContentType): Promise<LegalContent> {
    const record = await this.legalRepository.findOne({ where: { type } });
    if (!record) {
      throw new NotFoundException(`Content for '${type}' has not been set yet`);
    }
    return record;
  }

  async findAll(): Promise<LegalContent[]> {
    return this.legalRepository.find({ order: { type: 'ASC' } });
  }

  // ── PDF export ─────────────────────────────────────────────────────────────

  async generateLegalPdfExport(type: LegalContentType): Promise<FileExport> {
    const record = await this.findByType(type);
    const buffer = await this.buildLegalPdfBuffer(record);
    const slug   = type.replace(/_/g, '-');
    return {
      base64:   buffer.toString('base64'),
      filename: `activ-${slug}.pdf`,
      mimeType: 'application/pdf',
    };
  }

  private buildLegalPdfBuffer(record: LegalContent): Promise<Buffer> {
    return new Promise<Buffer>((resolve, reject) => {
      // bufferPages: true keeps every page in memory so we can go back and
      // stamp footers on all pages AFTER content is written — avoids the
      // pageAdded → doc.text() → addPage → pageAdded infinite recursion.
      const doc = new PDFDocument({
        size: 'A4',
        bufferPages: true,
        margins: { top: 50, bottom: 60, left: 55, right: 55 },
        info: {
          Title:   LEGAL_TITLES[record.type],
          Author:  'ACTIV Platform',
          Subject: LEGAL_TITLES[record.type],
        },
      });

      const chunks: Buffer[] = [];
      doc.on('data',  (chunk: Buffer) => chunks.push(chunk));
      doc.on('end',   () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      const pageWidth = 595;
      const margin    = 55;
      const usableW   = pageWidth - margin * 2;
      const title     = LEGAL_TITLES[record.type];
      const updatedAt = record.updatedAt
        ? new Date(record.updatedAt).toLocaleDateString('en-IN', { day: '2-digit', month: 'long', year: 'numeric' })
        : new Date().toLocaleDateString('en-IN', { day: '2-digit', month: 'long', year: 'numeric' });

      // ── Brand header bar (page 1 only) ───────────────────────
      doc.fillColor('#1e3a5f').rect(0, 0, pageWidth, 60).fill();
      doc.fillColor('#f97316').rect(0, 0, 6, 60).fill();

      doc.fillColor('#ffffff').fontSize(22).font('Helvetica-Bold')
        .text('ACTIV', margin, 15, { continued: true })
        .fillColor('#f97316')
        .text(' Platform');

      doc.fillColor('#aaaaaa').fontSize(8).font('Helvetica')
        .text('Legal Document', margin, 42);

      // ── Document title ────────────────────────────────────────
      doc.fillColor('#1e3a5f').fontSize(20).font('Helvetica-Bold')
        .text(title, margin, 82, { width: usableW });

      doc.fillColor('#666666').fontSize(8.5).font('Helvetica')
        .text(`Version ${record.version}   ·   Last updated: ${updatedAt}`, margin, doc.y + 6, { width: usableW });

      doc.strokeColor('#e0e6f0').lineWidth(1)
        .moveTo(margin, doc.y + 10)
        .lineTo(margin + usableW, doc.y + 10)
        .stroke();

      doc.moveDown(1.4);

      // ── Body content ──────────────────────────────────────────
      const paragraphs = record.content
        .split(/\n{2,}/)
        .map((p) => p.trim())
        .filter(Boolean);

      doc.fontSize(9.5).font('Helvetica').fillColor('#333333');

      paragraphs.forEach((para) => {
        const isHeading = para.length < 80 && para === para.toUpperCase() && !para.endsWith('.');
        if (isHeading) {
          doc.moveDown(0.5)
            .fontSize(10.5).font('Helvetica-Bold').fillColor('#1e3a5f')
            .text(para, { width: usableW })
            .fontSize(9.5).font('Helvetica').fillColor('#333333');
        } else {
          doc.text(para, { width: usableW, align: 'justify' });
        }
        doc.moveDown(0.6);
      });

      // ── Stamp footers on every buffered page ──────────────────
      // Must be done BEFORE flushPages() / end().
      const range      = doc.bufferedPageRange();
      const totalPages = range.count;

      for (let i = 0; i < totalPages; i++) {
        doc.switchToPage(range.start + i);

        const footerY = doc.page.height - 40;

        doc.strokeColor('#e0e6f0').lineWidth(0.5)
          .moveTo(margin, footerY - 6)
          .lineTo(margin + usableW, footerY - 6)
          .stroke();

        doc.fillColor('#aaaaaa').fontSize(7).font('Helvetica')
          .text(
            '© ACTIV Platform. All rights reserved.',
            margin, footerY,
            { width: usableW - 60, lineBreak: false },
          );

        doc.fillColor('#aaaaaa').fontSize(7).font('Helvetica')
          .text(
            `Page ${i + 1} of ${totalPages}`,
            margin, footerY,
            { width: usableW, align: 'right', lineBreak: false },
          );
      }

      doc.flushPages();
      doc.end();
    });
  }
}
