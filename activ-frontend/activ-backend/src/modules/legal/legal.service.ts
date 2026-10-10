import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'crypto';
import PDFDocument = require('pdfkit');
import { PrismaService } from '../../prisma/prisma.service';
import type { content_documents } from '../../generated/prisma/client';

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
    private readonly prisma: PrismaService,
  ) {}

  private validateType(type: LegalContentType) {
    if (!Object.values(LegalContentType).includes(type)) {
      throw new BadRequestException('Invalid legal content type');
    }
  }

  private toLegalContent(record: content_documents, updatedBy?: string): LegalContent & { title: string } {
    return Object.assign(new LegalContent(), {
      id: record.id, type: record.type as LegalContentType,
      title: record.title, content: record.body,
      version: Number(record.version) || 1,
      createdAt: record.created_at, updatedAt: record.updated_at,
      updatedBy: updatedBy ?? null,
    });
  }

  async upsert(type: LegalContentType, dto: UpsertLegalContentDto, adminId: string): Promise<LegalContent> {
    this.validateType(type);
    // Keep published history and retry conflicting saves so version numbers stay unique.
    for (let attempt = 0; ; attempt++) {
      try {
        return await this.prisma.$transaction(async (tx) => {
          const existing = await tx.content_documents.findMany({ where: { type } });
          const version = Math.floor(existing.reduce((highest, record) =>
            Math.max(highest, Number(record.version) || 0), 0)) + 1;
          const now = new Date();
          const record = await tx.content_documents.create({
            data: {
              id: randomUUID(), type, version: String(version),
              title: LEGAL_TITLES[type], body: dto.content,
              status: 'PUBLISHED', published_at: now, updated_at: now,
            },
          });
          await tx.audit_events.create({
            data: {
              id: randomUUID(), actor_id: adminId,
              action: 'legal_content.published', entity_type: 'content_documents',
              entity_id: record.id, after_json: { type, version },
            },
          });
          return this.toLegalContent(record, adminId);
        }, { isolationLevel: 'Serializable' });
      } catch (error) {
        if (attempt >= 2 || !['P2034', 'P2002'].includes(error?.code)) throw error;
      }
    }
  }

  async findByType(type: LegalContentType): Promise<LegalContent> {
    this.validateType(type);
    const record = await this.prisma.content_documents.findFirst({
      where: { type, status: 'PUBLISHED' },
      orderBy: [{ published_at: { sort: 'desc', nulls: 'last' } }, { updated_at: 'desc' }, { created_at: 'desc' }],
    });
    if (!record) {
      throw new NotFoundException(`Content for '${type}' has not been set yet`);
    }
    return this.toLegalContent(record);
  }

  async findAll(): Promise<LegalContent[]> {
    const records = await this.prisma.content_documents.findMany({
      where: { type: { in: Object.values(LegalContentType) }, status: 'PUBLISHED' },
      orderBy: [{ type: 'asc' }, { published_at: { sort: 'desc', nulls: 'last' } }, { updated_at: 'desc' }, { created_at: 'desc' }],
    });
    const latest = new Map<string, LegalContent>();
    for (const record of records) {
      if (!latest.has(record.type)) latest.set(record.type, this.toLegalContent(record));
    }
    return [...latest.values()];
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
