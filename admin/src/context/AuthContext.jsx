import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import {
  api,
  clearAdminSession,
  hasAdminToken,
  setAdminToken,
} from '../api/client.js';

const AuthContext = createContext(null);
const adminDeviceKey = 'matka_admin:v1:device_id';
const adminUserKey = 'matka_admin:v1:user';

function getAdminDeviceId() {
  const existing = localStorage.getItem(adminDeviceKey);
  if (existing && existing.length >= 16) return existing;

  const deviceId =
    typeof crypto?.randomUUID === 'function'
      ? crypto.randomUUID()
      : `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  localStorage.setItem(adminDeviceKey, deviceId);
  return deviceId;
}

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let active = true;
    api
      .post('/auth/refresh', {})
      .then((response) => {
        const data = response.data?.data;
        if (data?.user?.role !== 'admin' || !data?.accessToken) {
          throw new Error('Admin access is required');
        }
        if (!active) return;
        setAdminToken(data.accessToken);
        localStorage.setItem(adminUserKey, JSON.stringify(data.user));
        setUser(data.user);
      })
      .catch(() => {
        if (active) clearAdminSession();
      })
      .finally(() => {
        if (active) setReady(true);
      });
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    const handleExpiredSession = () => setUser(null);
    window.addEventListener('admin-session-expired', handleExpiredSession);
    return () => window.removeEventListener('admin-session-expired', handleExpiredSession);
  }, []);

  const login = async ({ identifier, password }) => {
    setAdminToken(null);
    localStorage.removeItem(adminUserKey);
    const response = await api.post('/auth/login', {
      identifier: identifier.trim(),
      password,
      deviceId: getAdminDeviceId(),
    });
    const data = response.data.data;
    if (data.user.role !== 'admin') {
      setAdminToken(null);
      throw new Error('Admin access is required');
    }
    setAdminToken(data.accessToken);
    localStorage.setItem(adminUserKey, JSON.stringify(data.user));
    setUser(data.user);
    return data.user;
  };

  const logout = async () => {
    try {
      await api.post('/auth/logout', {});
    } catch {
      // Local logout still clears the admin session.
    }
    setAdminToken(null);
    localStorage.removeItem(adminUserKey);
    setUser(null);
  };

  const value = useMemo(
    () => ({
      user,
      isAuthenticated: Boolean(user && hasAdminToken()),
      ready,
      login,
      logout,
    }),
    [ready, user],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  return useContext(AuthContext);
}
