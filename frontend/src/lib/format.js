/** "12 Oct 2026, 10:42" in the viewer's own time zone. */
export function dateTime(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false });
}

export function relative(iso) {
  const diff = (Date.now() - new Date(iso).getTime()) / 1000;
  if (diff < 60) return 'just now';
  if (diff < 3600) return `${Math.floor(diff / 60)} min ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)} h ago`;
  return dateTime(iso);
}

export const pct = v => (v == null ? '—' : `${Math.round(v)}%`);
export const num = v => (v == null ? '—' : Number(v).toLocaleString('en-US'));

export function statusLabel(status) {
  switch (status) {
    case 'PENDING_REVIEW': return 'Pending review';
    case 'APPROVED': return 'Approved';
    case 'REJECTED': return 'Rejected';
    case 'SUPERSEDED': return 'Superseded';
    // An allocation is final as soon as the forecast is approved (stored as COMMITTED in DB2; older rows may say PROPOSED).
    case 'PROPOSED':
    case 'COMMITTED': return 'Allocation ready';
    default: return status ?? '';
  }
}

export function statusPill(status) {
  switch (status) {
    case 'PENDING_REVIEW': return 'pill p-wa';
    case 'APPROVED': return 'pill p-ok';
    case 'REJECTED': return 'pill p-ba';
    case 'PROPOSED':
    case 'COMMITTED': return 'pill p-ok';
    default: return 'pill';
  }
}

/** Newer than a day: the wireframes tag fresh records "NEW". */
export const isNew = iso => !!iso && Date.now() - new Date(iso).getTime() < 24 * 3600 * 1000;
