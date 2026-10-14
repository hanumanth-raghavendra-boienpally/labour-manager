import { useState } from 'react';

const C = { forecastFill: '#f3f4f6', forecastStroke: '#9ca3af', scheduled: '#5b8def', grid: '#eef0f2', ink: '#6b7280' };
const X0 = 40, X1 = 860, Y0 = 200, H = 180;

function niceStep(max) {
  const raw = Math.max(1, max) / 6;
  const pow = Math.pow(10, Math.floor(Math.log10(raw)));
  for (const m of [1, 2, 5, 10]) if (raw <= m * pow) return m * pow;
  return 10 * pow;
}

const gapText = g => (g === 0 ? '0' : g > 0 ? `▲${g} surplus` : `▼${-g} short`);

/**
 * Required vs scheduled staff per hour: forecast required (dashed grey box, agent_playbook_line.recommended_hc) and
 * scheduled (blue bar, agent_playbook_line.static_plan_hc). series = { required: number[24], scheduled: number[24] }.
 */
export function StaffingChart({ hours, series, title }) {
  const [hover, setHover] = useState(null);
  const n = hours.length;
  const all = [...series.required, ...series.scheduled];
  const step = niceStep(Math.max(1, ...all));
  const yMax = Math.max(step, Math.ceil(Math.max(1, ...all) / step) * step);
  const y = v => Y0 - (v / yMax) * H;
  const slot = (X1 - X0) / n;
  const ticks = [];
  for (let v = 0; v <= yMax; v += step) ticks.push(v);

  return (
    <div className="chart-wrap">
      <svg viewBox="0 0 880 230" width="100%" role="img" aria-label={title} onMouseLeave={() => setHover(null)}>
        {ticks.map(t => (
          <g key={t}>
            <line x1={X0} x2={X1} y1={y(t)} y2={y(t)} stroke={C.grid} />
            <text x={X0 - 8} y={y(t) + 4} fontSize="11" textAnchor="end" fill={C.ink}>{t}</text>
          </g>
        ))}
        {hours.map((h, i) => {
          const fx = X0 + i * slot + slot * 0.055;
          const fw = slot * 0.89;
          const sw = slot * 0.42;
          const sx = fx + (fw - sw) / 2;
          const req = series.required[i] ?? 0;
          const sch = series.scheduled[i] ?? 0;
          return (
            <g key={h.index}>
              {hover === i && <rect x={X0 + i * slot} y={10} width={slot} height={Y0 - 10} fill="#f6f7f9" />}
              <rect x={fx} y={y(req)} width={fw} height={Y0 - y(req)} fill={C.forecastFill} stroke={C.forecastStroke} strokeDasharray="3 2" />
              <rect x={sx} y={y(sch)} width={sw} height={Y0 - y(sch)} fill={C.scheduled} />
              <text x={X0 + i * slot + slot / 2} y="218" fontSize="11" textAnchor="middle" fill={C.ink}>{h.label}</text>
              <rect x={X0 + i * slot} y={0} width={slot} height={230} fill="transparent" onMouseEnter={() => setHover(i)} />
            </g>
          );
        })}
        <line x1={X0} x2={X1} y1={Y0} y2={Y0} stroke="#d1d5db" />
      </svg>
      {hover != null && (
        <div className="chart-tip" style={{ left: `calc(${((X0 + hover * slot + slot) / 880) * 100}% + 8px)`, top: 8,
          transform: hover > n * 0.7 ? 'translateX(calc(-100% - 40px))' : undefined }}>
          <div className="h">{hours[hover].label} · shift {hours[hover].shift}</div>
          <div className="r"><span>Forecast required</span><span>{series.required[hover]}</span></div>
          <div className="r"><span>Scheduled</span><span>{series.scheduled[hover]}</span></div>
          <div className="r"><span>Gap</span><span>{gapText(series.scheduled[hover] - series.required[hover])}</span></div>
        </div>
      )}
      <div className="legend">
        <span><span className="sw" style={{ background: C.forecastFill, border: `1px dashed ${C.forecastStroke}` }} />Forecast required</span>
        <span><span className="sw" style={{ background: C.scheduled }} />Scheduled</span>
      </div>
    </div>
  );
}
