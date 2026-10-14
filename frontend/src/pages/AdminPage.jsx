import { useSearchParams } from 'react-router';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../api/http';
import { useAuth } from '../auth/AuthProvider';
import { AuditTrail } from '../components/AllocationCard';
import { DecisionRecord, HistoryTable } from '../components/DecisionRecord';
import { ForecastCard } from '../components/ForecastCard';
import { ForecastStats } from '../components/ForecastStats';
import { Icon } from '../components/Icon';
import { useNotificationFocus } from '../lib/focus';
import { dateTime, num, pct, relative, statusLabel, statusPill } from '../lib/format';
import { AllocationOutcome } from './AllocationPage';

/**
 * Admin · forecast and allocation together, read-only: every request with its status, decision and allocation (DB2);
 * the selected request's forecast (card, KPI cards, chart, decision, review history) and allocation (card, audit trail);
 * role permissions and integrations; the agent's latest writes in DB1; the audit log.
 */
export function AdminPage() {
  const { user } = useAuth();
  const qc = useQueryClient();
  const [params, setParams] = useSearchParams();
  const q = useQuery({ queryKey: ['admin'], queryFn: () => api('/api/admin/overview'), refetchInterval: 6_000 });
  const d = q.data;
  const requests = d?.requests ?? [];
  const selectedId = Number(params.get('request') ?? requests[0]?.requestId ?? 0) || 0;
  const selected = requests.find(r => r.requestId === selectedId);

  const fq = useQuery({ queryKey: ['admin-forecast', selectedId], queryFn: () => api(`/api/forecast/${selectedId}`), enabled: selectedId > 0, refetchInterval: 8_000 });
  const aq = useQuery({ queryKey: ['admin-allocation', selectedId], queryFn: () => api(`/api/allocation/request/${selectedId}`), enabled: selectedId > 0, refetchInterval: 8_000 });
  const focus = useNotificationFocus(!!selected && !!fq.data);
  const select = id => setParams({ request: String(id) });

  return (
    <div className="wrap"><main>
      <div className="ph">
        <div className="tile" />
        <div><h1>Admin</h1><div className="sub">Welcome back, {user?.displayName}!</div></div>
        <div className="acts"><button className="btn" onClick={() => qc.invalidateQueries()}><Icon name="refresh" size={13} /> Refresh</button></div>
      </div>
      {q.isLoading && <div className="card loading"><span className="spin" /> Loading…</div>}
      {q.isError && <div className="inline-note bad">{q.error.message}</div>}

      {d && (
        <>
          <div className="card">
            <h3>Forecast requests and allocations</h3>
            <div className="flow" style={{ marginBottom: 12 }}>
              <span className="step">AI agent</span><span className="arrow">→</span>
              <span className="step"><Icon name="database" size={12} /> DB1 · agent_playbook</span><span className="arrow">→</span>
              <span className="step">Forecast · store manager</span><span className="arrow">→</span>
              <span className="step"><Icon name="database" size={12} /> DB2 · workflow</span><span className="arrow">→</span>
              <span className="step">Allocation · user</span>
            </div>
            {requests.length === 0 ? (
              <div className="empty"><h4>No requests yet</h4><p>Requests appear here as soon as the agent writes a forecast with status {d.requestStatuses.join(' or ')} to DB1.</p></div>
            ) : (
              <div className="hxw">
                <table>
                  <thead><tr><th>Forecast request</th><th>DC · business date</th><th>Requested by (DB1)</th><th>Store manager decision (DB2)</th><th>Allocation (DB2)</th><th className="num">Cover</th></tr></thead>
                  <tbody>{requests.map(r => (
                    <tr key={r.requestId} className={`clickable ${r.requestId === selectedId ? 'sel' : ''}`} onClick={() => select(r.requestId)}>
                      <td className="nowrap"><span className="mono">{r.code}</span><span className="sub-id">received {relative(r.receivedAt)}</span></td>
                      <td className="nowrap">{r.dcCode} · {r.dateLabel}</td>
                      <td>{r.generatedBy}<span className="sub-id">{r.agentMode ? `${r.agentMode.toLowerCase()} mode · ` : ''}playbook #{r.playbookId} · {num(r.requiredHours)} vs {num(r.scheduledHours)} staff-h</span></td>
                      <td>
                        <span className={statusPill(r.status)}>{statusLabel(r.status)}</span>
                        {r.decidedBy && <span className="sub-id">{r.decision === 'REOPENED' ? 'Reopened' : r.decision === 'APPROVED' ? 'Approved' : 'Rejected'} by {r.decidedBy} · {dateTime(r.decidedAt)}{r.decisionComment ? ` · “${r.decisionComment}”` : ''}</span>}
                      </td>
                      <td>{r.allocationCode
                        ? <><span className="mono">{r.allocationCode}</span> <span className="pill p-ok">Ready</span></>
                        : <span className="muted">{r.status === 'REJECTED' ? 'Not allocated' : '—'}</span>}</td>
                      <td className="num">{r.coverage != null ? pct(r.coverage) : '—'}</td>
                    </tr>
                  ))}</tbody>
                </table>
              </div>
            )}
          </div>

          {selected && (
            <div className={`focus-wrap${focus.flash ? ' flash' : ''}`} ref={focus.ref}>
              <div className="detail-head">
                <h2>{selected.code}</h2>
                <span className={statusPill(selected.status)}>{statusLabel(selected.status)}</span>
                <span className="muted">{selected.dcName} · {selected.dateLabel} · forecast (requested by the agent) and allocation (outcome)</span>
              </div>
              {fq.isLoading && <div className="card loading"><span className="spin" /> Loading forecast…</div>}
              {fq.data?.notice && <div className="inline-note warn">{fq.data.notice}</div>}
              {fq.data?.forecast && (
                <>
                  <ForecastCard f={fq.data.forecast} showStatus />
                  <ForecastStats view={fq.data} />
                  {fq.data.forecast.status === 'PENDING_REVIEW'
                    ? <div className="card decide"><h3>Review and decision</h3><div className="inline-note" style={{ margin: 0 }}>Waiting for the store manager. Admin is read-only.</div></div>
                    : <DecisionRecord view={fq.data} />}
                  <div className="card">
                    <h3>Review history · {selected.code}</h3>
                    <HistoryTable rows={fq.data.history} />
                  </div>
                </>
              )}
              {aq.data && (
                <>
                  <div className="section-title"><h2>Allocation</h2><span className="muted">what the user sees · DB2</span></div>
                  <AllocationOutcome view={aq.data} compact />
                  <AuditTrail rows={aq.data.audit} title={`Audit trail · ${selected.code}`} />
                </>
              )}
            </div>
          )}

          <div className="card">
            <h3>Role permissions</h3>
            <table>
              <thead><tr><th>Capability</th><th>Store manager</th><th>User</th><th>Admin</th></tr></thead>
              <tbody>{d.permissions.map(p => (
                <tr key={p.capability}><td>{p.capability}</td><td>{p.storeManager}</td><td>{p.user}</td><td>{p.admin}</td></tr>
              ))}</tbody>
            </table>
          </div>

          <div className="card">
            <h3>Integrations</h3>
            <table>
              <thead><tr><th>System</th><th>Mode</th><th>Status</th></tr></thead>
              <tbody>{d.integrations.map(i => (
                <tr key={i.system}><td>{i.system}</td><td>{i.mode}</td>
                  <td className="nowrap"><span className="pill p-ok">{i.status}</span>{i.at && <span className="sub-id">{relative(i.at)}</span>}</td></tr>
              ))}</tbody>
            </table>
          </div>

          <div className="card">
            <h3>Agent writes in DB1 <span className="muted">· labor_allocation.agent_playbook, latest {d.dumps.length}</span></h3>
            <table>
              <thead><tr><th>Playbook</th><th>DC · date</th><th>Status in DB1</th><th>Written by the agent</th><th className="num">Lines</th><th>What the app did</th></tr></thead>
              <tbody>{d.dumps.map(p => (
                <tr key={p.playbookId}>
                  <td className="mono">#{p.playbookId}</td>
                  <td className="nowrap">{p.dcCode} · {p.businessDate}</td>
                  <td><span className={`pill ${p.status === 'PUBLISHED' ? 'p-in' : ''}`}>{p.status}</span>{p.agentMode && <span className="sub-id">{p.agentMode.toLowerCase()} mode</span>}</td>
                  <td className="nowrap">{dateTime(p.generatedAt)}</td>
                  <td className="num">{p.lines}</td>
                  <td>{p.forecastCode
                    ? <button className="link" onClick={() => select(p.requestId)}>{p.forecastCode}</button>
                    : p.ignored ? <span className="muted">Ignored: that date is already approved</span>
                    : p.isRequestStatus ? <span className="muted">{p.lines === 0 ? 'Waiting for its lines' : 'Being picked up…'}</span>
                    : <span className="muted">Not a request (status {p.status})</span>}
                    {p.forecastCode && <> <span className={statusPill(p.requestStatus)}>{statusLabel(p.requestStatus)}</span></>}</td>
                </tr>
              ))}</tbody>
            </table>
          </div>

          <div className="card">
            <h3>Audit log <span className="muted">· DB2, latest {d.audit.length}, append-only</span></h3>
            <table>
              <thead><tr><th>Time</th><th>User</th><th>Event</th><th>Request</th><th>Detail</th></tr></thead>
              <tbody>{d.audit.map(a => (
                <tr key={a.eventId}><td className="nowrap">{dateTime(a.occurredAt)}</td><td className="nowrap">{a.actor}</td>
                  <td><span className="pill">{a.eventType.toLowerCase()}</span></td><td className="mono nowrap">{a.forecastCode ?? '—'}</td><td>{a.detail}</td></tr>
              ))}</tbody>
            </table>
          </div>
        </>
      )}
    </main></div>
  );
}
