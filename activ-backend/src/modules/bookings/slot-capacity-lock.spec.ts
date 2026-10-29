import { lockSlotForCapacity } from './slot-capacity';

describe('slot capacity transaction lock', () => {
  it('uses a caller-owned PostgreSQL row lock and performs no mutation', async () => {
    const query = jest.fn().mockResolvedValue([{ id: 'slot-1' }]);
    await lockSlotForCapacity({ $queryRaw: query }, 'slot-1');
    expect(query).toHaveBeenCalledTimes(1);
    const template = query.mock.calls[0][0] as TemplateStringsArray;
    expect(Array.from(template).join('?')).toContain('SELECT id FROM slots');
    expect(Array.from(template).join('?')).toContain('FOR UPDATE');
  });
});
