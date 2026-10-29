import { ConfigService } from '@nestjs/config';
import { createRazorpayOrderClient, createRazorpayOrderLookupClient } from './razorpay-order-client';

describe('Razorpay order client', () => {
  afterEach(() => jest.restoreAllMocks());
  it('creates a server-side INR order with paise and auth', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify({ id: 'order_1', amount: 1250, currency: 'INR' }), { status: 200 }));
    const client = createRazorpayOrderClient(new ConfigService({ RAZORPAY_KEY_ID: 'key', RAZORPAY_KEY_SECRET: 'secret', RAZORPAY_TIMEOUT_MS: '1000' }));
    await expect(client({ amountPaise: 1250, currency: 'INR', receipt: 'booking:1' })).resolves.toMatchObject({ id: 'order_1' });
    expect(fetchMock).toHaveBeenCalledWith('https://api.razorpay.com/v1/orders', expect.objectContaining({ method: 'POST', body: JSON.stringify({ amount: 1250, currency: 'INR', receipt: 'booking:1' }) }));
  });
  it('fails closed on provider/network uncertainty', async () => {
    jest.spyOn(global, 'fetch').mockRejectedValue(new Error('timeout'));
    const client = createRazorpayOrderClient(new ConfigService({ RAZORPAY_KEY_ID: 'key', RAZORPAY_KEY_SECRET: 'secret', RAZORPAY_TIMEOUT_MS: '1000' }));
    await expect(client({ amountPaise: 1250, currency: 'INR', receipt: 'booking:1' })).rejects.toThrow('uncertain');
  });
  it('looks up an authenticated provider order', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify({ id: 'order_1', amount: 1250, currency: 'INR', status: 'created' }), { status: 200 }));
    const lookup = createRazorpayOrderLookupClient(new ConfigService({ RAZORPAY_KEY_ID: 'key', RAZORPAY_KEY_SECRET: 'secret', RAZORPAY_TIMEOUT_MS: '1000' }));
    await expect(lookup('order_1')).resolves.toMatchObject({ id: 'order_1', amount: 1250 });
    expect(fetchMock).toHaveBeenCalledWith('https://api.razorpay.com/v1/orders/order_1', expect.objectContaining({ method: 'GET' }));
  });
  it('returns null for a missing provider order', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response('', { status: 404 }));
    const lookup = createRazorpayOrderLookupClient(new ConfigService({ RAZORPAY_KEY_ID: 'key', RAZORPAY_KEY_SECRET: 'secret' }));
    await expect(lookup('missing')).resolves.toBeNull();
  });
});
