import { BadRequestException } from '@nestjs/common';
import { VenuesController } from './venues.controller';

describe('activity photo review uploads', () => {
  const venuesService = { uploadActivityImages: jest.fn() };
  const cloudinaryService = { uploadFiles: jest.fn() };
  const controller = Object.assign(Object.create(VenuesController.prototype), {
    venuesService, cloudinaryService,
  }) as VenuesController;

  beforeEach(() => {
    jest.clearAllMocks();
    cloudinaryService.uploadFiles.mockResolvedValue(['photo-url']);
    venuesService.uploadActivityImages.mockResolvedValue({ id: 'activity', imageUrls: ['photo-url'] });
  });

  it('replaces the reviewed batch on retry', async () => {
    const files = [{ buffer: Buffer.from('photo') }] as Express.Multer.File[];
    await controller.uploadActivityImages('activity', { id: 'partner' }, files, 'true');
    expect(venuesService.uploadActivityImages).toHaveBeenCalledWith(
      'activity', ['photo-url'], 'partner', true,
    );
  });

  it('preserves append behavior for other callers', async () => {
    await controller.uploadActivityImages('activity', { id: 'partner' }, [{}] as Express.Multer.File[]);
    expect(venuesService.uploadActivityImages).toHaveBeenCalledWith(
      'activity', ['photo-url'], 'partner', false,
    );
  });

  it('rejects an empty replacement without deleting saved photos', async () => {
    await expect(controller.uploadActivityImages('activity', { id: 'partner' }, [], 'true'))
      .rejects.toBeInstanceOf(BadRequestException);
    expect(cloudinaryService.uploadFiles).not.toHaveBeenCalled();
    expect(venuesService.uploadActivityImages).not.toHaveBeenCalled();
  });
});
