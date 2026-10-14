import { useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../api/http';
import { useAuth } from '../auth/AuthProvider';
import { AllocationCard, AllocationDetails, AuditTrail } from '../components/AllocationCard';
import { Icon } from '../components/Icon';
import { DcDatePickers, useDcDate } from '../components/Pickers';
import { useNotificationFocus } from '../lib/focus';
import { dateTime, num, relative } from '../lib/format';

/**
 * Page 2 · user. Read-only, from DB2: what happened to the agent's request (waiting, rejected with the comment, or approved),
 * the forecast allocation (ready as soon as the forecast is approved), its four KPI cards, zone coverage, unfilled shortages and remaining surplus, and the audit trail.
 */
export function AllocationPage() {
  const { user } = useAuth();
  const sel = useDcDate('allocation');
  const qc = useQueryClient();

  const q = useQuery({
    queryKey: ['allocation', sel.dcId, sel.date],
    queryFn: () => api(`/api/allocation?dcId=${sel.dcId}&date=${sel.date}`),
    enabled: sel.ready,
    refetchInterval: 8_000,
  });
  const view = q.data;
  const focus = useNotificationFocus(!!view);

  return (
    <div className="wrap"><main>
      <div className="ph">
        <div className="tile" />
        <div><h1>Allocation</h1><div className="sub">Welcome back, {user?.displayName}!</div></div>
        <div className="acts"><button className="btn" onClick={() => qc.invalidateQueries()}><Icon name="refresh" size={13} /> Refresh</button></div>
      </div>

      <div className="toolbar">
        <DcDatePickers state={sel} mode="allocation" />
        {view && <OutcomePill view={view} />}
      </div>

      {(q.isLoading || (!sel.ready && !sel.empty)) && <div className="card loading"><span className="spin" /> Loading allocation…</div>}
      {q.isError && <div className="inline-note bad">{q.error.message}</div>}

      {sel.empty && (
        <div className="card">
          <h3>Forecast allocation</h3>
          <div className="empty">
            <h4>Nothing allocated yet</h4>
            <p>The agent has not sent a forecast for {sel.dc?.dcName ?? 'this DC'}. Once the store manager approves or rejects one, you get a popup and the outcome shows here.</p>
          </div>
        </div>
      )}

      {view && (
        <div className={`focus-wrap${focus.flash ? ' flash' : ''}`} ref={focus.ref}>
          <AllocationOutcome view={view} />
        </div>
      )}
      {view?.request && <AuditTrail rows={view.audit} title={`Audit trail · ${view.request.code}`} />}
    </main></div>
  );
}

export function OutcomePill({ view }) {
  switch (view.state) {
    case 'PENDING': return <span className="pill p-wa">Waiting for the store manager</span>;
    case 'REJECTED': return <span className="pill p-ba">Rejected</span>;
    case 'SUPERSEDED': return <span className="pill">Superseded</span>;
    case 'ALLOCATED': return <><span className="pill p-ok">Approved</span> <span className="pill p-ok">Allocation ready</span></>;
    case 'NO_REQUEST': return <span className="pill">No request</span>;
    default: return null;
  }
}

/**
 * The outcome of one request (all from DB2). Used by the Allocation page and, without the KPI cards and tables (compact),
 * by the Admin page, which shows the forecast and its chart next to it.
 */
export function AllocationOutcome({ view, compact = false }) {
  const r = view.request;
  if (view.state === 'NO_REQUEST') {
    return <div className="card"><h3>Forecast allocation · {view.dateLabel}</h3><p style={{ margin: 0 }}>The agent has not sent a forecast for this DC and date, so there is nothing to allocate.</p></div>;
  }
  if (view.state === 'PENDING' || view.state === 'SUPERSEDED') {
    return (
      <div className="card">
        <h3>Forecast allocation · {view.dateLabel}</h3>
        {view.state === 'PENDING'
          ? <p style={{ margin: '0 0 8px' }}>Forecast <b>{r.code}</b> was sent by the agent {relative(r.receivedAt)} and is <b>waiting for the store manager's decision</b>. You get a popup as soon as it is approved or rejected.</p>
          : <p style={{ margin: '0 0 8px' }}>Forecast <b>{r.code}</b> was replaced by a newer version from the agent before it was reviewed.</p>}
        <div className="rec">
          <div><span className="muted">Requested by</span>{r.generatedBy}{r.agentMode ? ` · ${r.agentMode.toLowerCase()} mode` : ''}</div>
          <div><span className="muted">Store and date</span>{r.dcName} · {view.dateLabel}</div>
          <div><span className="muted">Requirement</span>{num(r.requiredHours)} staff-h required vs {num(r.scheduledHours)} scheduled</div>
        </div>
      </div>
    );
  }
  if (view.state === 'REJECTED') {
    const j = view.rejection ?? {};
    return (
      <div className="card rejected">
        <h3>Forecast allocation · {view.dateLabel} <span className="pill p-ba">Rejected</span></h3>
        <p style={{ margin: '0 0 10px' }}>The store manager rejected this forecast, so nothing was allocated.</p>
        <div className="rec">
          <div><span className="muted">Forecast</span>{r.code} · v{r.version}</div>
          <div><span className="muted">Rejected by</span>{j.by ?? '—'}{j.title ? ` · ${j.title}` : ''}</div>
          <div><span className="muted">Rejected at</span>{dateTime(j.at)}</div>
          <div className="wide"><span className="muted">Comment</span>{j.comment || '—'}</div>
        </div>
      </div>
    );
  }
  if (view.state === 'NOT_ALLOCATED') {
    return <div className="card"><h3>Forecast allocation · {view.dateLabel}</h3><p style={{ margin: 0 }}>Forecast <b>{r.code}</b> is approved, but no allocation was found in DB2.</p></div>;
  }
  if (view.state !== 'ALLOCATED') return null;
  return (
    <>
      <AllocationCard request={r} allocation={view.allocation} />
      {!compact && <AllocationDetails view={view} />}
    </>
  );
}
