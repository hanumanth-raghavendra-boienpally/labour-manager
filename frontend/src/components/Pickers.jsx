import { useEffect } from 'react';
import { useSearchParams } from 'react-router';
import { useQuery } from '@tanstack/react-query';
import { api } from '../api/http';
import { statusLabel } from '../lib/format';

/**
 * DC and business date, kept in the URL (?dc=1&date=2026-10-10) so notifications and popups can open a specific request.
 * Only DCs the agent plans for, and only dates the agent sent a request for, are offered. With nothing selected it opens
 * what matters to this person: a pending forecast for the store manager, the latest decided forecast for the user.
 * mode: 'forecast' | 'allocation'
 */
export function useDcDate(mode) {
  const [params, setParams] = useSearchParams();
  const dcs = useQuery({ queryKey: ['dcs'], queryFn: () => api('/api/meta/dcs'), refetchInterval: 8_000 });
  const list = dcs.data ?? [];
  const interesting = d => (mode === 'forecast' ? d.pending : d.allocations);
  const preferredDc = (list.find(d => interesting(d) > 0) ?? list.find(d => d.requests > 0) ?? list[0])?.dcId ?? 0;
  const dcId = Number(params.get('dc') ?? preferredDc) || 0;
  const dates = useQuery({
    queryKey: ['dates', dcId],
    queryFn: () => api(`/api/meta/dates?dcId=${dcId}`),
    enabled: dcId > 0,
    refetchInterval: 8_000,
  });
  const dateList = dates.data ?? [];
  const actionable = dateList.find(d => (mode === 'forecast'
    ? d.forecastStatus === 'PENDING_REVIEW'
    : d.forecastStatus === 'APPROVED' || d.forecastStatus === 'REJECTED'));
  const date = params.get('date') ?? (actionable ?? dateList[0])?.date ?? '';

  useEffect(() => {
    if (!dcId || !date) return;
    if (params.get('dc') !== String(dcId) || params.get('date') !== date) {
      setParams({ dc: String(dcId), date }, { replace: true });
    }
  }, [dcId, date, params, setParams]);

  return {
    dcId, date, dcs: list, dates: dateList,
    dc: list.find(d => d.dcId === dcId),
    setDc: id => setParams({ dc: String(id) }),
    setDate: d => setParams({ dc: String(dcId), date: d }),
    /** True once we know the agent has not sent any request for the selected DC. */
    empty: dates.isSuccess && dateList.length === 0,
    ready: dcId > 0 && !!date,
  };
}

export function DcDatePickers({ state, mode }) {
  return (
    <>
      <select className="input" aria-label="Distribution centre" value={state.dcId || ''} onChange={e => state.setDc(Number(e.target.value))}>
        {state.dcs.map(d => (
          <option key={d.dcId} value={d.dcId}>
            {d.dcName} · {d.dcCode}
            {mode === 'forecast' && d.pending > 0 ? ` · ${d.pending} pending` : ''}
          </option>
        ))}
      </select>
      <select className="input" aria-label="Business date" value={state.date} onChange={e => state.setDate(e.target.value)}>
        {state.dates.length === 0 && <option value="">No requests yet</option>}
        {state.dates.map(d => <option key={d.date} value={d.date}>{d.label}{optionSuffix(d)}</option>)}
      </select>
    </>
  );
}

function optionSuffix(d) {
  if (d.allocationStatus) return ' · allocation ready';
  return d.forecastStatus ? ` · ${statusLabel(d.forecastStatus).toLowerCase()}` : '';
}
