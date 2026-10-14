import { useRef, useState } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router';
import { useQuery } from '@tanstack/react-query';
import { api, ApiError } from '../api/http';
import { useAuth } from './AuthProvider';
import { Icon } from '../components/Icon';
import { homePath } from '../layout/Shell';
import '../styles/login.css';

/** Sign-in screen for the three roles: store manager, user and administrator. */
export function LoginPage() {
  const { status, user, login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const passwordRef = useRef(null);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  const demo = useQuery({ queryKey: ['demo-identities'], queryFn: () => api('/api/auth/demo-identities'), staleTime: Infinity, retry: 1 });
  const appInfo = useQuery({ queryKey: ['app-info'], queryFn: () => api('/api/auth/app-info'), staleTime: Infinity, retry: 0 });

  const from = location.state?.from;
  if (status === 'authenticated' && user) return <Navigate to={from ?? homePath(user)} replace />;

  async function submit(e) {
    e.preventDefault();
    if (!username.trim() || !password) { setError('Enter your username and password.'); return; }
    setBusy(true);
    setError(null);
    try {
      const me = await login(username.trim(), password);
      navigate(from && me.pages.some(p => from.startsWith('/' + p)) ? from : homePath(me), { replace: true });
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Sign-in failed. Try again.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login-page">
      <form className="login-card" onSubmit={submit} noValidate>
        <h1 className="login-title">Sign in</h1>
        <p className="login-subtitle">Sign in as a store manager, a user or an administrator.</p>

        <label className="login-label" htmlFor="username">Username</label>
        <input id="username" className="login-input" autoComplete="username" autoFocus value={username}
               onChange={e => { setUsername(e.target.value); setError(null); }} />

        <label className="login-label" htmlFor="password">Password</label>
        <input id="password" ref={passwordRef} type="password" className="login-input" autoComplete="current-password"
               value={password} onChange={e => { setPassword(e.target.value); setError(null); }} />

        {error && <div className="login-error" role="alert"><Icon name="alert" />{error}</div>}

        <button className="login-button" type="submit" disabled={busy}>
          <Icon name="shieldCheck" size={18} />{busy ? 'Signing in...' : 'Sign In'}
        </button>

        <div className="login-label demo-heading">Provisioned demo identities</div>
        {demo.isLoading && <p className="login-note">Loading identities...</p>}
        {demo.isError && <p className="login-note err">Can't load demo identities. Check that the backend is running.</p>}
        {demo.data && (
          <ul className="demo-list">
            {demo.data.map(d => (
              <li key={d.username}>
                <button type="button" className="demo-row"
                        onClick={() => { setUsername(d.username); setError(null); passwordRef.current?.focus(); }}>
                  {d.username} &rarr; {d.label}
                </button>
              </li>
            ))}
          </ul>
        )}
        <p className="login-app">{appInfo.data?.name ?? 'WINFO Labour Manager'}</p>
      </form>
    </div>
  );
}
