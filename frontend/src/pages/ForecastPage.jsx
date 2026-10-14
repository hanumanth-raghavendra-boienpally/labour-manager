import { useEffect, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiError, post } from '../api/http';
import { useAuth } from '../auth/AuthProvider';
import { ConfirmModal } from '../components/ConfirmModal';
import { DecisionRecord, HistoryTable } from '../components/DecisionRecord';
import { ForecastCard } from '../components/ForecastCard';
import { ForecastStats } from '../components/ForecastStats';
import { Icon } from '../components/Icon';
import { DcDatePickers, useDcDate } from '../components/Pickers';
import { useToast } from '../components/Toast';
import { useNotificationFocus } from '../lib/focus';
import { statusLabel, statusPill } from '../lib/format';

/**
 * Page 1 · store manager. Everything here is live:
 *   - the AI labour forecast card, the four KPI cards and the staffing chart with its zone chips
 *     (DB1 while pending, the DB2 snapshot once decided);
 *   - the popup when the agent writes a forecast (see Shell);
 *   - review and decision (approve or reject with a comment, written to DB2) and the review history.
 */
export function ForecastPage() {
  const { user } = useAuth();
  const sel = useDcDate('forecast');
  const toast = useToast();
  const qc = useQueryClient();
  const [comment, setComment] = useState('');
  const [confirm, setConfirm] = useState(null); // 'approve' | 'reject' | 'reopen'

  const q = useQuery({
    queryKey: ['forecast', sel.dcId, sel.date],
    queryFn: () => api(`/api/forecast?dcId=${sel.dcId}&date=${sel.date}`),
    enabled: sel.ready,
    refetchInterval: 8_000,
  });
  const view = q.data;
  const f = view?.forecast ?? null;
  const focus = useNotificationFocus(!!f);

  // Reset the comment when another record (or another state of it) is shown.
  useEffect(() => { setComment(''); }, [f?.requestId, f?.status]);

  const done = (data, kind, title, body) => {
    qc.setQueryData(['forecast', sel.dcId, sel.date], data);
    qc.invalidateQueries({ queryKey: ['dates'] });
    qc.invalidateQueries({ queryKey: ['dcs'] });
    qc.invalidateQueries({ queryKey: ['notifications'] });
    setConfirm(null);
    toast(kind, title, body);
  };
  const fail = e => {
    setConfirm(null);
    toast('bad', 'Action failed', e instanceof ApiError ? e.message : String(e));
    if (e instanceof ApiError && e.status === 409) q.refetch();
  };

  const approve = useMutation({
    mutationFn: () => post(`/api/forecast/${f.requestId}/approve`, { rowVersion: f.rowVersion, comment }),
    onSuccess: d => done(d, 'ok', `Approved ${d.forecast.code}`, `Saved to DB2. Allocation ${d.allocation?.code} is ready; the user has been notified.`),
    onError: fail,
  });
  const reject = useMutation({
    mutationFn: () => post(`/api/forecast/${f.requestId}/reject`, { rowVersion: f.rowVersion, comment }),
    onSuccess: d => done(d, 'info', `Rejected ${d.forecast.code}`, 'Saved to DB2. The user has been notified; nothing was allocated.'),
    onError: fail,
  });
  const reopen = useMutation({
    mutationFn: () => post(`/api/forecast/${f.requestId}/reopen`, { rowVersion: f.rowVersion, comment }),
    onSuccess: d => done(d, 'info', `Reopened ${d.forecast.code}`, `Review cycle ${d.forecast.reviewCycle}.`),
    onError: fail,
  });
  const busy = approve.isPending || reject.isPending || reopen.isPending;

  return (
    <div className="wrap"><main>
      <div className="ph">
        <div className="tile" />
        <div><h1>Forecast</h1><div className="sub">Welcome back, {user?.displayName}!</div></div>
        <div className="acts"><button className="btn" onClick={() => qc.invalidateQueries()}><Icon name="refresh" size={13} /> Refresh</button></div>
      </div>

      <div className="toolbar">
        <DcDatePickers state={sel} mode="forecast" />
        {f && <span className={statusPill(f.status)}>{statusLabel(f.status)}</span>}
        {view?.allocation && <span className="pill p-ok">Allocation ready</span>}
      </div>

      {(q.isLoading || (!sel.ready && !sel.empty)) && <div className="card loading"><span className="spin" /> Loading forecast…</div>}
      {q.isError && <div className="inline-note bad">{q.error.message}</div>}
      {view?.notice && <div className="inline-note warn">{view.notice}</div>}

      {sel.empty && (
        <div className="card">
          <h3>AI labour forecast</h3>
          <div className="empty">
            <h4>Waiting for the agent</h4>
            <p>No forecast request has arrived for {sel.dc?.dcName ?? 'this DC'} yet. As soon as the agent writes its forecast to DB1, you get a
              popup and a notification, and the request appears here for you to approve or reject.</p>
          </div>
        </div>
      )}

      {view && !f && !sel.empty && (
        <div className="card"><h3>AI labour forecast · {view.dateLabel}</h3>
          <div className="empty"><h4>No agent request for {sel.dc?.dcName ?? 'this DC'} on {view.dateLabel}.</h4></div></div>
      )}

      {view && f && (
        <>
          <ForecastCard f={f} cardRef={focus.ref} flash={focus.flash} />

          <ForecastStats view={view} />

          {f.status === 'PENDING_REVIEW' && (
            <div className="card decide">
              <h3>Review and decision</h3>
              {view.permissions.canReview ? (
                <>
                  <p style={{ margin: '0 0 10px', fontSize: 13 }}>The agent is asking you to approve this forecast. Approving locks it and creates the
                    allocation, which is ready for the user at once; rejecting leaves it unallocated. Either way the decision and your comment are saved
                    to DB2 and the user is notified.</p>
                  <label className="field">Comment (optional)
                    <textarea value={comment} onChange={e => setComment(e.target.value)} placeholder="e.g. Approved; inbound truck confirmed for 6:30a" maxLength={1000} />
                  </label>
                  <div style={{ marginTop: 12, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                    <button className="btn pri" disabled={busy} onClick={() => setConfirm('approve')}><Icon name="check" size={13} /> Approve and allocate</button>
                    <button className="btn danger" disabled={busy} onClick={() => setConfirm('reject')}><Icon name="x" size={13} /> Reject</button>
                  </div>
                  <div className="muted" style={{ marginTop: 8 }}>Signed in as {user?.displayName} ({user?.title}, {f.dcCode}). Decision, comment and time are recorded.</div>
                </>
              ) : (
                <div className="inline-note" style={{ margin: 0 }}><b>Read-only.</b> This request cannot be decided right now.</div>
              )}
            </div>
          )}

          <DecisionRecord view={view} footer={f.status === 'REJECTED' && view.permissions.canReopen ? (
            <div className="decide" style={{ marginTop: 12 }}>
              <label className="field">Reason for reopening (optional)
                <textarea value={comment} onChange={e => setComment(e.target.value)} placeholder="e.g. The truck is confirmed after all; reviewing again." maxLength={1000} />
              </label>
              <div style={{ marginTop: 10, display: 'flex', gap: 8, alignItems: 'center' }}>
                <button className="btn pri" disabled={busy} onClick={() => setConfirm('reopen')}><Icon name="undo" size={13} /> Reopen for review</button>
                <span className="muted">If the agent writes a revised forecast, it arrives as a new version instead.</span>
              </div>
            </div>
          ) : null} />

          <div className="card">
            <h3>Review history</h3>
            <HistoryTable rows={view.history} />
          </div>
        </>
      )}

      {confirm === 'approve' && f && (
        <ConfirmModal title={`Approve ${f.code}?`} confirmLabel="Approve and allocate" confirmClass="btn ok" busy={approve.isPending}
                      onConfirm={() => approve.mutate()} onCancel={() => setConfirm(null)}>
          Approving locks the forecast as the agent sent it, saves your decision to DB2 and creates the allocation, ready for the user at once.
          The user gets a popup.
        </ConfirmModal>
      )}
      {confirm === 'reject' && f && (
        <ConfirmModal title={`Reject ${f.code}?`} confirmLabel="Reject" confirmClass="btn danger" busy={reject.isPending}
                      onConfirm={() => reject.mutate()} onCancel={() => setConfirm(null)}>
          The forecast stays unallocated and the user gets a popup. It can be reopened for another review cycle later.
          {!comment.trim() && <div className="inline-note warn" style={{ marginTop: 10 }}>Tip: add a comment so the reason is recorded.</div>}
        </ConfirmModal>
      )}
      {confirm === 'reopen' && f && (
        <ConfirmModal title={`Reopen ${f.code}?`} confirmLabel="Reopen for review" busy={reopen.isPending}
                      onConfirm={() => reopen.mutate()} onCancel={() => setConfirm(null)}>
          The forecast goes back to pending review as cycle {f.reviewCycle + 1}.
        </ConfirmModal>
      )}
    </main></div>
  );
}
