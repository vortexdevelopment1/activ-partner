import { buildLegacyIdempotencyContext, extractLegacyIdempotencyKey } from './legacy-idempotency';

describe('legacy booking idempotency compatibility', () => {
  const dto: any = { venueId: 'v', serviceId: 's', bookingDate: '2030-01-01', startTime: '10:00', endTime: '11:00' };

  it('reads an optional header without changing the request body', () => {
    expect(extractLegacyIdempotencyKey({ 'Idempotency-Key': ' retry-1 ' })).toBe('retry-1');
    expect(buildLegacyIdempotencyContext(dto, 'user', 'slot', { 'idempotency-key': 'retry-1' }).guaranteed).toBe(true);
  });
  it('does not fabricate identity for legacy requests without a key', () => {
    const context = buildLegacyIdempotencyContext(dto, 'user', 'slot');
    expect(context.key).toBeUndefined();
    expect(context.guaranteed).toBe(false);
  });
  it('produces the same fingerprint for retries and changes it for payload changes', () => {
    const first = buildLegacyIdempotencyContext(dto, 'user', 'slot', { 'idempotency-key': 'k' });
    const retry = buildLegacyIdempotencyContext({ ...dto }, 'user', 'slot', { 'idempotency-key': 'k' });
    const changed = buildLegacyIdempotencyContext({ ...dto, endTime: '12:00' }, 'user', 'slot', { 'idempotency-key': 'k' });
    expect(retry.fingerprint).toBe(first.fingerprint);
    expect(changed.fingerprint).not.toBe(first.fingerprint);
  });
  it('rejects malformed or oversized header values', () => {
    expect(extractLegacyIdempotencyKey({ 'idempotency-key': ['a', 'b'] })).toBeUndefined();
    expect(extractLegacyIdempotencyKey({ 'idempotency-key': 'x'.repeat(256) })).toBeUndefined();
  });
});
