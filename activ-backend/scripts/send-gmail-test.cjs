// Sends one explicitly approved Gmail API test message with a sample PDF.
// Usage: node scripts/send-gmail-test.cjs --confirm
// Safe validation: node scripts/send-gmail-test.cjs --confirm --dry-run
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
require('dotenv').config({
  path: path.resolve(__dirname, '..', '.env'),
  quiet: true,
});
const { google } = require('googleapis');

if (!process.argv.includes('--confirm')) {
  throw new Error('Refusing to send. Add --confirm for the configured test recipient.');
}
const recipient = process.env.GOOGLE_TEST_RECIPIENT;
const sender = process.env.GOOGLE_SENDER_EMAIL;
const storageKey = process.env.GOOGLE_REFRESH_TOKEN_STORAGE_KEY?.trim();
const tokenFile = process.env.GOOGLE_REFRESH_TOKEN_FILE || './.secrets/google-refresh-token.enc';

function readEncryptedRefreshToken() {
  if (!storageKey || storageKey.length < 32) {
    throw new Error('GOOGLE_REFRESH_TOKEN_STORAGE_KEY must contain at least 32 characters.');
  }
  const key = crypto.createHash('sha256').update(storageKey).digest();
  const record = JSON.parse(fs.readFileSync(path.resolve(__dirname, '..', tokenFile), 'utf8'));
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, Buffer.from(record.iv, 'base64'));
  decipher.setAuthTag(Buffer.from(record.tag, 'base64'));
  return Buffer.concat([
    decipher.update(Buffer.from(record.value, 'base64')),
    decipher.final(),
  ]).toString('utf8');
}

const refreshToken = process.env.GOOGLE_REFRESH_TOKEN?.trim() || readEncryptedRefreshToken();
if (!recipient || !sender || !refreshToken) {
  throw new Error('Set GOOGLE_TEST_RECIPIENT and GOOGLE_SENDER_EMAIL, and configure a refresh token or encrypted token storage.');
}
if (process.argv.includes('--dry-run')) {
  console.log('Gmail test configuration is valid and the encrypted refresh token was decrypted successfully. No email was sent.');
  process.exit(0);
}

const auth = new google.auth.OAuth2(
  process.env.GOOGLE_CLIENT_ID,
  process.env.GOOGLE_CLIENT_SECRET,
  process.env.GOOGLE_REDIRECT_URI,
);
auth.setCredentials({ refresh_token: refreshToken });
const gmail = google.gmail({ version: 'v1', auth });
const boundary = `activ-test-${crypto.randomBytes(8).toString('hex')}`;
const pdf = Buffer.from('%PDF-1.4\n% ACTIV Gmail OAuth test\n', 'utf8');
const message = [
  `From: ACTIV Partner Support <${sender}>`,
  `To: ${recipient}`,
  'Subject: ACTIV Gmail API test',
  'MIME-Version: 1.0',
  `Content-Type: multipart/mixed; boundary="${boundary}"`, '',
  `--${boundary}`, 'Content-Type: text/plain; charset="UTF-8"', '',
  'This confirms Gmail API acceptance. Inbox delivery is not guaranteed by provider acceptance.',
  `--${boundary}`, 'Content-Type: application/pdf',
  'Content-Transfer-Encoding: base64',
  'Content-Disposition: attachment; filename="activ-gmail-test.pdf"', '',
  pdf.toString('base64'), `--${boundary}--`, '',
].join('\r\n');

gmail.users.messages.send({
  userId: 'me',
  requestBody: { raw: Buffer.from(message).toString('base64url') },
}).then((result) => {
  console.log(`Gmail accepted the test message. Message ID: ${result.data.id || 'unknown'}`);
}).catch((error) => {
  console.error(`Gmail test failed: code=${error.code || 'UNKNOWN'} status=${error.response?.status || 'unknown'}`);
  process.exitCode = 1;
});
