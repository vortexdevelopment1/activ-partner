// All backend tests are offline. Individual tests can install their own mocks.
// Fail before any accidental real OAuth, mail, SMS or database connection.
const deny = () => { throw new Error('Network access is disabled in automated tests; mock the provider'); };
const net = require('net');
const connect = net.Socket.prototype.connect;
jest.spyOn(net.Socket.prototype, 'connect').mockImplementation(function (...args) {
  const options = net._normalizeArgs(args)[0];
  if (!options.path && ['localhost', '127.0.0.1', '::1'].includes(options.host || 'localhost')) {
    return connect.apply(this, args); // Local HTTP tests only.
  }
  return deny();
});
const fetch = global.fetch;
global.fetch = jest.fn(async (input, options) => {
  const url = new URL(typeof input === 'string' ? input : input.url || input);
  if (['localhost', '127.0.0.1', '[::1]'].includes(url.hostname)) return fetch(input, options);
  return deny();
});
