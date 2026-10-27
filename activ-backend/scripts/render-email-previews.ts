import * as fs from 'fs';
import * as path from 'path';
import { EMAIL_TEMPLATES, EmailData, EmailTemplateId, escapeHtml, renderPartnerEmail } from '../src/modules/mail/templates/partner-email';

// Static, fictitious review fixtures. This script never opens a mail transport or database.
const output = path.resolve(__dirname, '../email-previews');
fs.mkdirSync(path.join(output, 'assets'), { recursive: true });
fs.copyFileSync(path.resolve(__dirname, '../src/modules/mail/templates/assets/activ-partner-logo.png'), path.join(output, 'assets/activ-partner-logo.png'));
const common: EmailData = { partnerName: 'Seemant', venueName: 'Sports Arena Complex' };
const fixtures: Partial<Record<EmailTemplateId, EmailData>> = {
  agreement_signed: { signedAt: '27 October 2026, 10:30 AM IST' },
  venue_changes_requested: { reason: 'Please upload a clear image of the venue entrance and confirm your operating hours.' },
  venue_rejected: { reason: 'The venue address could not be verified. Please correct the address and supporting documents.' },
  venue_suspended: { reason: 'Please contact support to resolve the pending venue verification.' },
  partner_suspended: { reason: 'Please contact support to complete account verification.' },
  venue_update_rejected: { reason: 'Please provide a clear supporting document for the requested address change.' },
  activity_rejected: { reason: 'Please add clear court photographs and complete the safety information.' },
  bank_rejected: { reason: 'The account holder name does not match the supporting document.' },
  password_reset: { code: '123456' },
  team_invitation: { email: 'teammate@example.com', role: 'Venue Manager', password: 'Example-only-Change-Me' },
};
const ids = Object.keys(EMAIL_TEMPLATES) as EmailTemplateId[];
for (const id of ids) {
  const data: EmailData = { ...common, ...fixtures[id] };
  if (id.startsWith('activity_')) data.activityName = 'Cricket Turf';
  if (id.startsWith('bank_')) Object.assign(data, { bankName: 'Example Bank', accountLast4: '4321' });
  if (id.startsWith('support_')) Object.assign(data, { subject: 'Help updating my venue details', reference: 'SUP-EXAMPLE-001' });
  if (id.startsWith('callback_')) Object.assign(data, { callbackDate: '28 October 2026', callbackTime: '10:00 AM - 11:00 AM', reference: 'CALL-EXAMPLE-001' });
  const rendered = renderPartnerEmail(id, data);
  fs.writeFileSync(path.join(output, `${id}.html`), rendered.html.replace('cid:activ-partner-logo', 'assets/activ-partner-logo.png'));
  fs.writeFileSync(path.join(output, `${id}.txt`), `Subject: ${rendered.subject}\n\n${rendered.text}\n`);
}
fs.writeFileSync(path.join(output, 'index.html'), `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>ACTIV Partner email templates</title><style>body{margin:0;font-family:Arial,sans-serif;background:#f3f7fa;color:#17231d}header,main{max-width:1100px;margin:auto;padding:28px}h1{font-size:28px}p{line-height:1.6}section{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:16px}a.card{display:block;background:white;border:1px solid #e0e8e3;border-radius:12px;padding:20px;color:inherit;text-decoration:none}a.card:hover{border-color:#13c83f}small{display:block;color:#65716b;margin-top:10px}strong{line-height:1.5}.note{background:#fff0c9;padding:12px;border-radius:8px}</style></head><body><header><img src="assets/activ-partner-logo.png" width="136" alt="ACTIV Partner"><h1>Partner email templates</h1><p>${ids.length} responsive HTML emails with plain-text alternatives. Open any template to review its complete layout.</p><p class="note">Preview data is fictitious. Store and social buttons currently open the project link. No emails are sent by this gallery.</p></header><main><section>${ids.map(id => `<a class="card" href="${id}.html"><strong>${escapeHtml(EMAIL_TEMPLATES[id].subject)}</strong><small>${id.replace(/_/g, ' ')}</small></a>`).join('')}</section></main></body></html>`);
console.log(`Generated ${ids.length} HTML/text email previews in ${output}`);
