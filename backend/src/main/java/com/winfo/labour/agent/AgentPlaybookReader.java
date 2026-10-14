package com.winfo.labour.agent;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.concurrent.CompletableFuture;

import org.springframework.stereotype.Component;

import com.winfo.labour.db.Db1;
import com.winfo.labour.db.Rows;
import com.winfo.labour.forecast.ShiftCalendar;

/**
 * Reads what the AI agent wrote into DB1. Never writes.
 *
 *   labor_allocation.agent_playbook       one row per DC and business date: status, generated_at, forecast volume, narrative ...
 *   labor_allocation.agent_playbook_line  zone x clock hour: fcst_workload, recommended_hc (required staff), static_plan_hc (scheduled)
 *
 * One publication is identified by its source key "playbook_id@generated_at": if the agent rewrites the playbook for the
 * same DC and date, generated_at changes and the app treats it as a new version of the request.
 */
@Component
public class AgentPlaybookReader {

    public static final String AGENT_NAME = "Labor Planning & Reallocation Agent";

    /** "17@2026-10-08T23:00:00.000000Z" - computed in SQL so it is exact to the microsecond. */
    static final String SOURCE_KEY =
            "(p.playbook_id || '@' || to_char(p.generated_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS.US\"Z\"'))";

    private final Db1 db1;

    public AgentPlaybookReader(Db1 db1) {
        this.db1 = db1;
    }

    /** Playbooks whose status means "waiting for a decision", oldest first, with how many lines they have so far. */
    public List<Map<String, Object>> publications(List<String> statuses) {
        // statuses are validated in AppSettings (letters and underscores only), so they can be inlined safely.
        String in = "'" + String.join("','", statuses) + "'";
        return db1.rows("select p.playbook_id, p.dc_id, p.business_date::text as business_date, p.status, "
                + SOURCE_KEY + " as source_key, "
                + "(select count(*) from labor_allocation.agent_playbook_line l where l.playbook_id = p.playbook_id)::int as lines "
                + "from labor_allocation.agent_playbook p where p.status in (" + in + ") order by p.generated_at, p.playbook_id");
    }

    /** The source key the playbook has right now, or null if the agent removed it. */
    public String currentSourceKey(int playbookId) {
        Map<String, Object> r = db1.one("select " + SOURCE_KEY + " as k from labor_allocation.agent_playbook p where p.playbook_id = ?", playbookId);
        return r == null ? null : Rows.s(r, "k");
    }

    /** Latest agent dumps in DB1 (any status), newest first, for the admin page. */
    public List<Map<String, Object>> recentDumps(int limit) {
        return db1.rows("select p.playbook_id as \"playbookId\", d.dc_code as \"dcCode\", p.business_date::text as \"businessDate\", "
                + "p.status, p.agent_mode as \"agentMode\", p.generated_at as \"generatedAt\", p.fcst_volume as \"forecastVolume\", "
                + SOURCE_KEY + " as \"sourceKey\", "
                + "(select count(*) from labor_allocation.agent_playbook_line l where l.playbook_id = p.playbook_id)::int as lines "
                + "from labor_allocation.agent_playbook p join labor_allocation.dc d on d.dc_id = p.dc_id "
                + "order by p.generated_at desc, p.playbook_id desc limit ?", limit);
    }

    /** DCs for the pickers (the CONTROL cohort stays on static planning and gets no agent forecasts). */
    public List<Map<String, Object>> agentDcs() {
        return db1.rows("select d.dc_id as \"dcId\", d.dc_code as \"dcCode\", d.dc_name as \"dcName\", d.agent_cohort as cohort "
                + "from labor_allocation.dc d order by d.dc_id");
    }

