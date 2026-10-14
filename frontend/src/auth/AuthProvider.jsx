import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { api, post, tokenStore } from '../api/http';

const AuthContext = createContext(null);

/** status: 'loading' | 'anonymous' | 'authenticated'; user: { userId, displayName, role, roleLabel, title, pages, permissions } */
export function AuthProvider({ children }) {
  const queryClient = useQueryClient();
  const [status, setStatus] = useState(tokenStore.get() ? 'loading' : 'anonymous');
  const [user, setUser] = useState(null);

  const logout = useCallback(() => {
    tokenStore.set(null);
    setUser(null);
    setStatus('anonymous');
    queryClient.clear();
  }, [queryClient]);

  useEffect(() => {
    tokenStore.onSessionLost(logout);
    if (!tokenStore.get()) return;
    let cancelled = false;
    api('/api/auth/me')
      .then(me => { if (!cancelled) { setUser(me); setStatus('authenticated'); } })
      .catch(() => { if (!cancelled) logout(); });
    return () => { cancelled = true; };
  }, [logout]);

  const login = useCallback(async (username, password) => {
    const res = await post('/api/auth/login', { username, password });
    tokenStore.set(res.token);
    setUser(res.user);
    setStatus('authenticated');
    return res.user;
  }, []);

  const value = useMemo(() => ({ status, user, login, logout }), [status, user, login, logout]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
}
