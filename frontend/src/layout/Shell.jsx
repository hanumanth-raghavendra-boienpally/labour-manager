import { useEffect, useRef, useState } from 'react';
import { NavLink, useNavigate } from 'react-router';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, post } from '../api/http';
import { useAuth } from '../auth/AuthProvider';
import { Icon } from '../components/Icon';
import { relative } from '../lib/format';

const PAGE_LABEL = { forecast: 'Forecast', allocation: 'Allocation', admin: 'Admin' };

export const homePath = me => `/${me.pages[0] ?? 'forecast'}`;

/** Header, role-based navigation, notification bell and the role's popups. */
export function Shell({ children }) {
  const { user, logout } = useAuth();
  if (!user) return null;
  return (
    <>
      <header className="hdr">
        <img src="/winfo-logo.svg" alt="WINFO" />
        <div>
          <div className="ttl">Labour Manager</div>
          <div className="sub">Workforce Management Portal V1</div>
        </div>
        <div className="right">
          <NotificationBell me={user} />
          <span>Signed in as <b>{user.displayName}</b> · {user.roleLabel}</span>
          <button className="linkish" onClick={logout}><Icon name="logout" size={14} /> Sign out</button>
        </div>
      </header>
      <nav className="nav" aria-label="Main">
        {user.pages.map(p => (
          <NavLink key={p} to={`/${p}`} className={({ isActive }) => (isActive ? 'on' : '')}>{PAGE_LABEL[p]}</NavLink>
        ))}
      </nav>
      {children}
      <RolePopup me={user} />
      <div className="foot">WINFO Labour Manager · AI agent → DB1 (labor_allocation) → store manager decision → DB2 (workflow) → allocation</div>
    </>
  );
}

function useNotifications() {
  return useQuery({
    queryKey: ['notifications'],
    queryFn: () => api('/api/notifications'),
    refetchInterval: 2000,
    refetchIntervalInBackground: true,
  });
}

/** Where a notification takes this person: their own page, opened on that request (admin: that request on the admin page). */
function targetFor(me, n) {
  if (me.role === 'ADMIN') return n.requestId ? `/admin?request=${n.requestId}` : '/admin';
  if (n.dcId == null || !n.businessDate) return null;
  return `/${me.pages[0]}?dc=${n.dcId}&date=${n.businessDate}`;
}

/**
 * Marks the notification read and opens its request. The navigation carries { focus } so the page scrolls to the record and
 * highlights it, even when it was already on screen.
 */
function useOpenNotification(me) {
  const navigate = useNavigate();
  const qc = useQueryClient();
  return async n => {
    if (!n.readAt) {
      try { qc.setQueryData(['notifications'], await post(`/api/notifications/${n.id}/read`)); } catch { /* still open it */ }
    }
    qc.invalidateQueries({ queryKey: ['forecast'] });
    qc.invalidateQueries({ queryKey: ['allocation'] });
    qc.invalidateQueries({ queryKey: ['admin'] });
    qc.invalidateQueries({ queryKey: ['dates'] });
    qc.invalidateQueries({ queryKey: ['dcs'] });
    const to = targetFor(me, n);
    if (to) navigate(to, { state: { focus: Date.now() } });
  };
}

