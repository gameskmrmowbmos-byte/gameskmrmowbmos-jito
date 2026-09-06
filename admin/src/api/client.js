import axios from 'axios';

const baseURL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:5002/api';
const adminUserKey = 'matka_admin:v1:user';

let adminAccessToken = null;

export const api = axios.create({
  baseURL,
  withCredentials: true,
  headers: {
    Accept: 'application/json',
    'X-Client-Platform': 'web',
  },
});

let refreshPromise = null;

export function clearAdminSession() {
  setAdminToken(null);
  localStorage.removeItem(adminUserKey);
  window.dispatchEvent(new Event('admin-session-expired'));
}

export async function refreshAdminSession() {
  if (!refreshPromise) {
    refreshPromise = api
      .post('/auth/refresh', {})
      .then((response) => {
        const token = response.data?.data?.accessToken;
        if (!token) throw new Error('Session refresh failed');
        setAdminToken(token);
        return token;
      })
      .finally(() => {
        refreshPromise = null;
      });
  }
  return refreshPromise;
}

api.interceptors.request.use((config) => {
  const token = adminAccessToken;
  if (token && !config.url?.includes('/auth/login')) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error?.response?.status === 401) {
      clearAdminSession();
    }
    return Promise.reject(error);
  },
);

export function setAdminToken(token) {
  adminAccessToken = token || null;
}

export function hasAdminToken() {
  return adminAccessToken != null;
}

export function apiMessage(error) {
  const data = error?.response?.data;
  if (Array.isArray(data?.errors) && data.errors.length > 0) {
    return data.errors
      .map((item) => {
        const field = item?.field ? `${item.field}: ` : '';
        return `${field}${item?.message || 'Invalid value'}`;
      })
      .join(', ');
  }
  return data?.message || error?.message || 'Request failed';
}
