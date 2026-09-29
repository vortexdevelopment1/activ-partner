import { Injectable } from '@nestjs/common';
import PDFDocument = require('pdfkit');

interface PayoutRecord {
  bookingDate: string;
  bookingId: string;
  transactionId: string;
  activity: string;
  customerName: string;
  bookingAmount: number;
  activCommission: number;
  gstOnCommission: number;
  netBeforeRefund: number;
  refundAmount: number;
  refundReason: string;
  finalNet: number;
  status: string;
}

interface ColumnDef {
  header: string;
  width: number;
  key: keyof PayoutRecord;
  align: 'left' | 'center' | 'right';
  isNumeric?: boolean;
}

export interface FileExport {
  base64: string;
  filename: string;
  mimeType: string;
}

@Injectable()
export class PayoutsService {
  private readonly COLUMNS: ColumnDef[] = [
    { header: 'Booking Date',      width: 58, key: 'bookingDate',     align: 'center' },
    { header: 'Booking ID',        width: 50, key: 'bookingId',       align: 'center' },
    { header: 'Transaction ID',    width: 50, key: 'transactionId',   align: 'center' },
    { header: 'Activity',          width: 55, key: 'activity',        align: 'left'   },
    { header: 'Customer Name',     width: 72, key: 'customerName',    align: 'left'   },
    { header: 'Booking Amount',    width: 55, key: 'bookingAmount',   align: 'right', isNumeric: true },
    { header: 'ACTIV Commission',  width: 58, key: 'activCommission', align: 'right', isNumeric: true },
    { header: 'GST on Commission', width: 58, key: 'gstOnCommission', align: 'right', isNumeric: true },
    { header: 'Net Before Refund', width: 55, key: 'netBeforeRefund', align: 'right', isNumeric: true },
    { header: 'Refund Amount',     width: 52, key: 'refundAmount',    align: 'right', isNumeric: true },
    { header: 'Refund Reason',     width: 62, key: 'refundReason',    align: 'left'   },
    { header: 'Final Net',         width: 52, key: 'finalNet',        align: 'right', isNumeric: true },
    { header: 'Status',            width: 32, key: 'status',          align: 'center' },
  ];
  // Column widths sum = 709 → fits A4 landscape (842pt) with 20pt margins each side

  private getStaticPayoutData(): PayoutRecord[] {
    return [
      {
        bookingDate: '02-05-2026', bookingId: 'BKG-1001', transactionId: 'TXN-2001',
        activity: 'Badminton', customerName: 'Rahul Sharma',
        bookingAmount: 500, activCommission: 50, gstOnCommission: 9.0,
        netBeforeRefund: 441.0,
        refundAmount: 0, refundReason: '-', finalNet: 441.0, status: 'Success',
      },
      {
        bookingDate: '05-05-2026', bookingId: 'BKG-1002', transactionId: 'TXN-2002',
        activity: 'Football', customerName: 'Amit Patel',
        bookingAmount: 800, activCommission: 80, gstOnCommission: 14.4,
        netBeforeRefund: 705.6,
        refundAmount: 0, refundReason: '-', finalNet: 705.6, status: 'Pending',
      },
      {
        bookingDate: '08-05-2026', bookingId: 'BKG-1003', transactionId: 'TXN-2003',
        activity: 'Swimming', customerName: 'Neha Shah',
        bookingAmount: 1200, activCommission: 120, gstOnCommission: 21.6,
        netBeforeRefund: 1058.4,
        refundAmount: 300, refundReason: 'Customer Cancelled', finalNet: 758.4, status: 'Partial Refund',
      },
      {
        bookingDate: '10-05-2026', bookingId: 'BKG-1004', transactionId: 'TXN-2004',
        activity: 'Gym', customerName: 'Riya Singh',
        bookingAmount: 1000, activCommission: 100, gstOnCommission: 18.0,
        netBeforeRefund: 882.0,
        refundAmount: 1000, refundReason: 'Venue Closed', finalNet: -118.0, status: 'Refunded',
      },
      {
        bookingDate: '12-05-2026', bookingId: 'BKG-1005', transactionId: 'TXN-2005',
        activity: 'Yoga', customerName: 'Vikas Rao',
        bookingAmount: 600, activCommission: 60, gstOnCommission: 10.8,
        netBeforeRefund: 529.2,
        refundAmount: 0, refundReason: '-', finalNet: 529.2, status: 'Success',
      },
    ];
  }