    /**
     * Everything the Forecast page shows for one playbook, read live from DB1: the AI labour forecast card, the four KPI cards and
     * the staffing chart. Tables: agent_playbook, agent_playbook_line, dc, dc_zone, agent_model_version, shift_definition,
     * carrier_cutoff. Null when the playbook does not exist.
     */
    public AgentForecast read(int playbookId) {
        Map<String, Object> p = db1.one(
                "select p.playbook_id, " + SOURCE_KEY + " as source_key, p.status, p.dc_id, d.dc_code, d.dc_name, "
                        + "p.business_date::text as business_date, to_char(p.business_date, 'Dy DD Mon YYYY') as date_label, "
                        + "p.generated_at, to_char(p.generated_at at time zone d.timezone, 'DD Mon YYYY, HH24:MI') as generated_local, "
                        + "p.agent_mode, p.model_version_id, p.fcst_volume, p.fcst_volume_p10, p.fcst_volume_p90, "
                        + "p.static_plan_hours, p.recommended_hours, p.recommended_vet_hours, p.recommended_vto_hours, p.narrative, "
                        + "mv.component as mv_component, mv.version as mv_version, mv.algorithm as mv_algorithm "
                        + "from labor_allocation.agent_playbook p join labor_allocation.dc d on d.dc_id = p.dc_id "
                        + "left join labor_allocation.agent_model_version mv on mv.model_version_id = p.model_version_id "
                        + "where p.playbook_id = ?", playbookId);
        if (p == null) return null;
        int dcId = Rows.i(p, "dc_id");
        String date = Rows.s(p, "business_date");

        // The database can be far away (every query costs a network round trip), so the independent reads run at the same time.
        CompletableFuture<ShiftCalendar> calF = async(() -> ShiftCalendar.load(db1, dcId));
        CompletableFuture<List<Map<String, Object>>> zonesF = async(() -> db1.rows(
                "select z.zone_id, z.zone_code, z.zone_name, z.primary_skill_code as skill "
                        + "from labor_allocation.dc_zone z where z.dc_id = ? order by z.zone_id", dcId));
        CompletableFuture<List<Map<String, Object>>> linesF = async(() -> db1.rows(
                "select zone_id, local_hour, fcst_workload, recommended_hc, static_plan_hc "
                        + "from labor_allocation.agent_playbook_line where playbook_id = ?", playbookId));
        CompletableFuture<List<Map<String, Object>>> riskF = async(() -> db1.rows(
                "select e->>'zone' as zone, (e->>'local_hour')::int as hh from labor_allocation.agent_playbook p, "
                        + "jsonb_array_elements(case when jsonb_typeof(p.risk_windows) = 'array' then p.risk_windows else '[]'::jsonb end) e "
                        + "where p.playbook_id = ? and e->>'local_hour' ~ '^[0-9]+$'", playbookId));
        CompletableFuture<Map<String, Object>> cutF = async(() -> db1.one(
                "select count(*)::int as n, to_char(max(pull_time), 'HH24:MI') as last_pull "
                        + "from labor_allocation.carrier_cutoff where dc_id = ?", dcId));
        ShiftCalendar cal = await(calF);

        List<AgentForecast.Zone> zones = new ArrayList<>();
        Map<Integer, Integer> zi = new HashMap<>();
        for (Map<String, Object> z : await(zonesF)) {
            zi.put(Rows.i(z, "zone_id"), zones.size());
            zones.add(new AgentForecast.Zone(Rows.i(z, "zone_id"), Rows.s(z, "zone_code"), Rows.s(z, "zone_name"), Rows.s(z, "skill")));
        }
        int nz = zones.size();
        int[][] workload = new int[nz][24], required = new int[nz][24], scheduled = new int[nz][24];
        for (Map<String, Object> l : await(linesF)) {
            Integer z = zi.get(Rows.i(l, "zone_id"));
            if (z == null) continue; // a line for a zone of another DC: ignored rather than shown under the wrong DC
            int h = cal.hourIndex(Rows.i(l, "local_hour"));
            workload[z][h] = Rows.i(l, "fcst_workload");
            required[z][h] = Rows.i(l, "recommended_hc");
            scheduled[z][h] = Rows.i(l, "static_plan_hc");
        }

        String model = "Workload forecaster";
        if (Rows.s(p, "mv_component") != null) {
            String c = Rows.s(p, "mv_component").toLowerCase().replace('_', ' ');
            model = Character.toUpperCase(c.charAt(0)) + c.substring(1) + " v" + Rows.s(p, "mv_version")
                    + " (" + Rows.s(p, "mv_algorithm").toLowerCase() + ")";
        }
        String workloadSource = model + " · agent_playbook #" + playbookId + ", published " + Rows.s(p, "generated_local") + " DC time";

        String scheduleSource = "Static plan carried in the agent playbook (static_plan_hc)";

        int active = 0, first = 24, last = -1;
        for (int z = 0; z < nz; z++) {
            boolean any = false;
            for (int h = 0; h < 24; h++) {
                if (required[z][h] > 0 || scheduled[z][h] > 0) { any = true; first = Math.min(first, h); last = Math.max(last, h); }
            }
            if (any) active++;
        }
        String coverage = active + " zones · " + (last < 0 ? "no hours"
                : last - first == 23 ? "24 h from " + cal.label(0) : cal.window(first, last + 1));

        AgentForecast result = new AgentForecast(playbookId, Rows.s(p, "source_key"), Rows.s(p, "status"), dcId, Rows.s(p, "dc_code"),
                Rows.s(p, "dc_name"), date, Rows.s(p, "date_label"), Rows.s(p, "generated_at"), AGENT_NAME, Rows.s(p, "agent_mode"),
                workloadSource, scheduleSource, coverage, drivers(p, await(riskF), await(cutF)), Rows.s(p, "narrative"),
                cal, zones, workload, required, scheduled);
        if (BY_KEY.size() > 50) BY_KEY.clear();
        BY_KEY.put(result.sourceKey(), result);
        return result;
    }