function NotificationBell({ me }) {
  const [open, setOpen] = useState(false);
  const ref = useRef(null);
  const qc = useQueryClient();
  const { data } = useNotifications();
  const openNotification = useOpenNotification(me);

  const readAll = useMutation({ mutationFn: () => post('/api/notifications/read-all'), onSuccess: d => qc.setQueryData(['notifications'], d) });

  useEffect(() => {
    if (!open) return undefined;
    const onClick = e => { if (!ref.current?.contains(e.target)) setOpen(false); };
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, [open]);

  const unread = data?.unread ?? 0;
  return (
    <div className="bell-wrap" ref={ref}>
      <button className="bell" aria-label={`Notifications, ${unread} unread`} onClick={() => setOpen(o => !o)}>
        <Icon name="bell" />
        {unread > 0 && <span className="count">{unread > 99 ? '99+' : unread}</span>}
      </button>
      {open && (
        <div className="menu" role="menu">
          <div className="menu-head">
            <span>Notifications</span>
            {unread > 0 && <button className="link" onClick={() => readAll.mutate()}>Mark all read</button>}
          </div>
          <div className="menu-list">
            {(data?.items ?? []).length === 0 && <div className="menu-empty">Nothing yet.</div>}
            {(data?.items ?? []).map(n => (
              <button key={n.id} className="menu-item" role="menuitem" onClick={() => { setOpen(false); openNotification(n); }}>
                <span className={`dot ${n.readAt ? 'read' : ''}`} />
                <span>
                  <span className="t">{n.title}</span>
                  <span className="b">{n.body}</span>
                  <span className="w">{relative(n.createdAt)}{n.forecastCode ? ` · open ${n.forecastCode}` : ''}</span>
                </span>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

/**
 * Centered popup cards per role. The admin only gets the bell.
 *   store manager  "New forecast request: FC-…"  (only while that request still waits for a decision)  Later | Review forecast
 *   user           "Forecast approved: allocation ready" / "Forecast rejected"                         Later | View allocation / View details
 */
const POPUPS = {
  STORE_MANAGER: {
    REQUEST_RECEIVED: {
      icon: 'inbox', tone: 'warn', action: 'Review forecast',
      title: n => `New forecast request: ${n.forecastCode ?? ''}`.trim(),
      show: n => n.requestStatus === 'PENDING_REVIEW',
    },
  },
  ALLOCATOR: {
    FORECAST_APPROVED: { icon: 'checkCircle', tone: 'ok', action: 'View allocation', title: () => 'Forecast approved: allocation ready' },
    FORECAST_REJECTED: { icon: 'xCircle', tone: 'bad', action: 'View details', title: () => 'Forecast rejected' },
  },
  ADMIN: {},
};

/** "Later" puts a popup off for this browser session. Keyed by id and time, so ids reused after a DB2 reset still pop up. */
const dismissedKey = me => `lm.dismissedPopups.${me.userId}`;
const popupKey = n => `${n.id}@${n.createdAt}`;
function loadDismissed(me) {
  try { return JSON.parse(sessionStorage.getItem(dismissedKey(me)) ?? '[]'); } catch { return []; }
}

/** Shows the oldest unread notification of a popup type until it is opened or put off ("Later"). */
function RolePopup({ me }) {
  const { data } = useNotifications();
  const openNotification = useOpenNotification(me);
  const [dismissed, setDismissed] = useState(() => loadDismissed(me));
  const [opening, setOpening] = useState(false);
  const kinds = POPUPS[me.role] ?? {};
  const pending = (data?.items ?? [])
    .filter(n => kinds[n.type] && !n.readAt && !dismissed.includes(popupKey(n)) && (kinds[n.type].show?.(n) ?? true))
    .sort((a, b) => a.id - b.id);
  const current = pending[0];
  if (!current) return null;
  const kind = kinds[current.type];

  const later = () => {
    const next = [...dismissed, popupKey(current)];
    setDismissed(next);
    try { sessionStorage.setItem(dismissedKey(me), JSON.stringify(next)); } catch { /* storage blocked: remember for this page only */ }
  };
  const open = async () => {
    setOpening(true);
    try { await openNotification(current); } finally { setOpening(false); }
  };

  return (
    <div className="modal-back" role="dialog" aria-modal="true" aria-labelledby="popup-title">
      <div className="modal">
        <div className="modal-h">
          <span className={`badge badge-${kind.tone}`}><Icon name={kind.icon} /></span>
          <h3 id="popup-title">{kind.title(current)}</h3>
        </div>
        <div className="modal-b">
          <p className="lead">{current.body}</p>
          <dl className="dl">
            <div><dt>Request</dt><dd>{current.forecastCode ?? '—'}</dd></div>
            <div><dt>Received</dt><dd>{relative(current.createdAt)}</dd></div>
            {pending.length > 1 && <div><dt>Also waiting</dt><dd>{pending.length - 1} more</dd></div>}
          </dl>
        </div>
        <div className="modal-a">
          <button className="btn" onClick={later} disabled={opening}>Later</button>
          <button className="btn pri" onClick={open} disabled={opening} autoFocus>{kind.action}</button>
        </div>
      </div>
    </div>
  );
}
