import { BadRequestException } from '@nestjs/common';
import { PDFFont, PDFPage, rgb } from 'pdf-lib';

// Measured from the border paths in partner-agreement-template.pdf, page 3.
// PDF coordinates use a bottom-left origin. Keep all painting inside the cells.
export const agreementValueColumn = { left: 207.6915, right: 565.7082 };
export const agreementRowEdges = [
  622.9234, 584.6589, 546.3945, 508.1301,
  469.8657, 431.6013, 377.1347, 338.8703,
] as const;

function wrapText(value: string, font: PDFFont, size: number, width: number): string[] {
  const lines: string[] = [];
  for (const paragraph of value.replace(/\r\n?/g, '\n').split('\n')) {
    let line = '';
    for (const word of paragraph.split(/\s+/).filter(Boolean)) {
      if (line && font.widthOfTextAtSize(`${line} ${word}`, size) > width) {
        lines.push(line);
        line = '';
      }
      // Email addresses and other long tokens must wrap too.
      for (const character of word) {
        const candidate = line + character;
        if (font.widthOfTextAtSize(candidate, size) > width && line) {
          lines.push(line);
          line = character;
        } else {
          line = candidate;
        }
      }
      line += ' ';
    }
    lines.push(line.trimEnd());
  }
  return lines;
}

export function fillAgreementAcceptance(page: PDFPage, font: PDFFont, values: string[]): void {
  if (values.length !== agreementRowEdges.length - 1) throw new Error('Invalid agreement row count');
  const inset = 2;
  const padding = 8;
  const width = agreementValueColumn.right - agreementValueColumn.left;
  values.forEach((value, index) => {
    const top = agreementRowEdges[index];
    const bottom = agreementRowEdges[index + 1];
    let size = 11;
    let lines: string[];
    let height: number;
    while (true) {
      lines = wrapText(value, font, size, width - 2 * padding);
      height = font.heightAtSize(size) + (lines.length - 1) * size * 1.25;
      if (height <= top - bottom - 2 * padding) break;
      size -= 0.5;
      if (size < 7) throw new BadRequestException('Agreement details are too long to fit. Please shorten the name or signature.');
    }
    page.drawRectangle({
      x: agreementValueColumn.left + inset, y: bottom + inset,
      width: width - 2 * inset, height: top - bottom - 2 * inset,
      color: rgb(1, 1, 1),
    });
    const baseline = top - (top - bottom - height) / 2 - font.heightAtSize(size, { descender: false });
    lines.forEach((line, lineIndex) => page.drawText(line, {
      x: agreementValueColumn.left + padding,
      y: baseline - lineIndex * size * 1.25,
      size, font, color: rgb(0.12, 0.12, 0.12),
    }));
  });
}
