import { BadRequestException } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { isValidGstin } from '../../common/utils/gstin-validation';
import { SubmitGstVerificationDto } from '../partners/dto/submit-gst-verification.dto';
import { VenuesController } from './venues.controller';

describe('legal GSTIN validation', () => {
  const venuesService = { saveLegalInfo: jest.fn().mockResolvedValue({}) };
  const cloudinaryService = { uploadFile: jest.fn() };
  const controller = Object.assign(Object.create(VenuesController.prototype), {
    venuesService, cloudinaryService,
  }) as VenuesController;
  beforeEach(() => jest.clearAllMocks());

  it.each(['27AAPFU0939F1ZV', '33ABCCA3430E1ZD', ' 27aapfu0939f1zv '])('accepts valid GSTIN %s', value => {
    expect(isValidGstin(value)).toBe(true);
  });
  it.each(['Heueueieieieidu', '27AAPFU0939F1ZA', '00AAPFU0939F1ZV',
    '27AAPFU0939F0ZV', '27AAPFU0939F1YV', '27AAPFU0939F1Z',
    '27AAPFU0939F1ZVV', '27AAPF!0939F1ZV', '', null, 123])('rejects invalid GSTIN %s', async value => {
    expect(isValidGstin(value)).toBe(false);
    if (value === '') return; // GST remains optional for venue legal information.
    await expect(controller.saveLegalInfo('venue', { id: 'partner' },
      { gstNumber: value as string }, { gstinDoc: [{} as Express.Multer.File] }))
      .rejects.toBeInstanceOf(BadRequestException);
    expect(cloudinaryService.uploadFile).not.toHaveBeenCalled();
    expect(venuesService.saveLegalInfo).not.toHaveBeenCalled();
  });
  it.each([undefined, '', '  '])('allows omitted optional GSTIN %s', async gstNumber => {
    await controller.saveLegalInfo('venue', { id: 'partner' }, { gstNumber }, {});
    expect(venuesService.saveLegalInfo).toHaveBeenCalledWith('venue', 'partner',
      gstNumber === undefined ? {} : { gstNumber: '' }, false);
  });
  it('normalizes valid GSTIN before saving', async () => {
    await controller.saveLegalInfo('venue', { id: 'partner' }, { gstNumber: ' 27aapfu0939f1zv ' }, {});
    expect(venuesService.saveLegalInfo).toHaveBeenCalledWith('venue', 'partner', { gstNumber: '27AAPFU0939F1ZV' }, false);
  });
  it('uses the same checksum validation for GST verification requests', async () => {
    const dto = plainToInstance(SubmitGstVerificationDto, { gstNumber: ' 27aapfu0939f1zv ', gstName: 'Club' });
    expect(await validate(dto)).toHaveLength(0);
    expect(dto.gstNumber).toBe('27AAPFU0939F1ZV');
    dto.gstNumber = '27AAPFU0939F1ZA';
    expect((await validate(dto)).map(error => error.property)).toContain('gstNumber');
  });
});
