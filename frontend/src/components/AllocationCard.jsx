import { dateTime, isNew, num, pct } from '../lib/format';

/** The "Forecast allocation" card (dynamic): created in DB2 when the store manager approves, and final at once. */
export function AllocationCard({ request, allocation }) {
  const a = allocation;
  return (
    <div className="card">
      <h3>
        Forecast allocation {a.code} {isNew(a.createdAt) && <span className="newtag">NEW</span>} <span className="pill p-ok">Ready</span>
      </h3>
      <div className="meta">
        <div><span className="muted">Source forecast</span>{request.code} <span className="pill p-ok">Approved</span></div>
        <div><span className="muted">Approved by</span>{a.approvedBy}{a.approverTitle ? ` · ${a.approverTitle}` : ''} · {dateTime(a.approvedAt)}</div>
        <div><span className="muted">Allocated</span>{dateTime(a.createdAt)}</div>
      </div>
      <div className="muted" style={{ marginTop: 10 }}>Allocated against the approved requirement: the forecast was approved as sent, with no changes.</div>
      <div className="narrative"><span className="muted">Store manager's comment: </span>{a.approvalComment || '—'}</div>
      <div className="src">Stored in DB2 · workflow.allocation · {request.dcName} · {request.dateLabel} · forecast from agent_playbook #{request.playbookId}</div>
    </div>
  );
}

/**
 * The allocation's four KPI cards, zone coverage, unfilled shortages and remaining surplus (Allocation wireframe, kept to what
 * the approved forecast supports: no employees, so no assignments or call-ins).
 * view = { summary, zoneCoverage, shortages, surpluses, shortagesMore, surplusesMore }
 */
export function AllocationDetails({ view }) {
  const s = view?.summary;
  if (!s) return null;
  const more = n => n > 0 && <div className="muted" style={{ marginTop: 8 }}>and {n} more window{n === 1 ? '' : 's'}</div>;
  return (
    <>
      <div className="kpis">
        <div className="kpi k-b"><div className="dot" /><div className="l">Approved need</div><div className="v">{num(s.needHours)} <small>staff-h</small></div><div className="s">Forecast approved as sent</div></div>
        <div className="kpi k-g"><div className="dot" /><div className="l">Scheduled</div><div className="v">{num(s.scheduledHours)} <small>staff-h</small></div><div className="s">From the static plan</div></div>
        <div className="kpi k-o"><div className="dot" /><div className="l">Staff-hours short</div><div className="v">{num(s.shortHours)}h</div><div className="s">Need above the schedule</div></div>
        <div className="kpi k-p"><div className="dot" /><div className="l">Coverage of approved need</div><div className="v">{pct(s.coverage)}</div><div className="s">{num(s.surplusHours)}h surplus elsewhere</div></div>
      </div>

      <div className="card">
        <h3>Zone coverage: scheduled vs approved</h3>
        <table>
          <thead><tr><th>Zone</th><th className="num">Approved need</th><th className="num">Scheduled covers</th><th className="num">Still short</th><th className="num">Surplus</th></tr></thead>
          <tbody>{view.zoneCoverage.map(z => (
            <tr key={z.zoneId}><td>{z.name}</td><td className="num">{num(z.needHours)} staff-h</td><td className="num">{pct(z.coverage)}</td>
              <td className="num">{num(z.shortHours)}h</td><td className="num">{num(z.surplusHours)}h</td></tr>
          ))}</tbody>
        </table>
      </div>

      <div className="card">
        <h3>Unfilled shortages</h3>
        {view.shortages.length === 0 ? <div className="empty">No shortages: the schedule covers the approved need in every zone and hour.</div> : (
          <>
            <table>
              <thead><tr><th>Zone</th><th>Window</th><th>Short by</th></tr></thead>
              <tbody>{view.shortages.map((r, i) => <tr key={i}><td>{r.zone}</td><td className="nowrap">{r.window}</td><td>{r.shortBy} staff</td></tr>)}</tbody>
            </table>
            {more(view.shortagesMore)}
          </>
        )}
      </div>

      <div className="card">
        <h3>Remaining surplus</h3>
        {view.surpluses.length === 0 ? <div className="empty">No surplus: nobody is scheduled above the approved need.</div> : (
          <>
            <table>
              <thead><tr><th>Zone</th><th>Window</th><th>Over by</th><th>Recommendation</th></tr></thead>
              <tbody>{view.surpluses.map((r, i) => <tr key={i}><td>{r.zone}</td><td className="nowrap">{r.window}</td><td>{r.overBy} staff</td><td>Redeploy to another zone or offer early release</td></tr>)}</tbody>
            </table>
            {more(view.surplusesMore)}
          </>
        )}
      </div>
    </>
  );
}

/** Audit trail of one request, from DB2 workflow.audit_event (append-only). */
export function AuditTrail({ rows, title = 'Audit trail' }) {
  const list = rows ?? [];
  return (
    <div className="card">
      <h3>{title} <span className="muted">· DB2 workflow.audit_event</span></h3>
      {list.length === 0 ? <div className="empty">Nothing recorded yet.</div> : (
        <table>
          <thead><tr><th>Time</th><th>By</th><th>Event</th><th>Detail</th></tr></thead>
          <tbody>{list.map(e => (
            <tr key={e.eventId}>
              <td className="nowrap">{dateTime(e.occurredAt)}</td>
              <td className="nowrap">{e.actor}</td>
              <td><span className="pill">{e.eventType.toLowerCase()}</span></td>
              <td>{e.detail}</td>
            </tr>
          ))}</tbody>
        </table>
      )}
    </div>
  );
}
