import { BadRequestException, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { CloudinaryService } from './cloudinary.service';
import { createHash } from 'crypto';

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

  afterEach(() => { global.fetch = originalFetch; jest.restoreAllMocks(); });

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

  it('retrieves a blocked raw PDF through a short-lived signed server request', async () => {
    jest.spyOn(Date, 'now').mockReturnValue(1800000000000);
    global.fetch = jest.fn().mockImplementation(async (target: string) => {
      if (!target.startsWith('https://api.cloudinary.com/')) return new Response('', { status: 401 });
      const signed = new URL(target);
      expect(signed.pathname).toBe('/v1_1/test-cloud/raw/download');
      expect(signed.searchParams.get('public_id')).toBe('activ/legal/document.pdf');
      expect(signed.searchParams.has('format')).toBe(false);
      expect(signed.searchParams.get('type')).toBe('upload');
      expect(signed.searchParams.get('expires_at')).toBe('1800000120');
      const expected = createHash('sha1').update('expires_at=1800000120&public_id=activ/legal/document.pdf&timestamp=1800000000&type=uploadsecret').digest('hex');
      expect(signed.searchParams.get('signature')).toBe(expected);
      expect(signed.searchParams.get('api_key')).toBe('key');
      return new Response(Buffer.from('%PDF-1.7\nbody'), { status: 200 });
    }) as any;
    expect((await service.downloadPdf(url)).subarray(0, 5).toString()).toBe('%PDF-');
  });

  it.each(['upload', 'private', 'authenticated'])('downloads an original image PDF with delivery type %s', async type => {
    global.fetch = jest.fn().mockImplementation(async (target: string) => {
      if (!target.startsWith('https://api.cloudinary.com/')) return new Response('', { status: 403 });
      const signed = new URL(target);
      expect(signed.pathname).toBe('/v1_1/test-cloud/image/download');
      expect(signed.searchParams.get('public_id')).toBe('activ/legal/pan card');
      expect(signed.searchParams.get('format')).toBe('pdf');
      expect(signed.searchParams.get('type')).toBe(type);
      return new Response(Buffer.from('%PDF-1.7\nbody'), { status: 200 });
    }) as any;
    expect((await service.downloadPdf(`https://res.cloudinary.com/test-cloud/image/${type}/v123/activ/legal/pan%20card.pdf`)).subarray(0, 5).toString()).toBe('%PDF-');
  });

  it('never signs a document from another cloud account', async () => {
    global.fetch = jest.fn() as any;
    await expect(service.downloadPdf('https://res.cloudinary.com/other-account/raw/upload/v1/document.pdf')).rejects.toBeInstanceOf(BadRequestException);
    expect(global.fetch).not.toHaveBeenCalled();
  });

  it('does not send Cloudinary HTML errors back as PDFs after signed access fails', async () => {
    global.fetch = jest.fn().mockImplementation(async (target: string) => new Response('<html>denied</html>', {
      status: target.startsWith('https://api.cloudinary.com/') ? 200 : 401,
    })) as any;
    await expect(service.downloadPdf(url)).rejects.toThrow('Cloudinary denied access');
  });

  it('enforces the PDF size limit on authenticated downloads too', async () => {
    global.fetch = jest.fn().mockImplementation(async (target: string) =>
      target.startsWith('https://api.cloudinary.com/')
        ? new Response('', { status: 200, headers: { 'content-length': String(11 * 1024 * 1024) } })
        : new Response('', { status: 401 })) as any;
    await expect(service.downloadPdf(url)).rejects.toThrow('10 MB');
  });
});
