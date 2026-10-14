import { AuthService } from './auth.service';

describe('partner profile photo', () => {
  it.each(['https://example.com/partner.png', null])('returns the saved photo %s', async (photo) => {
    const user = { name: 'Test Partner', email: 'partner@example.com', profile_photo: photo };
    const partner = { id: 'partner-1', status: 'ACTIVE', legal_name: 'Company',
      partner_users: [{ users: user, role: 'OWNER' }] };
    const service = Object.assign(Object.create(AuthService.prototype), {
      prisma: { partners: { findUnique: jest.fn().mockResolvedValue(partner) } },
      generatePartnerTokens: jest.fn().mockResolvedValue({ accessToken: 'token' }),
    }) as AuthService;
    const result = await service.getPartnerAuthProfile(partner as any);
    expect(result.partner.avatarUrl).toBe(photo);
    expect(result.partner.firstName).toBe('Test');
    expect(result.partner.email).toBe('partner@example.com');
  });
});
