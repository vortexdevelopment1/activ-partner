/** PAN-based GSTIN structure and base-36 checksum validation. */
export function isValidGstin(value: unknown): boolean {
  if (typeof value !== 'string') return false;
  const gstin = value.trim().toUpperCase();
  if (!/^(0[1-9]|[12][0-9]|3[0-8]|97|99)[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/.test(gstin)) return false;
  const alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  let sum = 0;
  for (let index = 0; index < 14; index++) {
    const product = alphabet.indexOf(gstin[index]) * (index % 2 === 0 ? 1 : 2);
    sum += Math.floor(product / 36) + product % 36;
  }
  return gstin[14] === alphabet[(36 - sum % 36) % 36];
}
