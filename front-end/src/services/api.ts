import axios from 'axios';
import { useSecurityStore } from '../store/useSecurityStore';

const normalizeApiBaseUrl = (raw?: string) => {
  const fallback = 'http://localhost:8080/api';
  const value = (raw ?? '').trim();
  if (!value) return fallback;

  const trimmed = value.replace(/\/+$/, '');
  if (trimmed.endsWith('/api')) return trimmed;
  return `${trimmed}/api`;
};

const API_URL = normalizeApiBaseUrl(import.meta.env.VITE_API_BASE_URL);

const ACCESS_TOKEN_KEY = 'token';
const REFRESH_TOKEN_KEY = 'refreshToken';
const TOKEN_EXPIRES_AT_KEY = 'tokenExpiresAt';

const clearAuthStorage = () => {
  localStorage.removeItem(ACCESS_TOKEN_KEY);
  localStorage.removeItem(REFRESH_TOKEN_KEY);
  localStorage.removeItem(TOKEN_EXPIRES_AT_KEY);
};

const persistAuthResponse = (data: any) => {
  const accessToken = data?.accessToken;
  const refreshToken = data?.refreshToken;
  const expiresIn = data?.expiresIn;

  if (typeof accessToken === 'string' && accessToken) {
    localStorage.setItem(ACCESS_TOKEN_KEY, accessToken);
  }
  if (typeof refreshToken === 'string' && refreshToken) {
    localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);
  }
  if (typeof expiresIn === 'number' && Number.isFinite(expiresIn) && expiresIn > 0) {
    localStorage.setItem(TOKEN_EXPIRES_AT_KEY, String(Date.now() + expiresIn * 1000));
  }
};

let refreshInFlight: Promise<string> | null = null;

const refreshAccessToken = async (): Promise<string> => {
  const refreshToken = localStorage.getItem(REFRESH_TOKEN_KEY);
  if (!refreshToken) {
    throw new Error('Missing refresh token');
  }

  if (!refreshInFlight) {
    refreshInFlight = axios
      .post(
        `${API_URL}/auth/refresh`,
        { refreshToken },
        {
          headers: { 'Content-Type': 'application/json' }
        }
      )
      .then((resp) => {
        const payload = resp?.data;
        if (!payload || payload.code !== 200) {
          throw new Error(payload?.message || 'Refresh failed');
        }
        const auth = payload?.data;
        persistAuthResponse(auth);
        const nextAccessToken = auth?.accessToken;
        if (typeof nextAccessToken !== 'string' || !nextAccessToken) {
          throw new Error('Missing access token in refresh response');
        }
        return nextAccessToken;
      })
      .finally(() => {
        refreshInFlight = null;
      });
  }

  return refreshInFlight;
};

const isAuthEndpoint = (url?: string) => {
  if (!url) return false;
  return url.includes('/auth/login') || url.includes('/auth/register') || url.includes('/auth/refresh');
};

const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

api.interceptors.request.use(
  (config) => {
    // Debug Log
    console.log(`[API Request] ${config.method?.toUpperCase()} ${config.url}`);
    
    const token = localStorage.getItem(ACCESS_TOKEN_KEY);
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }

    // Add Turnstile Token
    const turnstileToken = useSecurityStore.getState().turnstileToken;
    if (turnstileToken) {
        config.headers['X-CF-Token'] = turnstileToken;
    }

    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

api.interceptors.response.use(
  async (response) => {
    const payload = response.data;

    if (payload && (payload.code === 401 || payload.code === 403)) {
      const originalConfig: any = response.config || {};
      const alreadyRetried = !!originalConfig._authRetry;

      if (!alreadyRetried && !isAuthEndpoint(originalConfig.url)) {
        originalConfig._authRetry = true;
        try {
          await refreshAccessToken();
          return api(originalConfig);
        } catch (_e) {
          clearAuthStorage();
          window.dispatchEvent(new Event('auth:logout'));
        }
      } else {
        clearAuthStorage();
        window.dispatchEvent(new Event('auth:logout'));
      }
    }

    return payload; // Return the payload directly
  },
  async (error) => {
    // Handle 401 Unauthorized globally if needed (e.g., redirect to login)
    if (error.response && (error.response.status === 401 || error.response.status === 403)) {
      const originalConfig: any = error.config || {};
      const alreadyRetried = !!originalConfig._authRetry;

      if (!alreadyRetried && !isAuthEndpoint(originalConfig.url)) {
        originalConfig._authRetry = true;
        try {
          await refreshAccessToken();
          return api(originalConfig);
        } catch (_e) {
          clearAuthStorage();
          window.dispatchEvent(new Event('auth:logout'));
        }
      } else {
        clearAuthStorage();
        window.dispatchEvent(new Event('auth:logout'));
      }
    }
    
    // Check for Captcha failure
    if (error.response?.data?.code === 2012) {
        useSecurityStore.getState().setTurnstileToken(null);
    }

    return Promise.reject(error);
  }
);

export default api;
