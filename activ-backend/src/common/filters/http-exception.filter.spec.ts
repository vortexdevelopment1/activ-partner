import { BadRequestException } from '@nestjs/common';
import { HttpExceptionFilter } from './http-exception.filter';

describe('HTTP database interruption response', () => {
  function setup() {
    const response = { setHeader: jest.fn(), status: jest.fn().mockReturnThis(), json: jest.fn() };
    const adapter = { reply: jest.fn(), isHeadersSent: jest.fn().mockReturnValue(false) };
    const filter = new HttpExceptionFilter({ httpAdapter: adapter } as any);
    const host = { switchToHttp: () => ({ getResponse: () => response, getRequest: () => ({ method: 'GET', url: '/venues' }) }),
      getArgByIndex: () => response } as any;
    return { response, adapter, filter, host };
  }

  it('returns a retryable 503 without exposing database details', () => {
    const { response, filter, host } = setup();
    filter.catch(new Error('Connection terminated unexpectedly'), host);
    expect(response.status).toHaveBeenCalledWith(503);
    expect(response.setHeader).toHaveBeenCalledWith('Retry-After', '1');
    expect(response.json).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 503, success: false }));
  });

  it('preserves normal HTTP validation errors', () => {
    const { response, filter, host } = setup();
    filter.catch(new BadRequestException('Invalid request'), host);
    expect(response.status).toHaveBeenCalledWith(400);
    expect(response.json).toHaveBeenCalledWith(expect.objectContaining({ message: 'Invalid request' }));
  });

  it('keeps unrelated exceptions as internal server errors', () => {
    const { adapter, filter, host, response } = setup();
    filter.catch(new Error('Unexpected application bug'), host);
    expect(adapter.reply).toHaveBeenCalledWith(response, expect.objectContaining({ statusCode: 500 }), 500);
  });
});
