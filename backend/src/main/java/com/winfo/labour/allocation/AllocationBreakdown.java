package com.winfo.labour.allocation;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import com.winfo.labour.agent.AgentForecast;
import com.winfo.labour.forecast.Grid;

/**
 * What the Allocation page shows about an approved forecast, derived from the DB2 snapshot (required = recommended_hc,
 * scheduled = static_plan_hc). The forecast is approved as sent, so there are no reallocations or call-ins: the page shows how the
 * schedule covers the approved need, zone by zone, and the windows that stay short or over.
 */
final class AllocationBreakdown {

    private static final int MAX_ROWS = 15;

    private AllocationBreakdown() {}

    static Map<String, Object> of(AgentForecast f) {
        int[][] need = f.required(), staff = f.scheduled();
        Map<String, Object> out = new LinkedHashMap<>();

        long shortHours = 0, overHours = 0;
        List<Map<String, Object>> zones = new ArrayList<>();
        List<Map<String, Object>> shortages = new ArrayList<>(), surpluses = new ArrayList<>();
        int shortRuns = 0, overRuns = 0;
        for (int z = 0; z < f.zones().size(); z++) {
            String name = f.zones().get(z).name();
            long n = 0, met = 0, zShort = 0, zOver = 0;
            for (int h = 0; h < 24; h++) {
                n += need[z][h];
                met += Math.min(need[z][h], staff[z][h]);
                zShort += Math.max(0, need[z][h] - staff[z][h]);
                zOver += Math.max(0, staff[z][h] - need[z][h]);
            }
            shortHours += zShort;
            overHours += zOver;
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("zoneId", f.zones().get(z).id());
            m.put("name", name);
            m.put("needHours", n);
            m.put("coverage", n == 0 ? 100.0 : Math.round(met * 1000.0 / n) / 10.0);
            m.put("shortHours", zShort);
            m.put("surplusHours", zOver);
            zones.add(m);
            shortRuns += runs(f, name, need[z], staff[z], true, shortages);
            overRuns += runs(f, name, need[z], staff[z], false, surpluses);
        }

        Map<String, Object> s = new LinkedHashMap<>();
        s.put("needHours", Grid.sum(need));
        s.put("scheduledHours", Grid.sum(staff));
        s.put("coverage", Grid.coverage(need, staff));
        s.put("shortHours", shortHours);
        s.put("surplusHours", overHours);
        out.put("summary", s);
        out.put("zoneCoverage", zones);
        out.put("shortages", shortages);
        out.put("shortagesMore", Math.max(0, shortRuns - shortages.size()));
        out.put("surpluses", surpluses);
        out.put("surplusesMore", Math.max(0, overRuns - surpluses.size()));
        return out;
    }

    /** Consecutive short (or over) hours form one window; the figure is the peak gap in it ("12p–7p, short by 5"). Returns how many windows the zone has. */
    private static int runs(AgentForecast f, String zone, int[] need, int[] staff, boolean shortSide, List<Map<String, Object>> into) {
        int count = 0, h = 0;
        while (h < 24) {
            int gap = shortSide ? need[h] - staff[h] : staff[h] - need[h];
            if (gap <= 0) { h++; continue; }
            int end = h + 1, peak = gap;
            while (end < 24 && (shortSide ? need[end] - staff[end] : staff[end] - need[end]) > 0) {
                peak = Math.max(peak, shortSide ? need[end] - staff[end] : staff[end] - need[end]);
                end++;
            }
            count++;
            if (into.size() < MAX_ROWS) {
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("zone", zone);
                m.put("window", f.calendar().window(h, end));
                m.put(shortSide ? "shortBy" : "overBy", peak);
                into.add(m);
            }
            h = end;
        }
        return count;
    }
}
