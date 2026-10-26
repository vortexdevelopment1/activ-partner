import { BadRequestException, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { CloudinaryService } from './cloudinary.service';

describe('CloudinaryService PDF delivery', () => {
  const config = {
    get: (key: string) => ({
      CLOUDINARY_CLOUD_NAME: 'test-cloud',
      CLOUDINARY_API_KEY: 'key',
      CLOUDINARY_API_SECRET: 'secret',
    })[key],
  } as any;
  const service = new CloudinaryService(config);
  const originalFetch = global.fetch;

  afterEach(() => { global.fetch = originalFetch; });

  it('streams only a valid PDF from the configured Cloudinary account', async () => {
    global.fetch = jest.fn().mockResolvedValue(new Response(Buffer.from('%PDF-1.7\nbody'), {
      status: 200,
      headers: { 'content-type': 'application/octet-stream' },
    })) as any;

    const result = await service.downloadPdf(
      'https://res.cloudinary.com/test-cloud/raw/upload/v1/activ/legal/document.pdf',
    );

    expect(result.subarray(0, 5).toString()).toBe('%PDF-');
  });

  it('rejects URLs outside the configured Cloudinary account', async () => {
    await expect(service.downloadPdf('https://example.com/document.pdf'))
      .rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects Cloudinary error pages instead of sending them as PDFs', async () => {
    global.fetch = jest.fn().mockImplementation(async () =>
      new Response('<html>blocked</html>', { status: 200 })) as any;

    await expect(service.downloadPdf(
      'https://res.cloudinary.com/test-cloud/raw/upload/v1/activ/legal/document.pdf',
    )).rejects.toBeInstanceOf(ServiceUnavailableException);
  });

  const url = 'https://res.cloudinary.com/test-cloud/raw/upload/v1/activ/legal/document.pdf';

  it('identifies an explicit PDF delivery restriction', async () => {
    global.fetch = jest.fn().mockImplementation(async () => new Response('', {
      status: 401, headers: { 'x-cld-error': 'PDF delivery is blocked' },
    })) as any;
    await expect(service.downloadPdf(url)).rejects.toThrow('Allow delivery of PDF and ZIP files');
  });

  it('reports missing assets separately from account restrictions', async () => {
    global.fetch = jest.fn().mockImplementation(async () => new Response('', { status: 404 })) as any;
    await expect(service.downloadPdf(url)).rejects.toBeInstanceOf(NotFoundException);
  });

  it('does not claim a security restriction when Cloudinary is unreachable', async () => {
    global.fetch = jest.fn().mockRejectedValue(new Error('Network failure')) as any;
    await expect(service.downloadPdf(url)).rejects.toThrow('The PDF could not be retrieved');
  });

  it('still opens a legacy image PDF when the raw URL is missing', async () => {
    global.fetch = jest.fn()
      .mockResolvedValueOnce(new Response('', { status: 404 }))
      .mockResolvedValueOnce(new Response(Buffer.from('%PDF-1.7\nbody'), { status: 200 })) as any;
    expect((await service.downloadPdf(url)).subarray(0, 5).toString()).toBe('%PDF-');
  });
});
