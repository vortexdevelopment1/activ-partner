import { ConfigService } from '@nestjs/config';
import { ConflictException, ServiceUnavailableException } from '@nestjs/common';
import { RazorpayOrderClient, RazorpayOrderLookup } from './normalized-razorpay-order.service';

export function createRazorpayOrderClient(config: ConfigService): RazorpayOrderClient {
  const keyId = config.get<string>('RAZORPAY_KEY_ID');
  const keySecret = config.get<string>('RAZORPAY_KEY_SECRET');
  const timeoutMs = Number(config.get<string>('RAZORPAY_TIMEOUT_MS', '10000'));
  if (!keyId || !keySecret || !Number.isFinite(timeoutMs) || timeoutMs <= 0) throw new ConflictException('Razorpay configuration is incomplete');
  return async ({ amountPaise, currency, receipt }) => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch('https://api.razorpay.com/v1/orders', {
        method: 'POST', headers: { Authorization: `Basic ${Buffer.from(`${keyId}:${keySecret}`).toString('base64')}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ amount: amountPaise, currency, receipt }), signal: controller.signal,
      });
      const body: any = await response.json().catch(() => null);
      if (!response.ok || !body?.id || body.amount !== amountPaise || body.currency !== currency) throw new ServiceUnavailableException('Razorpay order creation failed');
      return { id: body.id, amount: body.amount, currency: body.currency };
    } catch (error) {
      if (error instanceof ServiceUnavailableException) throw error;
      throw new ServiceUnavailableException('Razorpay order outcome is uncertain');
    } finally { clearTimeout(timer); }
  };
}

export function createRazorpayOrderLookupClient(config: ConfigService): RazorpayOrderLookup {
  const keyId = config.get<string>('RAZORPAY_KEY_ID');
  const keySecret = config.get<string>('RAZORPAY_KEY_SECRET');
  const timeoutMs = Number(config.get<string>('RAZORPAY_TIMEOUT_MS', '10000'));
  if (!keyId || !keySecret || !Number.isFinite(timeoutMs) || timeoutMs <= 0) throw new ConflictException('Razorpay configuration is incomplete');
  return async (orderId: string) => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(`https://api.razorpay.com/v1/orders/${encodeURIComponent(orderId)}`, {
        method: 'GET', headers: { Authorization: `Basic ${Buffer.from(`${keyId}:${keySecret}`).toString('base64')}` }, signal: controller.signal,
      });
      if (response.status === 404) return null;
      const body: any = await response.json().catch(() => null);
      if (!response.ok || body?.id !== orderId || !Number.isSafeInteger(body?.amount) || typeof body?.currency !== 'string') throw new ServiceUnavailableException('Razorpay order lookup failed');
      return { id: body.id, amount: body.amount, currency: body.currency, status: body.status };
    } catch (error) {
      if (error instanceof ServiceUnavailableException) throw error;
      throw new ServiceUnavailableException('Razorpay order lookup outcome is uncertain');
    } finally { clearTimeout(timer); }
  };
}
