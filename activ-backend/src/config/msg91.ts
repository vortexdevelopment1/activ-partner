export const MSG91_TIMEOUT_MS = 10_000;
export const PHONE_OTP_LENGTH = 4;
export const PHONE_OTP_EXPIRY_MS = 10 * 60_000;
export const PHONE_OTP_COOLDOWN_MS = 60_000;
export const PHONE_OTP_MAX_ATTEMPTS = 5;

export const isMsg91TemplateId = (value: string): boolean => /^[a-f\d]{24}$/i.test(value || '');

/** The approved team invitation is for Indian mobile numbers only. */
export function indianMobileDigits(phone: string): string | null {
  const compact = phone.replace(/[\s()-]/g, '');
  if (/^[6-9]\d{9}$/.test(compact)) return `91${compact}`;
  if (/^\+?91[6-9]\d{9}$/.test(compact)) return compact.replace(/^\+/, '');
  return null;
}
