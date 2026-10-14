// Bearer token kept in sessionStorage so a page reload keeps you signed in (closing the tab signs you out).
const TOKEN_KEY = 'lm.token';
let token = readToken();
let sessionLostHandler = () => {};

function readToken() {
  try { return sessionStorage.getItem(TOKEN_KEY); } catch { return null; }
}

export const tokenStore = {
  get: () => token,
  set: value => {
    token = value;
    try {
      if (value) sessionStorage.setItem(TOKEN_KEY, value);
      else sessionStorage.removeItem(TOKEN_KEY);
    } catch { /* storage blocked: keep the token in memory only */ }
  },
  onSessionLost: handler => { sessionLostHandler = handler; },
};

export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

// Backend origin from VITE_API_BASE_URL (frontend/.env). Empty means same origin, so the Vite /api proxy is used.
const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL ?? '').replace(/\/+$/, '');

/** Calls the Spring Boot API at VITE_API_BASE_URL (or the Vite /api proxy if unset) and throws ApiError with the server's message. */
export async function api(path, init = {}) {
  const headers = new Headers(init.headers);
  headers.set('Accept', 'application/json');
  if (init.body !== undefined && !headers.has('Content-Type')) headers.set('Content-Type', 'application/json');
  if (token) headers.set('Authorization', `Bearer ${token}`);

  let res;
  try {
    res = await fetch(`${API_BASE_URL}${path}`, { ...init, headers });
  } catch {
    throw new ApiError(0, `Can't reach the server. Check that the backend is running${API_BASE_URL ? ` at ${API_BASE_URL}` : ''}.`);
  }
  if (res.status === 401 && !path.startsWith('/api/auth/login')) sessionLostHandler();
  if (!res.ok) {
    const problem = await res.json().catch(() => ({}));
    throw new ApiError(res.status, problem.detail ?? problem.title ?? `Request failed (${res.status}).`);
  }
  const text = await res.text();
  return text ? JSON.parse(text) : undefined;
}

export const post = (path, body = {}) => api(path, { method: 'POST', body: JSON.stringify(body) });
