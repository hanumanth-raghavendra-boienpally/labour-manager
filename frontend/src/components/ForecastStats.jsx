import { useEffect, useMemo, useState } from 'react';
import { num, pct } from '../lib/format';
import { StaffingChart } from './StaffingChart';

/**
 * The four KPI cards (Forecast required, Scheduled, Critical shortage hours, Overstaffed hours), the zone chips
 * (All zones, Receiving ... Inventory control) and the "Required vs scheduled staff by hour" chart.
 * view = { hours, zones: [{ zoneId, name, required[24], scheduled[24] }], summary } from the API
 * (DB1 live while pending; the DB2 snapshot once decided).
 */
export function ForecastStats({ view, requiredNote = 'From the Labor Agent' }) {
  const [zoneFilter, setZoneFilter] = useState('all');
  const zones = view?.zones ?? [];
  const firstZone = zones[0]?.zoneId;
  // Another DC has other zones: start again from "All zones".
  useEffect(() => { setZoneFilter('all'); }, [firstZone]);

  const visibleZones = zoneFilter === 'all' ? zones : zones.filter(z => z.zoneId === zoneFilter);
  const series = useMemo(() => {
    const add = key => Array.from({ length: 24 }, (_, h) => visibleZones.reduce((sum, z) => sum + (z[key]?.[h] ?? 0), 0));
    return { required: add('required'), scheduled: add('scheduled') };
  }, [visibleZones]);

  const s = view?.summary;
  if (!s) return null;
  return (
    <>
      <div className="kpis">
        <div className="kpi k-b"><div className="dot" /><div className="l">Forecast required</div><div className="v">{num(s.requiredHours)} <small>staff-h</small></div><div className="s">{requiredNote}</div></div>
        <div className="kpi k-g"><div className="dot" /><div className="l">Scheduled</div><div className="v">{num(s.scheduledHours)} <small>staff-h</small></div><div className="s">{pct(s.coverage)} of forecast covered</div></div>
        <div className="kpi k-o"><div className="dot" /><div className="l">Critical shortage hours</div><div className="v">{num(s.criticalHours)}</div><div className="s">Zone-hours short by 2+</div></div>
        <div className="kpi k-p"><div className="dot" /><div className="l">Overstaffed hours</div><div className="v">{num(s.overstaffedHours)}</div><div className="s">Zone-hours over by 2+</div></div>
      </div>

      {zones.length > 0 && (
        <>
          <div className="toolbar">
            <button className={`btn sm ${zoneFilter === 'all' ? 'pri' : ''}`} onClick={() => setZoneFilter('all')}>All zones</button>
            {zones.map(z => (
              <button key={z.zoneId} className={`btn sm ${zoneFilter === z.zoneId ? 'pri' : ''}`} onClick={() => setZoneFilter(z.zoneId)}>{z.name}</button>
            ))}
          </div>
          <div className="card">
            <h3>Required vs scheduled staff by hour · {zoneFilter === 'all' ? 'all zones' : zones.find(z => z.zoneId === zoneFilter)?.name}</h3>
            <StaffingChart hours={view.hours} series={series} title="Forecast required and scheduled staff by hour" />
          </div>
        </>
      )}
    </>
  );
}
