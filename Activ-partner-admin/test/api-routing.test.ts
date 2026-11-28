// @vitest-environment jsdom
// @vitest-environment-options {"url":"https://admin.example.com"}
import axios, { AxiosError } from 'axios';
import { afterEach, expect, it, vi } from 'vitest';

const localUrl = 'http://localhost:3000/api/v1';
const deployedUrl = 'https://api.example.com/api/v1';

afterEach(() => {
  localStorage.clear();
  vi.restoreAllMocks();
  vi.unstubAllEnvs();
  vi.resetModules();
});

it('returns a failed login to the form without invalidating the current session', async () => {
  vi.stubEnv('DEV', false);
  vi.stubEnv('VITE_API_URL', deployedUrl);
  localStorage.setItem('token', 'previous-token');
  const { default: api } = await import('../src/api/axios');

  await expect(api.post('/auth/login', {}, {
    adapter: async (config) => {
      expect(config.headers.has('Authorization')).toBe(false);
      throw new AxiosError('Invalid email or password', 'ERR_BAD_REQUEST', config, undefined, {
        data: { message: 'Invalid email or password' },
        status: 401, statusText: 'Unauthorized', headers: {}, config,
      });
    },
  })).rejects.toMatchObject({ response: { status: 401 } });
  expect(localStorage.getItem('token')).toBe('previous-token');
});

it.each([false, true])('selects the correct API and asset host with DEV=%s', async (dev) => {
  vi.stubEnv('DEV', dev);
  vi.stubEnv('VITE_LOCAL_API_URL', localUrl);
  vi.stubEnv('VITE_API_URL', deployedUrl);
  const probe = vi.spyOn(axios, 'get').mockResolvedValue({ status: 200 });
  const { default: api } = await import('../src/api/axios');
  const { resolveAssetUrl } = await import('../src/utils/documents');
  const expectedUrl = dev ? localUrl : deployedUrl;

  const response = await api.get('/logs', {
    adapter: async (config) => ({ data: null, status: 200, statusText: 'OK', headers: {}, config }),
  });

  expect(response.config.baseURL).toBe(expectedUrl);
  expect(resolveAssetUrl('/files/document.pdf')).toBe(
    `${new URL(expectedUrl).origin}/files/document.pdf`,
  );
  expect(probe).toHaveBeenCalledTimes(dev ? 1 : 0);
});
