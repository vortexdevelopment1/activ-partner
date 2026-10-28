const labels: Record<string, string> = {
  upi: 'UPI', cash: 'CASH', card: 'CARD', netbanking: 'NET BANKING',
  wallet: 'WALLET', bank_transfer: 'BANK TRANSFER', emi: 'EMI', paylater: 'PAY LATER',
};
type Payment = { provider: string; provider_payment_id?: string | null;
  provider_order_id?: string | null; amount_paise?: bigint | number };
const cache = new Map<string, { expires: number; result: Promise<string> }>();

// A gateway name is not a payment method. Historical normalized payments only
// store the gateway payment ID, so obtain the actual method from its payment API.
export async function paymentMethodLabel(payment?: Payment): Promise<string> {
  if (!payment) return 'Not available';
  const provider = payment.provider?.trim().toLowerCase();
  if (labels[provider]) return labels[provider];
  const key = process.env.RAZORPAY_KEY_ID;
  const secret = process.env.RAZORPAY_KEY_SECRET;
  const id = payment.provider_payment_id;
  if (provider !== 'razorpay' || !id || !/^pay_[a-zA-Z0-9]+$/.test(id) || !key || !secret) return 'Online';
  const cacheKey = `${key}:${id}:${payment.provider_order_id}:${payment.amount_paise}`;
  const saved = cache.get(cacheKey);
  if (saved && saved.expires > Date.now()) return saved.result;
  // Bound memory for long-running instances. Only method labels are retained.
  if (cache.size >= 1000) cache.delete(cache.keys().next().value!);
  const entry = { expires: Date.now() + 60_000, result: Promise.resolve('Online') };
  entry.result = (async () => {
    try {
      const response = await fetch(`https://api.razorpay.com/v1/payments/${id}`, {
        headers: { Authorization: `Basic ${Buffer.from(`${key}:${secret}`).toString('base64')}` },
        signal: AbortSignal.timeout(3000),
      });
      if (!response.ok) return 'Online';
      const data = await response.json() as Record<string, unknown>;
      if (data.id !== id || data.status !== 'captured' ||
        (payment.amount_paise != null && Number(payment.amount_paise) !== data.amount) ||
        (payment.provider_order_id && data.order_id !== payment.provider_order_id)) return 'Online';
      const label = labels[String(data.method).toLowerCase()];
      if (!label) return 'Online';
      entry.expires = Date.now() + 60 * 60_000;
      return label;
    } catch { return 'Online'; }
  })();
  cache.set(cacheKey, entry);
  return entry.result;
}
