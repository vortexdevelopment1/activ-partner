export type EmailData = {
  /** Stable business-event identity; never rendered in the email. */
  deliveryKey?: string;
  partnerName?: string; venueName?: string; activityName?: string; reason?: string;
  reference?: string; bankName?: string; accountLast4?: string; subject?: string;
  signedAt?: string; callbackDate?: string; callbackTime?: string;
  code?: string; password?: string; role?: string; email?: string; message?: string;
};
type Definition = {
  subject: string; heading: string; highlight: string; status: string;
  tone: 'green' | 'amber' | 'red' | 'purple'; paragraphs: string[];
};

export const EMAIL_TEMPLATES = {
  venue_under_review: {
    subject: 'Your ACTIV Venue Application Is Under Review', heading: 'Your Venue Application', highlight: 'Is Under Review', status: 'Under review', tone: 'amber',
    paragraphs: ["Thank you for registering your venue with ACTIV. We’ve received your submission, and our team is currently reviewing your details and documents.", "We’ll email you as soon as there’s an update. If any additional information is required, our team will contact you using the details provided during registration."],
  },
  agreement_signed: {
    subject: 'Your Signed Partnership Agreement – ACTIV Partner', heading: 'Your Partnership Agreement', highlight: 'Has Been Signed', status: 'Signed', tone: 'green',
    paragraphs: ['Thank you for completing your registration with ACTIV Partner. Your Partnership Agreement has been successfully signed.', 'Please find a copy of your signed Partnership Agreement attached for your records. Our team will review your venue registration and notify you of the next steps.'],
  },
  venue_approved: {
    subject: 'Your Venue Has Been Approved – ACTIV Partner', heading: 'Your Venue', highlight: 'Has Been Approved', status: 'Approved', tone: 'green',
    paragraphs: ['Your venue application has been approved. Welcome to the ACTIV partner community!', 'Open ACTIV Partner to review your activities, availability and booking settings. Activities become bookable once their required approvals are complete.'],
  },
  venue_rejected: {
    subject: 'An Update on Your Venue Application – ACTIV Partner', heading: 'Your Venue Application', highlight: 'Was Not Approved', status: 'Rejected', tone: 'red',
    paragraphs: ['Our team has reviewed your venue application. We’re unable to approve it at this time.', 'Review the reason below, update the relevant details in ACTIV Partner, and submit your application again when ready.'],
  },
  venue_changes_requested: {
    subject: 'Changes Needed for Your Venue Application – ACTIV Partner', heading: 'Your Venue Application', highlight: 'Needs a Few Changes', status: 'Changes requested', tone: 'amber',
    paragraphs: ['We’ve reviewed your venue application and need some additional information or corrections before we can continue.', 'Sign in with your phone OTP, update your venue details and submit again for review. The requested changes are listed below.'],
  },
  venue_suspended: {
    subject: 'Your ACTIV Venue Has Been Suspended', heading: 'Your Venue', highlight: 'Has Been Suspended', status: 'Suspended', tone: 'red',
    paragraphs: ['Your venue has been suspended and is no longer available for new bookings on ACTIV.', 'Review the reason below and contact our support team for clarification and assistance with reactivation. Existing bookings should still be managed with the support team.'],
  },
  partner_suspended: {
    subject: 'Your ACTIV Partner Account Has Been Suspended', heading: 'Your Partner Account', highlight: 'Has Been Suspended', status: 'Suspended', tone: 'red',
    paragraphs: ['Access to your ACTIV Partner account has been disabled.', 'Review the reason below and contact our support team for clarification and assistance with reactivation.'],
  },
  venue_deleted: {
    subject: 'Your Venue Has Been Removed – ACTIV Partner', heading: 'Your Venue', highlight: 'Has Been Removed', status: 'Removed', tone: 'red',
    paragraphs: ['Your venue has been removed from ACTIV and is no longer available for new bookings.', 'If you did not request this change or need assistance with any existing bookings, please contact our support team.'],
  },
  venue_update_submitted: {
    subject: 'Your Venue Changes Are Under Review – ACTIV Partner', heading: 'Your Venue Changes', highlight: 'Are Under Review', status: 'Under review', tone: 'amber',
    paragraphs: ['We’ve received your request to update your venue details.', 'Our team will review your submission and email you with a decision. Your existing published details remain in place until the changes are approved.'],
  },
  venue_update_approved: {
    subject: 'Your Venue Changes Have Been Approved – ACTIV Partner', heading: 'Your Venue Changes', highlight: 'Have Been Approved', status: 'Approved', tone: 'green',
    paragraphs: ['Your requested venue updates have been approved and applied.', 'Open ACTIV Partner to review your updated venue information.'],
  },
  venue_update_rejected: {
    subject: 'An Update on Your Venue Change Request – ACTIV Partner', heading: 'Your Venue Changes', highlight: 'Were Not Approved', status: 'Rejected', tone: 'red',
    paragraphs: ['We’ve reviewed your venue change request and cannot approve it as submitted.', 'Your existing published details remain unchanged. Review the reason below, correct your request and submit it again.'],
  },
  activity_submitted: {
    subject: 'Your Activity Is Under Review – ACTIV Partner', heading: 'Your New Activity', highlight: 'Is Under Review', status: 'Under review', tone: 'amber',
    paragraphs: ['We’ve received your activity submission and our team is reviewing its details.', 'This activity is not live yet. We’ll email you when a decision is available. Your other approved activities are not affected.'],
  },
  activity_approved: {
    subject: 'Your Activity Has Been Approved – ACTIV Partner', heading: 'Your Activity', highlight: 'Has Been Approved', status: 'Approved', tone: 'green',
    paragraphs: ['Your activity has been approved by ACTIV.', 'Open Activity Management to check its availability, pricing and booking controls before accepting bookings.'],
  },
  activity_rejected: {
    subject: 'An Update on Your Activity Submission – ACTIV Partner', heading: 'Your Activity', highlight: 'Was Not Approved', status: 'Rejected', tone: 'red',
    paragraphs: ['We’ve reviewed your activity submission and cannot approve it at this time.', 'Review the reason below, update the activity details and submit it again for review.'],
  },
  bank_submitted: {
    subject: 'Your Bank Details Are Under Review – ACTIV Partner', heading: 'Your Bank Details', highlight: 'Are Under Review', status: 'Under review', tone: 'amber',
    paragraphs: ['We’ve received your bank account details and supporting document.', 'Our team will verify your submission and email you when the review is complete.'],
  },
  bank_approved: {
    subject: 'Your Bank Account Has Been Approved – ACTIV Partner', heading: 'Your Bank Account', highlight: 'Has Been Verified', status: 'Approved', tone: 'green',
    paragraphs: ['Your submitted bank account details have been approved.', 'You can review your verified bank details and payout information in ACTIV Partner.'],
  },
  bank_rejected: {
    subject: 'Your Bank Details Need Attention – ACTIV Partner', heading: 'Your Bank Account', highlight: 'Was Not Approved', status: 'Rejected', tone: 'red',
    paragraphs: ['We couldn’t verify the bank account details you submitted.', 'Review the reason below and update your bank details and supporting document before submitting again.'],
  },
  support_received: {
    subject: 'We’ve Received Your Support Request – ACTIV Partner', heading: 'Your Support Request', highlight: 'Has Been Received', status: 'Received', tone: 'amber',
    paragraphs: ['Thank you for reaching out to ACTIV. Your support request has been saved and sent to our team.', 'Our team will review your request and contact you with an update.'],
  },
  support_in_progress: {
    subject: 'Your Support Request Is In Progress – ACTIV Partner', heading: 'Your Support Request', highlight: 'Is In Progress', status: 'In progress', tone: 'purple',
    paragraphs: ['Our support team is now working on your request.', 'We’ll contact you if we need more information and let you know when the request is resolved.'],
  },
  support_resolved: {
    subject: 'Your Support Request Has Been Resolved – ACTIV Partner', heading: 'Your Support Request', highlight: 'Has Been Resolved', status: 'Resolved', tone: 'green',
    paragraphs: ['Our support team has marked your request as resolved.', 'If you still need help with this issue, contact our support team and quote the request reference below.'],
  },
  support_cancelled: {
    subject: 'Your Support Request Has Been Cancelled – ACTIV Partner', heading: 'Your Support Request', highlight: 'Has Been Cancelled', status: 'Cancelled', tone: 'red',
    paragraphs: ['Your support request has been cancelled.', 'If you still need assistance, you can submit a new request through ACTIV Partner or contact our support team.'],
  },
  callback_received: {
    subject: 'We’ll Call You Soon – ACTIV Partner', heading: 'Your Callback Request', highlight: 'Has Been Received', status: 'Received', tone: 'amber',
    paragraphs: ['Thank you for your request. A member of our team will call you during your chosen time slot.', 'You can find your requested callback date and time below.'],
  },
  callback_in_progress: {
    subject: 'Your Callback Request Is In Progress – ACTIV Partner', heading: 'Your Callback Request', highlight: 'Is In Progress', status: 'In progress', tone: 'purple',
    paragraphs: ['Our team is working on your callback request and will contact you using the details you provided.'],
  },
  callback_resolved: {
    subject: 'Your Callback Request Has Been Resolved – ACTIV Partner', heading: 'Your Callback Request', highlight: 'Has Been Resolved', status: 'Resolved', tone: 'green',
    paragraphs: ['Our team has marked your callback request as resolved. If you need further help, please contact support.'],
  },
  callback_cancelled: {
    subject: 'Your Callback Request Has Been Cancelled – ACTIV Partner', heading: 'Your Callback Request', highlight: 'Has Been Cancelled', status: 'Cancelled', tone: 'red',
    paragraphs: ['Your callback request has been cancelled. You can request another callback through ACTIV Partner when convenient.'],
  },
  password_reset: {
    subject: 'Reset Your ACTIV Partner Password', heading: 'Your Password Reset', highlight: 'Verification Code', status: 'Action required', tone: 'purple',
    paragraphs: ['Use the verification code below to continue resetting your password. Never share this code with anyone.', 'If you didn’t request a password reset, you can ignore this email. Your password has not been changed.'],
  },
  team_invitation: {
    subject: 'You’re Invited to ACTIV Partner', heading: 'You’ve Been Invited', highlight: 'To Your Venue Team', status: 'Invited', tone: 'green',
    paragraphs: ['Your venue administrator has created an ACTIV Partner team account for you.', 'Use the account details below to sign in. If a temporary password is provided, change it after your first login.'],
  },
} satisfies Record<string, Definition>;

