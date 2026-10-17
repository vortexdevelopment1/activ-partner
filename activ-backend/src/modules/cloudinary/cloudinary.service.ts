import { BadRequestException, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash } from 'crypto';
import { Blob } from 'buffer';

type CloudinaryResourceType = 'image' | 'raw' | 'video' | 'auto';

@Injectable()
export class CloudinaryService {
  private readonly cloudName: string;
  private readonly apiKey: string;
  private readonly apiSecret: string;

  constructor(config: ConfigService) {
    this.cloudName = (config.get<string>('CLOUDINARY_CLOUD_NAME') || config.get<string>('CLOUD_NAME') || '').trim();
    this.apiKey = (config.get<string>('CLOUDINARY_API_KEY') || config.get<string>('API_KEY') || '').trim();
    this.apiSecret = (config.get<string>('CLOUDINARY_API_SECRET') || config.get<string>('API_SECRET') || '').trim();
  }

  get isConfigured(): boolean {
    return Boolean(this.cloudName && this.apiKey && this.apiSecret);
  }

  async uploadFile(
    file: Express.Multer.File | undefined,
    folder: string,
    resourceType: CloudinaryResourceType = 'auto',
  ): Promise<string | undefined> {
    if (!file) return undefined;
    if (!file.buffer) {
      throw new BadRequestException('Upload file is missing in-memory data.');
    }
    if (!this.isConfigured) {
      throw new ServiceUnavailableException(
        'Cloudinary is not configured. Set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY and CLOUDINARY_API_SECRET.',
      );
    }

    const uploadResourceType = this.resourceTypeForFile(file, resourceType);
    const timestamp = Math.floor(Date.now() / 1000).toString();
    const signature = this.sign({ folder, timestamp });
    const form = new (globalThis as any).FormData();
    form.append('file', new Blob([file.buffer], { type: file.mimetype }), file.originalname);
    form.append('folder', folder);
    form.append('timestamp', timestamp);
    form.append('api_key', this.apiKey);
    form.append('signature', signature);

    const response = await (globalThis as any).fetch(
      `https://api.cloudinary.com/v1_1/${this.cloudName}/${uploadResourceType}/upload`,
      { method: 'POST', body: form },
    );

    const body = await response.json().catch(() => ({}));
    if (!response.ok || !body.secure_url) {
      throw new ServiceUnavailableException(
        body.error?.message || 'Cloudinary upload failed. Please try again.',
      );
    }

    return body.secure_url;
  }

  async uploadFiles(
    files: Express.Multer.File[] | undefined,
    folder: string,
    resourceType: CloudinaryResourceType = 'auto',
  ): Promise<string[]> {
    if (!files?.length) return [];
    return Promise.all(files.map((file) => this.uploadFile(file, folder, resourceType))) as Promise<string[]>;
  }

  async downloadPdf(sourceUrl: string): Promise<Buffer> {
    let parsed: URL;
    try {
      parsed = new URL(sourceUrl);
    } catch {
      throw new BadRequestException('Invalid document URL.');
    }
    if (
      parsed.protocol !== 'https:' ||
      parsed.hostname !== 'res.cloudinary.com' ||
      !parsed.pathname.startsWith(`/${this.cloudName}/`) ||
      !/\/(?:raw|image)\/upload\//.test(parsed.pathname)
    ) {
      throw new BadRequestException('Only documents from the configured Cloudinary account can be opened.');
    }

    const candidates = [sourceUrl];
    if (sourceUrl.includes('/image/upload/')) {
      candidates.push(sourceUrl.replace('/image/upload/', '/raw/upload/'));
    } else if (sourceUrl.includes('/raw/upload/')) {
      candidates.push(sourceUrl.replace('/raw/upload/', '/image/upload/'));
    }

    for (const candidate of [...new Set(candidates)]) {
      const response = await fetch(candidate, { headers: { Accept: 'application/pdf' } }).catch(() => null);
      if (!response?.ok) continue;
      const length = Number(response.headers.get('content-length') || 0);
      if (length > 10 * 1024 * 1024) throw new BadRequestException('PDF exceeds the 10 MB viewing limit.');
      const bytes = Buffer.from(await response.arrayBuffer());
      if (bytes.length <= 10 * 1024 * 1024 && bytes.subarray(0, 5).toString() === '%PDF-') {
        return bytes;
      }
    }

    throw new ServiceUnavailableException(
      'Cloudinary did not deliver a valid PDF. Enable PDF and ZIP file delivery in Cloudinary Security settings, then try again.',
    );
  }

  private resourceTypeForFile(
    file: Express.Multer.File,
    requested: CloudinaryResourceType,
  ): CloudinaryResourceType {
    if (requested !== 'auto') return requested;
    const name = file.originalname?.toLowerCase() ?? '';
    if (file.mimetype === 'application/pdf' || name.endsWith('.pdf')) {
      return 'raw';
    }
    return requested;
  }

  private sign(params: Record<string, string>): string {
    const payload = Object.keys(params)
      .sort()
      .map((key) => `${key}=${params[key]}`)
      .join('&');
    return createHash('sha1').update(`${payload}${this.apiSecret}`).digest('hex');
  }
}
