import { paymentMethodLabel } from './payment-method';

describe('actual payment method labels', () => {
  const fetchBefore = global.fetch;
  const keyBefore = process.env.RAZORPAY_KEY_ID;
  const secretBefore = process.env.RAZORPAY_KEY_SECRET;
  let serial = 0;
  beforeEach(() => {
    process.env.RAZORPAY_KEY_ID = 'test-key'; process.env.RAZORPAY_KEY_SECRET = 'test-secret';
    global.fetch = jest.fn();
  });
  afterEach(() => {
    global.fetch = fetchBefore;
    if (keyBefore === undefined) delete process.env.RAZORPAY_KEY_ID; else process.env.RAZORPAY_KEY_ID = keyBefore;
    if (secretBefore === undefined) delete process.env.RAZORPAY_KEY_SECRET; else process.env.RAZORPAY_KEY_SECRET = secretBefore;
  });
  it.each(['upi', 'cash', 'card'])('labels a stored %s method directly', async provider => {
    expect(await paymentMethodLabel({ provider })).toBe(provider.toUpperCase());
    expect(global.fetch).not.toHaveBeenCalled();
  });
  it.each(['upi', 'card', 'wallet', 'netbanking'])('fetches and caches the actual Razorpay %s method', async method => {
    const id = `pay_test${++serial}`;
    (global.fetch as jest.Mock).mockResolvedValue({ ok: true,
      json: async () => ({ id, status: 'captured', amount: 90000, order_id: 'order_test', method }) });
    const payment = { provider: 'razorpay', provider_payment_id: id, provider_order_id: 'order_test', amount_paise: 90000n };
    expect(await paymentMethodLabel(payment)).toBe(method === 'netbanking' ? 'NET BANKING' : method.toUpperCase());
    await paymentMethodLabel(payment);
    expect(global.fetch).toHaveBeenCalledTimes(1);
  });
  it('does not guess UPI from a gateway, or fail bookings when the gateway is unavailable', async () => {
    expect(await paymentMethodLabel({ provider: 'razorpay' })).toBe('Online');
    (global.fetch as jest.Mock).mockRejectedValue(new Error('timeout'));
    expect(await paymentMethodLabel({ provider: 'razorpay', provider_payment_id: `pay_test${++serial}` })).toBe('Online');
  });
  it('rejects mismatched gateway payment details', async () => {
    (global.fetch as jest.Mock).mockResolvedValue({ ok: true, json: async () => ({ id: 'pay_other', method: 'upi', status: 'captured' }) });
    expect(await paymentMethodLabel({ provider: 'razorpay', provider_payment_id: `pay_test${++serial}` })).toBe('Online');
  });
});
