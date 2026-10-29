import { Injectable, INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { PassportModule, PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { EmailDeliveriesController } from './email-deliveries.controller';
import { EmailDeliveryService } from './email-delivery.service';
import { AuthController } from '../auth/auth.controller';
import { AuthService } from '../auth/auth.service';
import { GoogleOAuthService } from './google-oauth.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';

const secret = 'email-access-tests-only';
@Injectable()
class TestStrategy extends PassportStrategy(Strategy) {
  constructor() { super({ jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(), secretOrKey: secret }); }
  validate(payload: any) { return { id: 'test-user', role: payload.role }; }
}

describe('protected email operations', () => {
  let app: INestApplication;
  let url: string;
  const deliveries = { list: jest.fn().mockResolvedValue([]), retry: jest.fn().mockResolvedValue({ sent: true }) };
  const oauth = { createAuthorizationUrl: jest.fn().mockReturnValue('https://accounts.google.com/test-only'), completeAuthorization: jest.fn(),
    credentialStatus: jest.fn().mockResolvedValue({ source: 'database', status: 'NOT_CONFIGURED', verified: false }) };
  const headers = (role?: string) => role ? { Authorization: `Bearer ${new JwtService({ secret }).sign({ role })}` } : {};
  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [PassportModule],
      controllers: [EmailDeliveriesController, AuthController], providers: [TestStrategy, JwtAuthGuard, RolesGuard,
        { provide: EmailDeliveryService, useValue: deliveries }, { provide: GoogleOAuthService, useValue: oauth },
        { provide: AuthService, useValue: {} }] }).compile();
    app = module.createNestApplication({ logger: false });
    app.setGlobalPrefix('api/v1');
    app.useGlobalGuards(new JwtAuthGuard(app.get(Reflector)), new RolesGuard(app.get(Reflector)));
    await app.listen(0, '127.0.0.1');
    url = await app.getUrl();
  });
  afterAll(async () => { await app?.close(); });

  it.each([undefined, 'partner'])('rejects delivery access for %s', async role => {
    const result = await fetch(`${url}/api/v1/email-deliveries`, { headers: headers(role) });
    expect(result.status).toBe(role ? 403 : 401);
  });
  it('allows admin metadata access', async () => {
    const result = await fetch(`${url}/api/v1/email-deliveries`, { headers: headers('admin') });
    expect(result.status).toBe(200);
    expect(await result.json()).toEqual([]);
  });
  it('allows an admin retry without a request body and never confirms an unknown outcome implicitly', async () => {
    const id = '11111111-1111-4111-8111-111111111111';
    const result = await fetch(`${url}/api/v1/email-deliveries/${id}/retry`, { method: 'POST', headers: headers('admin') });
    expect(result.status).toBe(201);
    expect(deliveries.retry).toHaveBeenCalledWith(id, false);
  });
  it('passes the setup secret only through the protected connect endpoint', async () => {
    const result = await fetch(`${url}/api/v1/auth/google/connect`, { headers: { ...headers('admin'), 'x-google-oauth-setup-key': 'test-setup-key' }, redirect: 'manual' });
    expect(result.status).toBe(302);
    expect(oauth.createAuthorizationUrl).toHaveBeenCalledWith('test-setup-key');
  });
  it('rejects unauthenticated connect access', async () => {
    expect((await fetch(`${url}/api/v1/auth/google/connect`, { redirect: 'manual' })).status).toBe(401);
  });
  it.each([undefined, 'partner'])('rejects credential status access for %s', async role => {
    expect((await fetch(`${url}/api/v1/auth/google/status`, { headers: headers(role) })).status).toBe(role ? 403 : 401);
  });
  it('allows only admin read-only credential metadata', async () => {
    const result = await fetch(`${url}/api/v1/auth/google/status`, { headers: headers('admin') });
    expect(result.status).toBe(200);
    expect(await result.json()).toEqual({ source: 'database', status: 'NOT_CONFIGURED', verified: false });
  });
  it('rejects partner access to connect even with a setup-key header', async () => {
    expect((await fetch(`${url}/api/v1/auth/google/connect`, { headers: { ...headers('partner'), 'x-google-oauth-setup-key': 'test-setup-key' }, redirect: 'manual' })).status).toBe(403);
  });
  it('sanitizes callback failures without reporting verification', async () => {
    oauth.completeAuthorization.mockRejectedValueOnce(new Error('PRIVATE-REFRESH-TOKEN'));
    const result = await fetch(`${url}/api/v1/auth/google/callback?code=mock-code&state=mock-state`);
    expect(result.status).toBe(400);
    expect(await result.text()).not.toContain('PRIVATE');
  });
});
