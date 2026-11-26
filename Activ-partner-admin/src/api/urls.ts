const isLocalApp = import.meta.env.DEV ||
  (typeof window !== 'undefined' &&
    ['localhost', '127.0.0.1', '[::1]'].includes(window.location.hostname));

export const LOCAL_API_URL = isLocalApp
  ? import.meta.env.VITE_LOCAL_API_URL?.trim().replace(/\/+$/, '') || ''
  : '';
export const DEPLOYED_API_URL = import.meta.env.VITE_API_URL?.trim().replace(/\/+$/, '') || '';
