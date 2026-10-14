const assert = require('node:assert/strict');
const { config } = require('dotenv');

const env = { ...process.env, ...config({ path: '.env', quiet: true }).parsed,
  ...config({ path: '.env.local', quiet: true }).parsed };
const base = 'http://localhost:3000/api/v1';
const faqs = [
  {
    question: 'Is there a fee to use the app?',
    answer: 'Listing your venue on ACTIV is free. We charge a small commission per confirmed booking. You can view the applicable commission rates for your city in the app.',
  },
  {
    question: 'What can I do with ACTIV user app?',
    answer: 'With the ACTIV partner app, you can manage your venue listing, track bookings, update availability slots, handle team members, and view payout history - all from one place.',
  },
  {
    question: 'When will the ACTIV app be available ?',
    answer: "The ACTIV user app is currently in development. We're working hard to bring it to you soon. Stay tuned for our official launch announcement.",
  },
];

async function request(path, method = 'GET', body, token) {
  const response = await fetch(`${base}${path}`, {
    method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}), signal: AbortSignal.timeout(30000),
  });
  const result = await response.json();
  if (!response.ok) throw new Error(`${method} ${path} failed (${response.status}): ${result.message}`);
  return result.data;
}

const normalize = (question) => question.trim().toLowerCase().replace(/\s+\?/g, '?');

(async () => {
  if (!env.ADMIN_EMAIL || !env.ADMIN_PASSWORD) throw new Error('Configured admin credentials are required');
  const login = await request('/auth/login', 'POST', { email: env.ADMIN_EMAIL, password: env.ADMIN_PASSWORD });
  const token = login.accessToken;
  assert(token, 'Admin login did not return an access token');
  const existing = [];
  for (let page = 1, totalPages = 1; page <= totalPages; page++) {
    const result = await request(`/faqs?page=${page}&limit=100`, 'GET', undefined, token);
    existing.push(...result.items);
    totalPages = result.totalPages;
  }
  for (const [order, faq] of faqs.entries()) {
    const match = existing.find((item) => normalize(item.question) === normalize(faq.question));
    const saved = await request(match ? `/faqs/${match.id}` : '/faqs', match ? 'PATCH' : 'POST',
      { ...faq, order, isActive: true }, token);
    console.log(`${match ? 'Updated' : 'Created'} active FAQ: ${saved.question}`);
  }
  const published = await request('/faqs/public');
  for (const faq of faqs) {
    assert(published.some((item) => item.question === faq.question && item.answer === faq.answer && item.isActive),
      `FAQ not visible in the public app endpoint: ${faq.question}`);
  }
  console.log('All three FAQs verified in the public app endpoint.');
})().catch((error) => { console.error(error.message); process.exitCode = 1; });
