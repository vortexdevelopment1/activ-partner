const fs = require('fs');
const path = require('path');

const out = path.resolve(__dirname, '..', 'docs', 'ACTIV Partner Client Handover.docx');
fs.mkdirSync(path.dirname(out), { recursive: true });

const esc = (value) => String(value)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;');
const text = (value, bold = false, color = '1F2937', size = 21) =>
  `<w:r><w:rPr>${bold ? '<w:b/>' : ''}<w:color w:val="${color}"/><w:sz w:val="${size}"/><w:szCs w:val="${size}"/><w:rFonts w:ascii="Aptos" w:hAnsi="Aptos"/></w:rPr><w:t xml:space="preserve">${esc(value)}</w:t></w:r>`;
const para = (value = '', options = {}) => {
  const { style, bold, color, size, align, after = 120, before = 0, pageBreak = false } = options;
  return `<w:p><w:pPr>${style ? `<w:pStyle w:val="${style}"/>` : ''}${align ? `<w:jc w:val="${align}"/>` : ''}<w:spacing w:after="${after}" w:before="${before}"/>${pageBreak ? '<w:pageBreakBefore/>' : ''}</w:pPr>${text(value, bold, color, size)}</w:p>`;
};
const bullet = (value) => `<w:p><w:pPr><w:pStyle w:val="ListBullet"/><w:spacing w:after="60"/></w:pPr>${text(value, false, '1F2937', 20)}</w:p>`;
const cell = (value, width, header = false) => `<w:tc><w:tcPr><w:tcW w:w="${width}" w:type="dxa"/><w:shd w:fill="${header ? '1F4D3A' : 'FFFFFF'}"/><w:tcMar><w:top w:w="90" w:type="dxa"/><w:left w:w="110" w:type="dxa"/><w:bottom w:w="90" w:type="dxa"/><w:right w:w="110" w:type="dxa"/></w:tcMar></w:tcPr><w:p><w:pPr><w:spacing w:after="0"/></w:pPr>${text(value, header, header ? 'FFFFFF' : '1F2937', header ? 19 : 18)}</w:p></w:tc>`;
const table = (headers, rows, widths) => `<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblBorders><w:top w:val="single" w:sz="4" w:color="D9D9D9"/><w:left w:val="single" w:sz="4" w:color="D9D9D9"/><w:bottom w:val="single" w:sz="4" w:color="D9D9D9"/><w:right w:val="single" w:sz="4" w:color="D9D9D9"/><w:insideH w:val="single" w:sz="4" w:color="D9D9D9"/><w:insideV w:val="single" w:sz="4" w:color="D9D9D9"/></w:tblBorders></w:tblPr><w:tblGrid>${widths.map(w => `<w:gridCol w:w="${w}"/>`).join('')}</w:tblGrid><w:tr>${headers.map((h, i) => cell(h, widths[i], true)).join('')}</w:tr>${rows.map(row => `<w:tr>${row.map((v, i) => cell(v, widths[i])).join('')}</w:tr>`).join('')}</w:tbl>`;

const services = table(
  ['Area', 'Service', 'Purpose and client action'],
  [
    ['Partner application', 'Flutter mobile and web app on Vercel', 'Partners onboard venues, add activities, upload documents and images, manage availability, and view bookings. Current web address: activ-partner.vercel.app. Rebuild and distribute a new app version after app-side changes.'],
    ['Admin portal', 'Vite web application on Vercel', 'Admin users manage venues, partners, approvals, categories, commissions, and support. Vercel environment settings contain the public API URL and a redeploy is needed after changing it.'],
    ['Backend API', 'NestJS service on Render', 'Handles authentication, business rules, bookings, partner onboarding, activity review, notifications, uploads, and integrations. Deploy backend changes before running app builds that depend on them.'],
    ['Database', 'Supabase PostgreSQL with Prisma', 'Stores users, partners, venues, activities, bookings, bank information, activity questions, and answers. Apply Prisma migrations before deploying code that needs a changed schema.'],
    ['File storage', 'Cloudinary', 'Stores venue images and activity documents. The client should keep the Cloudinary account, folder policy, and billing active.'],
    ['Payments', 'Razorpay', 'Processes online payments. The client owns the Razorpay account, settlement settings, webhooks, and live credentials.'],
    ['Maps and places', 'Google Maps Platform', 'Provides address search, place details, and geocoding. The client maintains billing, API enablement, and key restrictions.'],
    ['Notifications', 'OneSignal and email delivery', 'Sends push notifications and transactional emails. The client maintains app credentials, sender identity, templates, and delivery monitoring.'],
  ], [1500, 1750, 4200]);