    /**
     * The forecast of one exact publication. A publication is immutable (the agent publishes a change under a new
     * generated_at, hence a new source key), so what was read once for that key is still right and costs no database trip.
     */
    public AgentForecast readForKey(int playbookId, String sourceKey) {
        AgentForecast hit = BY_KEY.get(sourceKey);
        return hit != null ? hit : read(playbookId);
    }

    private static final Map<String, AgentForecast> BY_KEY = new java.util.concurrent.ConcurrentHashMap<>();
    private static final java.util.concurrent.ExecutorService POOL = java.util.concurrent.Executors.newFixedThreadPool(6, r -> {
        Thread t = new Thread(r, "db1-read");
        t.setDaemon(true);
        return t;
    });

    private static <T> CompletableFuture<T> async(java.util.function.Supplier<T> s) {
        return CompletableFuture.supplyAsync(s, POOL);
    }

    private static <T> T await(CompletableFuture<T> f) {
        try {
            return f.join();
        } catch (java.util.concurrent.CompletionException e) {
            if (e.getCause() instanceof RuntimeException re) throw re;
            throw e;
        }
    }

    /** The chips under the card: what drives this forecast. */
    private List<String> drivers(Map<String, Object> p, List<Map<String, Object>> riskRows, Map<String, Object> cut) {
        List<String> chips = new ArrayList<>();
        chips.add("Forecast volume " + n(Rows.i(p, "fcst_volume")) + " units (P10 " + n(Rows.i(p, "fcst_volume_p10")) + " – P90 "
                + n(Rows.i(p, "fcst_volume_p90")) + ")");
        chips.add("Static plan " + h(Rows.d(p, "static_plan_hours")) + " h → agent recommends " + h(Rows.d(p, "recommended_hours")) + " h");
        double vet = Rows.d(p, "recommended_vet_hours"), vto = Rows.d(p, "recommended_vto_hours");
        if (vet > 0 || vto > 0) chips.add("Voluntary extra time " + h(vet) + " h · voluntary time off " + h(vto) + " h");

        Map<String, TreeSet<Integer>> risk = new TreeMap<>();
        for (Map<String, Object> r : riskRows) {
            if (Rows.s(r, "zone") != null) risk.computeIfAbsent(Rows.s(r, "zone"), k -> new TreeSet<>()).add(Rows.i(r, "hh"));
        }
        for (Map.Entry<String, TreeSet<Integer>> e : risk.entrySet()) {
            List<String> hours = new ArrayList<>();
            for (int hh : e.getValue()) hours.add(ShiftCalendar.clockLabel(hh));
            chips.add("Risk window " + e.getKey() + " " + String.join(", ", hours));
        }

        if (cut != null && Rows.i(cut, "n") > 0) chips.add(Rows.i(cut, "n") + " carrier cut-offs · last pull " + ampm(Rows.s(cut, "last_pull")));
        return chips;
    }

    private static String n(int v) {
        return String.format("%,d", v);
    }

    private static String h(double v) {
        return v == Math.rint(v) ? String.valueOf((long) v) : String.format("%.1f", v);
    }

    /** "06:30" -> "6:30a". */
    static String ampm(String hhmm) {
        if (hhmm == null || hhmm.length() < 5) return "";
        int hour = Integer.parseInt(hhmm.substring(0, 2));
        String m = hhmm.substring(3, 5);
        String base = ShiftCalendar.clockLabel(hour);
        String suffix = base.substring(base.length() - 1);
        String hh = base.substring(0, base.length() - 1);
        return "00".equals(m) ? base : hh + ":" + m + suffix;
    }
}
