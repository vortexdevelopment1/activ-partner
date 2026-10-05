import axios from 'axios';

const LOCAL_API_URL =
  import.meta.env.VITE_LOCAL_API_URL || 'http://localhost:3000/api/v1';
const DEPLOYED_API_URL =
  import.meta.env.VITE_API_URL ||
  'https://activ-partner.onrender.com/api/v1';

const LOCAL_CHECK_TIMEOUT_MS = 5000;
const LOCAL_RECHECK_INTERVAL_MS = 5000;

let activeApiUrl: string | undefined;
let lastLocalCheckAt = 0;
let selectionInProgress: Promise<string> | undefined;

const selectApiUrl = () => {
  if (activeApiUrl === LOCAL_API_URL) return Promise.resolve(LOCAL_API_URL);

  const now = Date.now();
  if (
    activeApiUrl === DEPLOYED_API_URL &&
    now - lastLocalCheckAt < LOCAL_RECHECK_INTERVAL_MS
  ) {
    return Promise.resolve(DEPLOYED_API_URL);
  }

  if (selectionInProgress) return selectionInProgress;

  lastLocalCheckAt = now;
  selectionInProgress = axios
    .get(`${LOCAL_API_URL}/categories/active`, {
      timeout: LOCAL_CHECK_TIMEOUT_MS,
      // A 4xx/5xx still proves that the local HTTP server is running.
      validateStatus: () => true,
    })
    .then(() => {
      activeApiUrl = LOCAL_API_URL;
      return LOCAL_API_URL;
    })
    .catch(() => {
      activeApiUrl = DEPLOYED_API_URL;
      return DEPLOYED_API_URL;
    })
    .finally(() => {
      selectionInProgress = undefined;
    });

  return selectionInProgress;
};

const api = axios.create({
  headers: { 'Content-Type': 'application/json' },
});

api.interceptors.request.use(async (config) => {
  config.baseURL = await selectApiUrl();

  const token = localStorage.getItem('token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const config = error.config as
      | (typeof error.config & { _renderFallbackAttempted?: boolean })
      | undefined;

    if (
      !error.response &&
      config?.baseURL === LOCAL_API_URL &&
      !config._renderFallbackAttempted
    ) {
      config._renderFallbackAttempted = true;
      config.baseURL = DEPLOYED_API_URL;
      activeApiUrl = DEPLOYED_API_URL;
      lastLocalCheckAt = Date.now();
      return api.request(config);
    }

    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default api;
