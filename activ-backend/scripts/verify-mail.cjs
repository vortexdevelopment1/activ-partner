// Checks SMTP connectivity and authentication without sending an email.
require('dotenv').config({ quiet: true });
const nodemailer = require('nodemailer');

const port = Number(process.env.MAIL_PORT || 587);
const transport = nodemailer.createTransport({
  host: process.env.MAIL_HOST || 'smtp.gmail.com',
  port,
  secure: port === 465,
  connectionTimeout: 10000,
  greetingTimeout: 10000,
  socketTimeout: 10000,
  auth: { user: process.env.MAIL_USER, pass: process.env.MAIL_PASS },
});

transport.verify()
  .then(() => console.log('SMTP connection and authentication succeeded. No email was sent.'))
  .catch((error) => {
    console.error(`SMTP verification failed: code=${error.code || 'UNKNOWN'} status=${error.responseCode || 'unknown'}`);
    if (error.code === 'EAUTH') {
      console.error('Update MAIL_USER and MAIL_PASS in the backend .env with valid SMTP credentials. For Gmail, use an app password. The account must also be authorized to send as support@activ.live.');
    }
    process.exitCode = 1;
  })
  .finally(() => transport.close());
