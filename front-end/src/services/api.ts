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
    
    const token = localStorage.getItem('token');
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
  (response) => {
    return response.data; // Return the payload directly
  },
  async (error) => {
    // Handle 401 Unauthorized globally if needed (e.g., redirect to login)
    if (error.response && (error.response.status === 401 || error.response.status === 403)) {
      // Clear local storage and redirect to login logic
      localStorage.removeItem('token');
      // Dispatch a custom event so App.tsx can handle the redirect without full reload
      window.dispatchEvent(new Event('auth:logout'));
    }
    
    // Check for Captcha failure
    if (error.response?.data?.code === 2012) {
        useSecurityStore.getState().setTurnstileToken(null);
    }

    return Promise.reject(error);
  }
);

export default api;
