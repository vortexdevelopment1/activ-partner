import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { AdminCreateVenueDto } from './dto/admin-create-venue.dto';

describe('admin venue initial activity selection', () => {
  const first = '00000000-0000-4000-8000-000000000001';
  const second = '00000000-0000-4000-8000-000000000002';
  const input = { partnerId: '00000000-0000-4000-8000-000000000003', name: 'Sports Arena' };

  it('accepts exactly one category', async () => {
    expect(await validate(plainToInstance(AdminCreateVenueDto, { ...input, categoryIds: [first] }))).toHaveLength(0);
  });

  it.each([
    { categoryIds: [] },
    { categoryIds: [first, second] },
    { categoryIds: [first, first] },
  ])('rejects an invalid category count: $categoryIds', async ({ categoryIds }) => {
    const errors = await validate(plainToInstance(AdminCreateVenueDto, { ...input, categoryIds }));
    expect(errors.some(error => error.property === 'categoryIds')).toBe(true);
  });

  it('retains inherited UUID validation', async () => {
    const errors = await validate(plainToInstance(AdminCreateVenueDto, { ...input, categoryIds: ['not-a-category-id'] }));
    expect(errors.some(error => error.property === 'categoryIds')).toBe(true);
  });

  it('rejects a scalar category ID rather than accepting it as an array', async () => {
    const errors = await validate(plainToInstance(AdminCreateVenueDto, { ...input, categoryIds: first }));
    expect(errors.some(error => error.property === 'categoryIds')).toBe(true);
  });
});
