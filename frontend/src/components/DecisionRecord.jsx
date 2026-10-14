import { dateTime, pct } from '../lib/format';

/** Approval or rejection record of a forecast (read-only), from DB2. footer: e.g. the store manager's "Reopen" form. */
export function DecisionRecord({ view, footer }) {
  const f = view.forecast;
  if (f.status === 'APPROVED' && view.approval) {
    const a = view.approval;
    const run = view.allocation;
    return (
      <div className="card">
        <h3>Approval record <span className="pill p-ok">Approved</span></h3>
        <div className="rec">
          <div><span className="muted">Approved by</span>{a.by} · {a.title}, {f.dcCode}</div>
          <div><span className="muted">Approved at</span>{dateTime(a.at)}</div>
          <div><span className="muted">Review cycle</span>{a.cycle}</div>
          <div className="wide"><span className="muted">Comment</span>{a.comment || '—'}</div>
          {run && (
            <div className="wide">
              <span className="muted">Allocation</span>
              {run.code} · {dateTime(run.createdAt)} · schedule covers {pct(run.coverage)} of the approved need{' '}
              <span className="pill p-ok">Ready</span>
            </div>
          )}
        </div>
        {footer}
      </div>
    );
  }
  if (f.status === 'REJECTED' && view.rejection) {
    const r = view.rejection;
    return (
      <div className="card rejected">
        <h3>Rejection record <span className="pill p-ba">Rejected</span></h3>
        <div className="rec">
          <div><span className="muted">Rejected by</span>{r.by} · {r.title}, {f.dcCode}</div>
          <div><span className="muted">Rejected at</span>{dateTime(r.at)}</div>
          <div><span className="muted">Review cycle</span>{r.cycle}</div>
          <div className="wide"><span className="muted">Comment</span>{r.comment || '—'}</div>
        </div>
        <div style={{ marginTop: 10 }}><span className="pill">Unallocated</span> <span className="muted" style={{ fontSize: 13 }}>No allocation was made for this forecast.</span></div>
        {footer}
      </div>
    );
  }
  return null;
}

/** Review history of one request (DB2): received, decisions with their comments, allocation. */
export function HistoryTable({ rows }) {
  const cls = a => (a === 'Approved' ? 'p-ok' : a === 'Rejected' ? 'p-ba' : a === 'Allocated' ? 'p-in' : a === 'Reopened' ? 'p-wa' : '');
  return (
    <table>
      <thead><tr><th>Cycle</th><th>Action</th><th>By</th><th>When</th><th>Comment</th></tr></thead>
      <tbody>
        {(rows ?? []).map((h, i) => (
          <tr key={i}>
            <td>{h.cycle}</td>
            <td><span className={`pill ${cls(h.action)}`}>{h.action}</span></td>
            <td>{h.actor}</td><td className="nowrap">{dateTime(h.at)}</td><td>{h.comment || '—'}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
