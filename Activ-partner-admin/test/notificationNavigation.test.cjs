const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');

const source = fs.readFileSync(path.join(__dirname, '../src/utils/notificationNavigation.ts'), 'utf8');
const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } });
const exportsObject = {};
vm.runInNewContext(compiled.outputText, { exports: exportsObject });
const { notificationDestination, openAdminNotification } = exportsObject;

const notification = (type, data = null, isRead = false) => ({ id: 'notification-1', type, data, isRead });

for (const [type, data, expected] of [
  ['venue_updated', { venueId: 'venue-1' }, '/venues/venue-1'],
  ['venue_bookings_paused', { venueId: 'venue-1' }, '/venues/venue-1'],
  ['venue_bookings_resumed', { venueId: 'venue-1' }, '/venues/venue-1'],
  ['venue_auto_deactivated', { venueId: 'venue-1' }, '/venues/venue-1'],
  ['activity_added', { venueId: 'venue-1', serviceId: 'activity-1' }, '/activity-approvals'],
  ['activity_submitted', { venueId: 'venue-1', serviceId: 'activity-1' }, '/activity-approvals'],
  ['partner_registered', { partnerId: 'partner-1' }, '/partners'],
  ['venue_submitted', { venueId: 'venue-1' }, '/venues/venue-1'],
  ['venue_request_submitted', { venueId: 'venue-1', venueRequestId: 'request-1' }, '/venue-requests/request-1'],
  ['venue_request_submitted', null, '/venue-requests'],
  ['bank_account_submitted', { bankAccountId: 'account-1' }, '/bank-accounts/account-1'],
  ['support_requested', { supportRequestId: 'support-1', partnerId: 'partner-1' }, '/support/requests/support-1'],
  ['support_requested', null, '/support/requests'],
  ['activity_removed', { venueId: 'venue-1', serviceId: 'activity-1' }, '/venues/venue-1'],
  ['partner_profile_updated', { partnerId: 'partner-1', venueId: 'venue-1' }, '/partners'],
  ['venue_updated', { venueId: 'venue-1', venueRequestId: 'request-1' }, '/venue-requests/request-1'],
  ['bank_account_updated', { bankAccountId: 'account-1', venueId: 'venue-1' }, '/bank-accounts/account-1'],
  ['gst_verification_submitted', { gstVerificationId: 'gst-1' }, '/gst-verification/gst-1'],
  ['callback_requested', { callbackId: 'callback-1' }, '/support/callback/callback-1'],
  ['activity_added', null, '/activity-approvals'],
  ['activity_removed', null, '/venues'],
  ['venue_updated', null, '/venues'],
  ['bank_account_updated', null, '/bank-accounts'],
  ['gst_verification_submitted', null, '/gst-verification'],
  ['callback_requested', null, '/support/callback'],
  ['unknown', null, '/dashboard'],
  ['venue_updated', { venueId: {} }, '/venues'],
  ['venue_updated', { venueId: '  ' }, '/venues'],
  ['venue_updated', { venueId: ' id/with?query ' }, '/venues/id%2Fwith%3Fquery'],
]) {
  test(`${type} with ${JSON.stringify(data)} opens ${expected}`, () => {
    assert.equal(notificationDestination(notification(type, data)), expected);
  });
}

test('opens the destination immediately while marking as read is still pending', async () => {
  const calls = [];
  let finishRead;
  const pending = new Promise(resolve => { finishRead = resolve; });
  openAdminNotification(notification('venue_updated', { venueId: 'venue-1' }), {
    navigate: destination => calls.push(destination),
    markRead: id => { calls.push(id); return pending; },
    onRead: () => calls.push('read'),
    onReadError: () => assert.fail('Unexpected read failure'),
  });
  assert.deepEqual(calls, ['/venues/venue-1', 'notification-1']);
  finishRead();
  await pending;
  assert.equal(calls.at(-1), 'read');
});

test('handles read failures without preventing navigation or rejecting the click handler', async () => {
  const calls = [];
  openAdminNotification(notification('activity_added', { venueId: 'venue-1' }), {
    navigate: destination => calls.push(destination),
    markRead: () => Promise.reject(new Error('Network unavailable')),
    onRead: () => assert.fail('Unexpected read success'),
    onReadError: () => calls.push('error'),
  });
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(calls, ['/activity-approvals', 'error']);
});

test('already read notifications navigate without another read request', () => {
  let destination;
  openAdminNotification(notification('venue_updated', { venueId: 'venue-1' }, true), {
    navigate: value => { destination = value; },
    markRead: () => assert.fail('Read notification should not be marked again'),
    onRead: () => assert.fail('No read update expected'),
    onReadError: () => assert.fail('No read error expected'),
  });
  assert.equal(destination, '/venues/venue-1');
});
