import { AuthService } from './auth.service';

describe('partner profile documents', () => {
  const reviewedAt = new Date('2026-10-07T10:00:00Z');
  const document = {
    aadhaar_card_url: '/uploads/legal/aadhaar.jpg',
    pan_card_url: '/uploads/legal/pan.pdf',
    gstin_doc_url: '/uploads/legal/gst.pdf',
    gst_number: '27AAPFU0939F1ZV',
    gst_name: 'Venue Company',
    updated_at: reviewedAt,
  };

  function fixture(venues: any[], business: any = null) {
    const partner = {
      id: 'partner-1', status: 'ACTIVE', legal_name: 'Company',
      partner_business_profiles: business,
      partner_users: [{ users: { name: 'Partner', email: 'test@example.com' }, role: 'OWNER' }],
      venues,
    };
    const findUnique = jest.fn().mockResolvedValue(partner);
    const service = Object.assign(Object.create(AuthService.prototype), {
      prisma: { partners: { findUnique } },
      generatePartnerTokens: jest.fn().mockResolvedValue({ accessToken: 'token' }),
    }) as AuthService;
    return { service, partner, findUnique };
  }

  it('returns stored venue URLs and real approval dates from the authenticated partner', async () => {
    const { service, partner, findUnique } = fixture([
      { id: 'venue-1', status: 'PUBLISHED', review_status: 'approved', approved_at: reviewedAt,
        partner_venue_legal_documents: document },
    ]);
    const result = await service.getPartnerAuthProfile(partner as any);
    expect(findUnique).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: 'partner-1' },
      include: expect.objectContaining({ venues: expect.objectContaining({
        select: expect.objectContaining({ partner_venue_legal_documents: true }),
      }) }),
    }));
    expect(result.partner.legalDocuments).toEqual([expect.objectContaining({
      venueId: 'venue-1', aadhaarCardUrl: document.aadhaar_card_url,
      panCardUrl: document.pan_card_url, gstinDocUrl: document.gstin_doc_url,
      isVerified: true, aadhaarVerifiedAt: reviewedAt, panVerifiedAt: reviewedAt,
      gstVerifiedAt: reviewedAt, documentsUpdatedAt: reviewedAt,
    })]);
  });

  it('does not mark pending documents verified because the partner is active', async () => {
    const { service, partner } = fixture([
      { id: 'venue-1', status: 'DRAFT', review_status: 'pending', approved_at: null,
        partner_venue_legal_documents: document },
    ]);
    const result = await service.getPartnerAuthProfile(partner as any);
    expect(result.partner.isVerified).toBe(false);
    expect(result.partner.legalDocuments[0]).toMatchObject({
      aadhaarCardUrl: document.aadhaar_card_url, isVerified: false, aadhaarVerifiedAt: null,
    });
  });

  it('keeps venues separate and supports business profile documents', async () => {
    const { service, partner } = fixture([
      { id: 'venue-1', status: 'DRAFT', partner_venue_legal_documents: document },
      { id: 'venue-2', status: 'DRAFT', partner_venue_legal_documents: null },
    ], { kyc_status: 'APPROVED', pan_document_url: '/business-pan.pdf', gst_document_url: '/business-gst.pdf' });
    const result = await service.getPartnerAuthProfile(partner as any);
    expect(result.partner.isVerified).toBe(true);
    expect(result.partner.panCardUrl).toBe('/business-pan.pdf');
    expect(result.partner.legalDocuments[1]).toMatchObject({ venueId: 'venue-2', aadhaarCardUrl: null });
  });
});
