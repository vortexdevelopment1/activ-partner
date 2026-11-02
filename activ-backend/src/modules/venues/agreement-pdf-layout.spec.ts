import { PDFDocument, StandardFonts } from 'pdf-lib';
import { agreementRowEdges, agreementValueColumn, fillAgreementAcceptance } from './agreement-pdf-layout';

describe('agreement acceptance PDF layout', () => {
  async function fixture(values: string[]) {
    const document = await PDFDocument.create();
    const page = document.addPage([595.5, 842.25]);
    const font = await document.embedFont(StandardFonts.Helvetica);
    const rectangles = jest.spyOn(page, 'drawRectangle');
    const texts = jest.spyOn(page, 'drawText');
    fillAgreementAcceptance(page, font, values);
    return { page, font, rectangles, texts };
  }

  it('keeps every white fill strictly inside its cell and away from the right border', async () => {
    const { page, rectangles } = await fixture(Array(7).fill('Sample value'));
    expect(rectangles).toHaveBeenCalledTimes(7);
    rectangles.mock.calls.forEach(([rectangle], index) => {
      expect(rectangle.x).toBeGreaterThan(agreementValueColumn.left);
      expect(rectangle.x + rectangle.width).toBeLessThan(agreementValueColumn.right);
      expect(rectangle.x + rectangle.width).toBeLessThan(page.getWidth());
      expect(rectangle.y).toBeGreaterThan(agreementRowEdges[index + 1]);
      expect(rectangle.y + rectangle.height).toBeLessThan(agreementRowEdges[index]);
    });
  });

  it('renders the complete acceptance method inside its actual value column', async () => {
    const value = 'Electronic Acceptance via ACTIV Venue Partner App';
    const { texts, font } = await fixture(['', '', '', '', '', value, '']);
    const calls = texts.mock.calls.filter(([text]) => text.length > 0);
    expect(calls.map(([text]) => text).join(' ')).toBe(value);
    for (const [text, options] of calls) {
      expect(options.x).toBeGreaterThan(agreementValueColumn.left);
      expect(options.x + font.widthOfTextAtSize(text, options.size)).toBeLessThan(agreementValueColumn.right);
      expect(options.y).toBeGreaterThan(agreementRowEdges[6]);
      expect(options.y + font.heightAtSize(options.size)).toBeLessThan(agreementRowEdges[5]);
    }
  });

  it('wraps long venue names and unbroken email addresses without losing text', async () => {
    const values = ['', 'A long community sports venue with indoor courts and fitness studios and coaching facilities',
      'sample.partner.with.a.very.long.registered.email.address.for.layout.review@example.com', '', '', '', ''];
    const { texts, font } = await fixture(values);
    for (const index of [1, 2]) {
      const calls = texts.mock.calls.filter(([text, options]) => text &&
        options.y > agreementRowEdges[index + 1] && options.y < agreementRowEdges[index]);
      expect(calls.length).toBeGreaterThan(1);
      expect(calls.map(([text]) => text).join('').replace(/\s/g, '')).toBe(values[index].replace(/\s/g, ''));
      for (const [text, options] of calls) {
        expect(options.x + font.widthOfTextAtSize(text, options.size)).toBeLessThan(agreementValueColumn.right);
        expect(options.y).toBeGreaterThan(agreementRowEdges[index + 1]);
      }
    }
  });
});