const responsibilities = table(
  ['Client responsibility', 'What to maintain'],
  [
    ['Accounts and billing', 'Keep Render, Vercel, Supabase, Cloudinary, Razorpay, Google Cloud, OneSignal, and email-provider accounts active and billed.'],
    ['Security', 'Store secrets only in deployment environment variables. Rotate credentials immediately if they are exposed. Do not place private keys or database passwords in frontend builds.'],
    ['Content and operations', 'Maintain partner data, activity categories, approval decisions, commission rules, FAQs, legal text, and support responses through the admin portal.'],
    ['Release approval', 'Test staging changes, approve production releases, and confirm payment, notification, document-upload, and booking flows after each important deployment.'],
    ['Backups and access', 'Maintain named administrator access, enable database backups, and document who can access each external service.'],
  ], [1900, 5550]);

const body = [
  para('ACTIV Partner Project Guide', { style: 'Title', bold: true, color: '000000', size: 36, after: 80 }),
  para('Client handover and service overview', { bold: false, color: '4B5563', size: 22, after: 280 }),
  para('Purpose', { style: 'Heading1', bold: true, color: '000000', size: 26, before: 80 }),
  para('This guide explains what the ACTIV Partner project does, where each part is deployed, which outside services it uses, and what the client should maintain after handover. It is written for operational and business owners. It intentionally excludes passwords, API keys, database connection strings, and other secrets.', { size: 21, after: 180 }),
  para('Project at a glance', { style: 'Heading1', bold: true, color: '000000', size: 26, before: 100 }),
  bullet('Partner experience: venue onboarding, activity setup, photo and document upload, bank details, availability, bookings, and account management.'),
  bullet('Admin experience: venue and partner review, approvals, users, categories, commissions, legal records, bank-account review, and support.'),
  bullet('Activity details: activity-specific questions are held in the database through Prisma and seeded from the approved activity catalogue.'),
  para('System architecture', { style: 'Heading1', bold: true, color: '000000', size: 26, before: 150 }),
  para('The partner application and admin portal call the same backend API. The backend stores core data in Supabase PostgreSQL and uses external providers for files, payments, maps, notifications, and email. The client should treat the backend deployment and database migration process as the source of truth for operational changes.', { size: 21, after: 180 }),
  para('Services and deployments', { style: 'Heading1', bold: true, color: '000000', size: 26, before: 120 }),
  services,
  para('', { after: 100 }),
  para('Client responsibilities', { style: 'Heading1', bold: true, color: '000000', size: 26, before: 180, pageBreak: true }),
  responsibilities,
  para('', { after: 100 }),
  para('Deployment and change process', { style: 'Heading1', bold: true, color: '000000', size: 26, before: 170 }),
  para('1. Test changes in a staging environment.  2. Back up or verify the database before a schema change.  3. Deploy the backend.  4. Apply Prisma migrations.  5. Run required data seeds.  6. Deploy the admin portal or release a new partner app build.  7. Perform a short production check with a test account.', { size: 21, after: 130 }),
  para('For the activity-details catalogue, the current release process is: deploy the backend code, run the Prisma migration, run the activity field seed, then restart the backend. The mobile and web UI retrieves the field definitions from the API.', { size: 21, after: 150 }),
  para('What the client should not change directly', { style: 'Heading1', bold: true, color: '000000', size: 26, before: 120 }),
  bullet('Do not edit production database rows manually unless a qualified technical owner has reviewed the change.'),
  bullet('Do not delete Cloudinary assets, Razorpay records, or Supabase data as a way to fix a screen issue.'),
  bullet('Do not expose deployment environment variables in frontend code, screenshots, spreadsheets, or chat messages.'),
  para('Client handover checklist', { style: 'Heading1', bold: true, color: '000000', size: 26, before: 120 }),
  bullet('Client has owner access to every external service and billing account.'),
  bullet('Production and staging URLs are recorded internally.'),
  bullet('At least two named people can approve releases and access backups.'),
  bullet('A test partner account and test booking flow have been checked after the latest release.'),
  para('Support information', { style: 'Heading1', bold: true, color: '000000', size: 26, before: 120 }),
  para('When reporting an issue, include the user role, screen name, approximate time, device or browser, action taken, and a screenshot with personal or financial information hidden. For payment or notification issues, also include the related booking or activity reference.', { size: 21, after: 80 }),
];

const documentXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>${body.join('')}<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1100" w:right="1050" w:bottom="1050" w:left="1050" w:header="600" w:footer="600" w:gutter="0"/></w:sectPr></w:body></w:document>`;
const stylesXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Aptos" w:hAnsi="Aptos"/><w:sz w:val="21"/></w:rPr></w:rPrDefault></w:docDefaults><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style><w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/></w:style><w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/></w:style><w:style w:type="paragraph" w:styleId="ListBullet"><w:name w:val="List Bullet"/><w:pPr><w:ind w:left="360" w:hanging="180"/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr></w:style></w:styles>`;
const numberingXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:abstractNum w:abstractNumId="0"><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:lvlJc w:val="left"/></w:lvl></w:abstractNum><w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num></w:numbering>`;
const contentTypes = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/></Types>`;
const rels = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>`;
const docRels = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/></Relationships>`;

let crcTable;
const crc32 = (buffer) => { if (!crcTable) { crcTable = Array.from({ length: 256 }, (_, n) => { let c = n; for (let i = 0; i < 8; i++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; }); } let c = 0xffffffff; for (const byte of buffer) c = crcTable[(c ^ byte) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const u16 = (n) => { const b = Buffer.alloc(2); b.writeUInt16LE(n); return b; };
const u32 = (n) => { const b = Buffer.alloc(4); b.writeUInt32LE(n >>> 0); return b; };
const entries = Object.entries({ '[Content_Types].xml': contentTypes, '_rels/.rels': rels, 'word/document.xml': documentXml, 'word/styles.xml': stylesXml, 'word/numbering.xml': numberingXml, 'word/_rels/document.xml.rels': docRels }).map(([name, value]) => ({ name, data: Buffer.from(value) }));
let offset = 0; const locals = []; const central = [];
for (const entry of entries) { const name = Buffer.from(entry.name); const crc = crc32(entry.data); const local = Buffer.concat([Buffer.from([0x50,0x4b,0x03,0x04,20,0,0,0,0,0,0,0,0,0]), u32(crc), u32(entry.data.length), u32(entry.data.length), u16(name.length), u16(0), name, entry.data]); locals.push(local); central.push(Buffer.concat([Buffer.from([0x50,0x4b,0x01,0x02,20,0,20,0,0,0,0,0,0,0,0,0]),u32(crc),u32(entry.data.length),u32(entry.data.length),u16(name.length),u16(0),u16(0),u16(0),u16(0),u32(0),u32(offset),name])); offset += local.length; }
const centralBuffer = Buffer.concat(central); const end = Buffer.concat([Buffer.from([0x50,0x4b,0x05,0x06,0,0,0,0]),u16(entries.length),u16(entries.length),u32(centralBuffer.length),u32(offset),u16(0)]);
fs.writeFileSync(out, Buffer.concat([...locals, centralBuffer, end]));
console.log(out);