  // ── CSV ──────────────────────────────────────────────────────────────────────

  private buildCsvString(): string {
    const records = this.getStaticPayoutData();
    const headers = this.COLUMNS.map((c) => `"${c.header}"`).join(',');
    const rows = records.map((r) =>
      this.COLUMNS.map((c) => `"${r[c.key]}"`).join(','),
    );
    return '﻿' + [headers, ...rows].join('\r\n'); // UTF-8 BOM for Excel
  }

  // ── PDF ──────────────────────────────────────────────────────────────────────

  private buildPdfBuffer(startDate: string, endDate: string): Promise<Buffer> {
    const records = this.getStaticPayoutData();

    const grossBookings   = records.reduce((s, r) => s + r.bookingAmount,   0);
    const totalCommission = records.reduce((s, r) => s + r.activCommission, 0);
    const totalGst        = records.reduce((s, r) => s + r.gstOnCommission, 0);
    const totalRefund     = records.reduce((s, r) => s + r.refundAmount,    0);
    const netPayable      = records.reduce((s, r) => s + r.finalNet,        0);

    const fmtAmt = (n: number) => `₹${Math.abs(n).toFixed(1)}`;

    return new Promise<Buffer>((resolve, reject) => {
      const doc = new PDFDocument({
        layout: 'landscape',
        size: 'A4',
        margins: { top: 20, bottom: 20, left: 20, right: 20 },
      });

      const chunks: Buffer[] = [];
      doc.on('data', (chunk: Buffer) => chunks.push(chunk));
      doc.on('end',  () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      const M  = 20;    // left/right margin
      const W  = 802;   // content width
      const PRIMARY   = '#3D1C6E';
      const LIGHT_BG  = '#F3EEF9';
      const BORDER    = '#C8B8E8';

      // Generated date/time
      const now = new Date();
      const dd  = String(now.getDate()).padStart(2, '0');
      const mm  = String(now.getMonth() + 1).padStart(2, '0');
      const yy  = now.getFullYear();
      const hh  = String(now.getHours()).padStart(2, '0');
      const min = String(now.getMinutes()).padStart(2, '0');
      const ampm = now.getHours() < 12 ? 'AM' : 'PM';
      const genStr = `${dd}-${mm}-${yy} (${hh}:${min} ${ampm} IST)`;

      let Y = 20;

      // ── 1. Header ────────────────────────────────────────────────────────────
      doc.fillColor(PRIMARY).rect(M, Y, W, 52).fill();

      doc.fillColor('#FFFFFF').fontSize(16).font('Helvetica-Bold')
        .text('ACTIVPULSE BOOKING PRIVATE LIMITED', M, Y + 7, { width: W, align: 'center' });

      doc.fillColor('#DAFF50').fontSize(10).font('Helvetica-Bold')
        .text('Payout Statement', M, Y + 27, { width: W, align: 'center' });

      doc.fillColor('#CCCCCC').fontSize(6.5).font('Helvetica')
        .text(`Generated On: ${genStr}`, M, Y + 42, { width: W, align: 'center' });

      Y += 56;

      // ── 2. Disclaimer ────────────────────────────────────────────────────────
      doc.fillColor('#F9F9F9').rect(M, Y, W, 28).fill();
      doc.strokeColor(BORDER).lineWidth(0.3).rect(M, Y, W, 28).stroke();

      doc.fillColor('#555555').fontSize(5.5).font('Helvetica')
        .text(
          'This statement is generated by ACTIVPULSE BOOKING PRIVATE LIMITED exclusively for the registered Venue Partner. It contains confidential financial, settlement and transaction information. Unauthorized copying, forwarding, distribution, publication, modification or disclosure of this document, in whole or in part, without prior written authorization from ACTIVPULSE BOOKING PRIVATE LIMITED is strictly prohibited and may result in contractual and legal action.',
          M + 6, Y + 7, { width: W - 12, align: 'justify', lineGap: 1 },
        );

      Y += 32;

      // ── 3. Company Details + Venue Details ───────────────────────────────────
      const BOX_W = (W - 6) / 2;
      const BOX_H = 88;
      const HDR_H = 14;

      // ── Company Details (left) ──
      doc.fillColor(PRIMARY).rect(M, Y, BOX_W, HDR_H).fill();
      doc.fillColor('#FFFFFF').fontSize(7).font('Helvetica-Bold')
        .text('Company Details', M + 6, Y + 4);

      doc.fillColor('#FFFFFF').rect(M, Y + HDR_H, BOX_W, BOX_H - HDR_H).fill();
      doc.strokeColor(BORDER).lineWidth(0.4).rect(M, Y, BOX_W, BOX_H).stroke();

      const companyRows: [string, string][] = [
        ['GSTIN',   '33ABCCA3430E1ZD'],
        ['PAN',     'ABCCA3430E'],
        ['CIN',     'U62099TN2025PTC177779'],
        ['Website', 'activ.live'],
        ['Support', 'support@activ.live'],
      ];
      companyRows.forEach(([label, value], i) => {
        const ry = Y + HDR_H + 4 + i * 13;
        doc.fillColor('#888888').fontSize(6).font('Helvetica')
          .text(label, M + 6, ry, { width: 44, lineBreak: false });
        doc.fillColor('#1F1F1F').fontSize(6).font('Helvetica-Bold')
          .text(value, M + 52, ry, { width: BOX_W - 58, lineBreak: false });
        if (i < companyRows.length - 1) {
          doc.strokeColor('#EEEEEE').lineWidth(0.2)
            .moveTo(M + 1, ry + 10).lineTo(M + BOX_W - 1, ry + 10).stroke();
        }
      });

      // ── Venue Details (right) ──
      const VX = M + BOX_W + 6;
      doc.fillColor(PRIMARY).rect(VX, Y, BOX_W, HDR_H).fill();
      doc.fillColor('#FFFFFF').fontSize(7).font('Helvetica-Bold')
        .text('Venue Details', VX + 6, Y + 4);

      doc.fillColor('#FFFFFF').rect(VX, Y + HDR_H, BOX_W, BOX_H - HDR_H).fill();
      doc.strokeColor(BORDER).lineWidth(0.4).rect(VX, Y, BOX_W, BOX_H).stroke();

      const venueRows: [string, string][] = [
        ['Venue ID',              'VEN000124'],
        ['Venue Name',            'ABC Sports Arena'],
        ['Venue Owner Name',      'Jai Kumar Singh'],
        ['Venue GSTIN',           '33AAACA3430E1ZD'],
        ['Registered Mobile',     '7878797524'],
        ['Registered Email',      'venuesports@gmail.com'],
        ['Registered Bank',       'HDFC Bank'],
        ['Bank Account (Masked)', 'XXXX7890'],
      ];
      venueRows.forEach(([label, value], i) => {
        const ry = Y + HDR_H + 3 + i * 10;
        doc.fillColor('#888888').fontSize(5.5).font('Helvetica')
          .text(label, VX + 6, ry, { width: 78, lineBreak: false });
        doc.fillColor('#1F1F1F').fontSize(5.5).font('Helvetica-Bold')
          .text(value, VX + 86, ry, { width: BOX_W - 92, lineBreak: false });
        if (i < venueRows.length - 1) {
          doc.strokeColor('#EEEEEE').lineWidth(0.2)
            .moveTo(VX + 1, ry + 8).lineTo(VX + BOX_W - 1, ry + 8).stroke();
        }
      });

      Y += BOX_H + 6;

      // ── 4. Statement Period banner ────────────────────────────────────────────
      doc.fillColor(LIGHT_BG).rect(M, Y, W, 18).fill();
      doc.strokeColor(BORDER).lineWidth(0.4).rect(M, Y, W, 18).stroke();

      doc.fillColor(PRIMARY).fontSize(8).font('Helvetica-Bold')
        .text('Venue Payout Statement Period: ', M + 8, Y + 5, { continued: true })
        .fillColor('#333333').font('Helvetica')
        .text(`${startDate}  –  ${endDate}`);

      Y += 22;

      // ── 5. Transaction table ──────────────────────────────────────────────────
      const ROW_H  = 18;
      const HDR_RH = 26; // taller to allow 2-line headers
      const PAD    = 3;
      const FS     = 6;

      // Header row
      doc.fillColor('#2D2D2D').rect(M, Y, W, HDR_RH).fill();
      let hx = M;
      this.COLUMNS.forEach((col) => {
        doc.fillColor('#FFFFFF').fontSize(FS).font('Helvetica-Bold')
          .text(col.header, hx + PAD, Y + 4, {
            width: col.width - PAD * 2,
            align: col.align,
            lineBreak: true,
            height: HDR_RH - 6,
          });
        // Column separator
        doc.strokeColor('#555555').lineWidth(0.3)
          .moveTo(hx + col.width, Y).lineTo(hx + col.width, Y + HDR_RH).stroke();
        hx += col.width;
      });

      Y += HDR_RH;

      // Data rows
      records.forEach((record, idx) => {
        const rowY = Y + idx * ROW_H;
        doc.fillColor(idx % 2 === 0 ? '#FFFFFF' : '#F7F4FC')
          .rect(M, rowY, W, ROW_H).fill();

        const statusColor =
          record.status === 'Success'        ? '#198754' :
          record.status === 'Pending'        ? '#E07C00' :
          record.status === 'Partial Refund' ? '#0D6EFD' : '#DC3545';

        let cx = M;
        this.COLUMNS.forEach((col) => {
          const raw = record[col.key];
          let display: string;
          if (col.isNumeric && typeof raw === 'number') {
            if (col.key === 'refundAmount' && raw === 0) {
              display = 'Nil';
            } else if (col.key === 'finalNet' && raw < 0) {
              display = `-₹${Math.abs(raw).toFixed(1)}`;
            } else {
              display = `₹ ${raw.toFixed(1)}`;
            }
          } else {
            display = String(raw);
          }

          doc
            .fillColor(col.key === 'status' ? statusColor : '#222222')
            .fontSize(FS)
            .font(col.key === 'status' ? 'Helvetica-Bold' : 'Helvetica')
            .text(display, cx + PAD, rowY + 6, {
              width: col.width - PAD * 2,
              align: col.align,
              lineBreak: false,
            });

          // Column separator
          doc.strokeColor('#E8E8E8').lineWidth(0.2)
            .moveTo(cx + col.width, rowY).lineTo(cx + col.width, rowY + ROW_H).stroke();

          cx += col.width;
        });

        // Row bottom border
        doc.strokeColor('#E0E0E0').lineWidth(0.2)
          .moveTo(M, rowY + ROW_H).lineTo(M + W, rowY + ROW_H).stroke();
      });

      // Table outer border
      const TABLE_H = HDR_RH + records.length * ROW_H;
      doc.strokeColor('#9AAAC8').lineWidth(0.6)
        .rect(M, Y - HDR_RH, W, TABLE_H).stroke();

      Y += records.length * ROW_H + 8;

      // ── 6. Summary (left) + Notes (right) ────────────────────────────────────
      const HALF_W  = (W - 6) / 2;
      const SECT_H  = 82;

      // ── Summary box ──
      doc.fillColor(PRIMARY).rect(M, Y, HALF_W, HDR_H).fill();
      doc.fillColor('#FFFFFF').fontSize(7).font('Helvetica-Bold')
        .text('Summary', M + 6, Y + 4);

      doc.fillColor('#FFFFFF').rect(M, Y + HDR_H, HALF_W, SECT_H - HDR_H).fill();
      doc.strokeColor(BORDER).lineWidth(0.4).rect(M, Y, HALF_W, SECT_H).stroke();

      // Net Payable highlight
      doc.fillColor(LIGHT_BG).rect(M + 1, Y + HDR_H + 1, HALF_W - 2, 18).fill();
      doc.fillColor(PRIMARY).fontSize(9).font('Helvetica-Bold')
        .text('Net Payable', M + 6, Y + HDR_H + 5);
      doc.fillColor(PRIMARY).fontSize(9).font('Helvetica-Bold')
        .text(fmtAmt(netPayable), M + 6, Y + HDR_H + 5, { width: HALF_W - 12, align: 'right' });

      const summaryRows: [string, number][] = [
        ['Gross Bookings', grossBookings],
        ['Commission',     totalCommission],
        ['GST',            totalGst],
        ['Refund',         totalRefund],
      ];
      summaryRows.forEach(([label, val], i) => {
        const sy = Y + HDR_H + 22 + i * 10;
        doc.fillColor('#555555').fontSize(6).font('Helvetica')
          .text(label, M + 6, sy);
        doc.fillColor('#1F1F1F').fontSize(6).font('Helvetica-Bold')
          .text(fmtAmt(val), M + 6, sy, { width: HALF_W - 12, align: 'right' });
        if (i < summaryRows.length - 1) {
          doc.strokeColor('#EEEEEE').lineWidth(0.2)
            .moveTo(M + 1, sy + 8).lineTo(M + HALF_W - 1, sy + 8).stroke();
        }
      });

      // ── Notes box ──
      const NX = M + HALF_W + 6;
      doc.fillColor(PRIMARY).rect(NX, Y, HALF_W, HDR_H).fill();
      doc.fillColor('#FFFFFF').fontSize(7).font('Helvetica-Bold')
        .text('Note', NX + 6, Y + 4);

      doc.fillColor('#FFFEF0').rect(NX, Y + HDR_H, HALF_W, SECT_H - HDR_H).fill();
      doc.strokeColor(BORDER).lineWidth(0.4).rect(NX, Y, HALF_W, SECT_H).stroke();

      const notes: [string, string][] = [
        [
          'GST on Commission (18%)',
          'GST is charged on ACTIV Platform services (ACTIV Commission). This amount is eligible for Input Tax Credit (ITC) in your GST returns.',
        ],
      ];
      notes.forEach(([title, desc], i) => {
        const ny = Y + HDR_H + 4 + i * 22;
        doc.fillColor(PRIMARY).fontSize(6).font('Helvetica-Bold')
          .text(title, NX + 6, ny, { width: HALF_W - 12 });
        doc.fillColor('#444444').fontSize(5.5).font('Helvetica')
          .text(desc, NX + 6, ny + 8, { width: HALF_W - 12, lineGap: 0.5 });
      });

      Y += SECT_H + 8;

      // ── 7. Footer ─────────────────────────────────────────────────────────────
      doc.fillColor('#AAAAAA').fontSize(6).font('Helvetica')
        .text('activ.live', M, Y, { width: W, align: 'center' });

      doc.end();
    });
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  async generateExport(
    format: 'pdf' | 'csv',
    partnerName: string,
    startDate: string,
    endDate: string,
  ): Promise<FileExport> {
    if (format === 'csv') {
      const csv = this.buildCsvString();
      return {
        base64: Buffer.from(csv, 'utf-8').toString('base64'),
        filename: 'activ-payout-statement.csv',
        mimeType: 'text/csv',
      };
    }

    const buffer = await this.buildPdfBuffer(startDate, endDate);
    return {
      base64: buffer.toString('base64'),
      filename: 'activ-payout-statement.pdf',
      mimeType: 'application/pdf',
    };
  }
}