export type EmailTemplateId = keyof typeof EMAIL_TEMPLATES;
export type EmailBrand = {
  projectUrl?: string; websiteUrl?: string; supportEmail?: string; logoUrl?: string;
  appStoreUrl?: string; playStoreUrl?: string;
  instagramUrl?: string; linkedinUrl?: string; youtubeUrl?: string; xUrl?: string;
};

export const escapeHtml = (value: unknown) => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]!);
const safeUrl = (value: string | undefined, fallback: string) => {
  try { const url = new URL(value || fallback); return url.protocol === 'https:' ? url.toString() : fallback; } catch { return fallback; }
};

export function renderPartnerEmail(id: EmailTemplateId, data: EmailData = {}, brand: EmailBrand = {}) {
  const template: Definition = EMAIL_TEMPLATES[id];
  const project = safeUrl(brand.projectUrl, 'https://activ-partner.vercel.app/');
  const website = safeUrl(brand.websiteUrl, 'https://activ.live/');
  const support = /^\S+@\S+\.\S+$/.test(brand.supportEmail ?? '') ? brand.supportEmail! : 'support@activ.live';
  const color = { green: '#13c83f', amber: '#b67813', red: '#df4747', purple: '#9e35e9' }[template.tone];
  const badgeBackground = { green: '#e4faeb', amber: '#fff0c9', red: '#ffe8e8', purple: '#f1e6ff' }[template.tone];
  const rows: [string, string | undefined][] = [
    ['Venue', data.venueName], ['Activity', data.activityName],
    ['Application Status', template.status], ['Reference', data.reference],
    ['Bank', data.bankName], ['Account', data.accountLast4 ? `Ending in ${data.accountLast4.replace(/\D/g, '').slice(-4)}` : undefined],
    ['Signed On', data.signedAt], ['Callback Date', data.callbackDate], ['Callback Time', data.callbackTime],
    ['Subject', data.subject], ['Role', data.role], ['Email', data.email],
    ['Verification Code', data.code], ['Temporary Password', data.password],
  ];
  const paragraph = (text: string) => `<p style="margin:0 0 14px;font-size:14px;line-height:1.6;color:#30363b;">${escapeHtml(text).replace(/\n/g, '<br>')}</p>`;
  const detailRows = rows.filter(([, value]) => value).map(([label, value]) => `<tr><td width="35%" style="padding:12px 14px;border-bottom:1px solid #e6e9e7;font-size:12px;color:#424b48;vertical-align:top;">${escapeHtml(label)}</td><td style="padding:12px 14px;border-bottom:1px solid #e6e9e7;font-size:13px;font-weight:600;color:#17231d;word-break:break-word;">${label === 'Application Status' ? `<span style="display:inline-block;padding:4px 12px;border-radius:20px;background:${badgeBackground};color:${color};font-size:12px;">${escapeHtml(value)}</span>` : escapeHtml(value)}</td></tr>`).join('');
  const store = (name: string, subtitle: string, url?: string) => `<a href="${escapeHtml(safeUrl(url, project))}" style="display:inline-block;background:#080c0a;border-radius:5px;color:#fff;text-decoration:none;padding:6px 10px;margin:5px 5px 0 0;line-height:1.15;"><span style="font-size:8px;">${subtitle}</span><br><span style="font-size:15px;font-weight:600;">${name}</span></a>`;
  const social = [['Instagram', 'IG', brand.instagramUrl, '#d84782'], ['LinkedIn', 'in', brand.linkedinUrl, '#087db3'], ['YouTube', '▶', brand.youtubeUrl, '#e82222'], ['X', 'X', brand.xUrl, '#111111']].map(([label, glyph, url, background]) => `<a aria-label="${label}" href="${escapeHtml(safeUrl(url, project))}" style="display:inline-block;margin:8px 5px 0 0;width:25px;height:25px;line-height:25px;text-align:center;border-radius:50%;background:${background};color:#fff;text-decoration:none;font-size:12px;font-weight:700;">${glyph}</a>`).join('');
  const logo = brand.logoUrl?.startsWith('cid:') ? brand.logoUrl : safeUrl(brand.logoUrl, 'cid:activ-partner-logo');
  const html = `<!doctype html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escapeHtml(template.subject)}</title></head><body style="margin:0;padding:0;background:#f3f7fa;font-family:Arial,Helvetica,sans-serif;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">${escapeHtml(template.heading)} ${escapeHtml(template.highlight)}</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f3f7fa;"><tr><td align="center" style="padding:24px 12px;"><table role="presentation" width="600" cellspacing="0" cellpadding="0" style="width:100%;max-width:600px;background:#fff;border:1px solid #edf1f3;"><tr><td style="padding:32px 28px 22px;">
<table role="presentation" width="100%"><tr><td align="center" style="padding:0 0 28px;"><img src="${escapeHtml(logo)}" alt="ACTIV Partner" width="136" style="display:block;width:136px;max-width:100%;height:auto;border:0;"></td></tr></table>
${paragraph(`Hi ${data.partnerName?.trim() || 'Partner'},`)}
<h1 style="font-size:25px;line-height:1.18;margin:0 0 22px;font-weight:700;letter-spacing:-.5px;color:#101714;">${escapeHtml(template.heading)}<br><span style="color:${template.tone === 'amber' ? '#13c83f' : color};">${escapeHtml(template.highlight)}</span></h1>
${template.paragraphs.map(paragraph).join('')}
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:20px 0;background:#f5f7f5;border-radius:8px;overflow:hidden;">${detailRows}</table>
${data.reason ? `<div style="padding:14px 16px;margin-bottom:18px;border-left:3px solid ${color};background:#fafaf8;"><strong style="font-size:13px;">${template.tone === 'red' ? 'Reason / review notes' : 'Requested changes / notes'}</strong>${paragraph(data.reason)}</div>` : ''}
${data.message ? paragraph(data.message) : ''}
${paragraph('Regards,')}<p style="font-size:14px;margin:-10px 0 22px;font-weight:700;color:#17231d;">Team ACTIV</p>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-top:1px solid #e6ebea;padding-top:16px;"><tr><td width="60%" style="vertical-align:top;padding-right:8px;"><p style="font-size:11px;margin:0 0 3px;color:#374740;">Download ACTIV Partner App</p>${store('App Store', 'Download on the', brand.appStoreUrl)}${store('Google Play', 'GET IT ON', brand.playStoreUrl)}</td><td style="vertical-align:top;border-left:1px solid #edf0ee;padding-left:14px;"><p style="font-size:11px;margin:0;color:#374740;">Follow us on</p>${social}</td></tr></table>
<p style="text-align:center;font-size:10px;line-height:1.6;color:#727d76;margin:22px 0 0;">Questions? Contact <a href="mailto:${escapeHtml(support)}" style="color:#467dba;">${escapeHtml(support)}</a> &nbsp; | &nbsp; Official website: <a href="${escapeHtml(website)}" style="color:#467dba;">${escapeHtml(website.replace(/\/$/, ''))}</a></p>
</td></tr></table></td></tr></table></body></html>`;
  const text = [`Hi ${data.partnerName?.trim() || 'Partner'},`, `${template.heading} ${template.highlight}`, ...template.paragraphs,
    ...rows.filter(([, value]) => value).map(([label, value]) => `${label}: ${value}`), data.reason ? `Reason / notes: ${data.reason}` : '', data.message,
    'Regards,\nTeam ACTIV', `Questions? Contact ${support}`, `ACTIV Partner: ${project}`, `Official website: ${website}`].filter(Boolean).join('\n\n');
  return { subject: template.subject, html, text };
}
