import { assertLockedSlotCapacity, lockSlotsForCapacity } from './slot-capacity-coordinator';

describe('inactive capacity transaction primitives', () => {
  it('locks multiple slots in deterministic order and deduplicates IDs', async () => {
    const calls: string[] = [];
    const tx = {
      $queryRaw: jest.fn(async (template: TemplateStringsArray, ...values: string[]) => {
        calls.push(`${Array.from(template).join('?')}:${values.join(',')}`);
        return [];
      }),
    };
    await lockSlotsForCapacity(tx as any, ['slot-b', 'slot-a', 'slot-b']);
    expect(calls).toEqual([
      expect.stringContaining('slot-a'),
      expect.stringContaining('slot-b'),
    ]);
    expect(tx.$queryRaw).toHaveBeenCalledTimes(2);
    expect(calls[0]).toContain('FOR UPDATE');
  });

  it('validates occupancy only after the caller has acquired the lock', () => {
    expect(() => assertLockedSlotCapacity(2, 1, 1)).not.toThrow();
    expect(() => assertLockedSlotCapacity(2, 2, 1)).toThrow('Slot capacity is unavailable');
    expect(() => assertLockedSlotCapacity(2, 0, 1, 'BLOCKED')).toThrow('Slot is not available');
  });
});
