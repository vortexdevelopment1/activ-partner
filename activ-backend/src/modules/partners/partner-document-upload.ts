import { BadRequestException } from '@nestjs/common';
import { extname } from 'path';

export enum PartnerDocumentKind {
  AVATAR = 'avatar',
  PAN = 'pan',
  GST = 'gst',
  CANCELLED_CHEQUE = 'cancelled-cheque',
  AADHAAR = 'aadhaar',
}

export const PARTNER_DOCUMENT_MAX_BYTES = 10 * 1024 * 1024;

export function validatePartnerDocument(file: Express.Multer.File | undefined, kind: PartnerDocumentKind) {
  if (!file?.buffer?.length) throw new BadRequestException('Select a document to upload');
  if (file.buffer.length > PARTNER_DOCUMENT_MAX_BYTES) throw new BadRequestException('File must be 10 MB or smaller');
  const bytes = file.buffer;
  const formats = [
    { extensions: ['.jpg', '.jpeg'], mime: 'image/jpeg', matches: bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff },
    { extensions: ['.png'], mime: 'image/png', matches: bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])) },
    { extensions: ['.webp'], mime: 'image/webp', matches: bytes.subarray(0, 4).toString() === 'RIFF' && bytes.subarray(8, 12).toString() === 'WEBP' },
    { extensions: ['.pdf'], mime: 'application/pdf', matches: bytes.subarray(0, 5).toString() === '%PDF-' },
  ];
  const format = formats.find(format => format.extensions.includes(extname(file.originalname).toLowerCase()) && format.mime === file.mimetype && format.matches);
  if (!format || (kind === PartnerDocumentKind.AVATAR && format.mime === 'application/pdf')) {
    throw new BadRequestException(kind === PartnerDocumentKind.AVATAR
      ? 'Profile photo must be a JPG, PNG or WebP image'
      : 'Document must be a JPG, PNG, WebP image or PDF');
  }
}
