import { BadRequestException, NotFoundException } from '@nestjs/common';
import { PartnersController } from './partners.controller';
import { PartnerDocumentKind, PARTNER_DOCUMENT_MAX_BYTES, validatePartnerDocument } from './partner-document-upload';

const pdf = { originalname: 'pan.pdf', mimetype: 'application/pdf', buffer: Buffer.from('%PDF-1.7\n') } as Express.Multer.File;
const png = { originalname: 'photo.png', mimetype: 'image/png', buffer: Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]) } as Express.Multer.File;

describe('admin partner document upload', () => {
  it('allows supported documents and image avatars', () => {
    expect(() => validatePartnerDocument(pdf, PartnerDocumentKind.PAN)).not.toThrow();
    expect(() => validatePartnerDocument(pdf, PartnerDocumentKind.GST)).not.toThrow();
    expect(() => validatePartnerDocument(pdf, PartnerDocumentKind.CANCELLED_CHEQUE)).not.toThrow();
    expect(() => validatePartnerDocument(pdf, PartnerDocumentKind.AADHAAR)).not.toThrow();
    expect(() => validatePartnerDocument(png, PartnerDocumentKind.AVATAR)).not.toThrow();
  });

  it('rejects missing, oversized, mismatched and non-image avatar files', () => {
    for (const file of [undefined, { ...pdf, buffer: Buffer.alloc(0) }, { ...pdf, buffer: Buffer.alloc(PARTNER_DOCUMENT_MAX_BYTES + 1) }, { ...pdf, buffer: Buffer.from('<html>') }, { ...pdf, originalname: 'document.html' }]) {
      expect(() => validatePartnerDocument(file as any, PartnerDocumentKind.PAN)).toThrow(BadRequestException);
    }
    expect(() => validatePartnerDocument(pdf, PartnerDocumentKind.AVATAR)).toThrow(BadRequestException);
  });

  it('checks partner existence before uploading and returns a staged URL', async () => {
    const partners = { findOne: jest.fn().mockResolvedValue({ id: 'partner' }) };
    const cloudinary = { uploadFile: jest.fn().mockResolvedValue('https://example.com/pan.pdf') };
    const controller = new PartnersController(partners as any, cloudinary as any);
    await expect(controller.uploadDocument('partner', PartnerDocumentKind.PAN, pdf)).resolves.toEqual({ message: expect.any(String), data: { url: 'https://example.com/pan.pdf' } });
    expect(partners.findOne).toHaveBeenCalledWith('partner');
    expect(cloudinary.uploadFile).toHaveBeenCalledWith(pdf, 'activ/partners/partner/pan', 'auto');
    cloudinary.uploadFile.mockClear();
    partners.findOne.mockRejectedValue(new NotFoundException());
    await expect(controller.uploadDocument('missing', PartnerDocumentKind.PAN, pdf)).rejects.toThrow(NotFoundException);
    expect(cloudinary.uploadFile).not.toHaveBeenCalled();
  });

  it('restricts the endpoint to administrators', () => {
    expect(Reflect.getMetadata('roles', PartnersController.prototype.uploadDocument)).toEqual(['admin']);
    expect(Reflect.getMetadata('__guards__', PartnersController)).toHaveLength(2);
  });
});
