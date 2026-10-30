// Offline preview using the real generator and synthetic details. No Nest app,
// database, email, or SMS services are initialized.
require('ts-node/register/transpile-only');
const fs = require('fs');
const path = require('path');
const { VenuesService } = require('../src/modules/venues/venues.service');

(async () => {
  const venue = {
    id: 'layout-preview', partnerId: 'preview-partner',
    name: 'ACTIV Community Sports and Recreation Centre - Indoor Courts, Fitness Studios and Coaching Academy',
    partner: { firstName: 'Sample', lastName: 'Partner',
      email: 'sample.partner.with.a.very.long.registered.email.address.for.layout.review@example.com', phone: '+919876543210' },
    electronicSignature: 'Sample Partner - Authorized Representative',
    termsAcceptedAt: new Date('2026-10-30T10:00:00Z'),
  };
  const context = { findOne: async () => venue };
  const result = await VenuesService.prototype.generatePartnerAgreementPdf.call(
    context, venue.id, { id: 'preview-partner', role: 'partner' },
  );
  const output = path.resolve(__dirname, '../../output/pdf/agreement-layout-preview.pdf');
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, Buffer.from(result.base64, 'base64'));
  console.log(output);
})().catch(error => { console.error(error); process.exitCode = 1; });
