import {
  canReserveCapacity,
  generateCandidatePublicCode,
  nextBookedQuantity,
  resolveBookingPolicyVersion,
} from './normalized-booking-contract';

describe('normalized booking contract utilities', () => {
  it('generates an unpredictable-looking public-code candidate without exposing a booking reference', () => {
    const code = generateCandidatePublicCode(() => Buffer.from('0123456789abcdef'));
    expect(code).toBe('ACTP-MDEyMzQ1Njc4OWFiY2RlZg');
    expect(code).not.toContain('ACT-');
  });

  it('does not fabricate a missing policy version', () => {
    expect(resolveBookingPolicyVersion(' v1 ')).toBe('v1');
    expect(() => resolveBookingPolicyVersion(null)).toThrow('Booking policy version is missing');
    expect(() => resolveBookingPolicyVersion(' ')).toThrow('Booking policy version is missing');
  });

  it('calculates capacity without allowing negative or over-capacity values', () => {
    expect(canReserveCapacity(2, 1)).toBe(true);
    expect(nextBookedQuantity(2, 1)).toBe(2);
    expect(canReserveCapacity(2, 2)).toBe(false);
    expect(canReserveCapacity(2, -1)).toBe(false);
    expect(() => nextBookedQuantity(2, 2)).toThrow('Slot capacity is unavailable');
  });
});
