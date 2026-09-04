import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { api, setAdminToken } from '../api/client.js';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    const raw = localStorage.getItem('admin_user');
    const token = localStorage.getItem('admin_access_token');

    if (!raw || !token) {
      localStorage.removeItem('admin_user');
      setAdminToken(null);
      return null;
    }

    try {
      return JSON.parse(raw);
    } catch {
      localStorage.removeItem('admin_user');
      setAdminToken(null);
      return null;
    }
  });

  useEffect(() => {
    const handleExpiredSession = () => setUser(null);
    window.addEventListener('admin-session-expired', handleExpiredSession);
    return () => window.removeEventListener('admin-session-expired', handleExpiredSession);
  }, []);

  const login = async ({ identifier, password }) => {
    setAdminToken(null);
    localStorage.removeItem('admin_user');
    const response = await api.post('/auth/login', { identifier, password });
    const data = response.data.data;
    if (data.user.role !== 'admin') {
      setAdminToken(null);
      throw new Error('Admin access is required');
    }
    setAdminToken(data.accessToken);
    localStorage.setItem('admin_user', JSON.stringify(data.user));
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
    localStorage.removeItem('admin_user');
    setUser(null);
  };

  const value = useMemo(
    () => ({
      user,
      isAuthenticated: Boolean(user && localStorage.getItem('admin_access_token')),
      login,
      logout,
    }),
    [user],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  return useContext(AuthContext);
}
