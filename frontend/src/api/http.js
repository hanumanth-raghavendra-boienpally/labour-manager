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

/** Calls the Spring Boot API (proxied by Vite on /api) and throws ApiError with the server's message. */
export async function api(path, init = {}) {
  const headers = new Headers(init.headers);
  headers.set('Accept', 'application/json');
  if (init.body !== undefined && !headers.has('Content-Type')) headers.set('Content-Type', 'application/json');
  if (token) headers.set('Authorization', `Bearer ${token}`);

  let res;
  try {
    res = await fetch(path, { ...init, headers });
  } catch {
    throw new ApiError(0, "Can't reach the server. Check that the backend is running on port 8080.");
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
