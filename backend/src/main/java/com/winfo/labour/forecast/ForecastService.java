package com.winfo.labour.forecast;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.winfo.labour.agent.AgentForecast;
import com.winfo.labour.agent.AgentPlaybookReader;
import com.winfo.labour.audit.AuditService;
import com.winfo.labour.auth.Roles;
import com.winfo.labour.auth.Session;
import com.winfo.labour.db.Db2;
import com.winfo.labour.db.Rows;
import com.winfo.labour.notify.NotificationService;
import com.winfo.labour.web.ApiException;

/**
 * Page 1 (store manager): the AI labour forecast the agent wrote into DB1, and the decision on it.
 *
 *   Pending request   -> the forecast card, the four KPI cards and the staffing chart are read live from DB1
 *                        (agent_playbook / agent_playbook_line).
 *   Approve / reject  -> the decision, the comment and a snapshot of the forecast are written to DB2. Approving also creates the
 *                        forecast allocation, which is final at once (status COMMITTED in DB2, shown as "Ready"). The user and
 *                        the admin are notified.
 *   Decided request   -> shown from the DB2 snapshot (exactly what was decided, even if the agent rewrites DB1 later).
 */
@Service
public class ForecastService {

    public static final String PENDING = "PENDING_REVIEW";
    public static final String APPROVED = "APPROVED";
    public static final String REJECTED = "REJECTED";
    public static final String SUPERSEDED = "SUPERSEDED";

    /** workflow.allocation.status for an allocation that is final. There is no separate commit step: approval makes it ready. */
    public static final String ALLOCATION_READY = "COMMITTED";

    private final Db2 db2;
    private final AgentPlaybookReader agent;
    private final AuditService audit;
    private final NotificationService notifications;

    public ForecastService(Db2 db2, AgentPlaybookReader agent, AuditService audit, NotificationService notifications) {
        this.db2 = db2;
        this.agent = agent;
        this.audit = audit;
        this.notifications = notifications;
    }

    // ------------------------------------------------------------------ read

    /** Latest request version for a DC and business date, or null. */
    public Integer latestRequestId(int dcId, String date) {
        Map<String, Object> r = db2.one("select request_id from workflow.forecast_request where dc_id = ? and business_date = ?::date "
                + "order by version desc limit 1", dcId, validDate(date));
        return r == null ? null : Rows.i(r, "request_id");
    }

    public Map<String, Object> viewLatest(Session session, int dcId, String date) {
        Integer id = latestRequestId(dcId, date);
        if (id != null) return view(session, id);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("forecast", null);
        out.put("dcId", dcId);
        out.put("businessDate", validDate(date));
        out.put("dateLabel", Rows.s(db2.one("select to_char(?::date, 'Dy DD Mon YYYY') as l", validDate(date)), "l"));
        out.put("permissions", Map.of("canReview", false, "canReopen", false));
        return out;
    }

    public Map<String, Object> view(Session session, int requestId) {
        Map<String, Object> req = request(requestId, false);
        String status = Rows.s(req, "status");
        String currentKey = agent.currentSourceKey(Rows.i(req, "playbook_id"));
        boolean current = Rows.s(req, "source_key").equals(currentKey);

        // Which forecast to show: the DB2 snapshot once decided, otherwise DB1 live.
        AgentForecast f = snapshot(req);
        String dataSource = "DB2";
        if (f == null && current) {
            f = agent.readForKey(Rows.i(req, "playbook_id"), Rows.s(req, "source_key"));
            dataSource = "DB1";
            if (f != null && !Rows.s(req, "source_key").equals(f.sourceKey())) { f = null; current = false; }
        }
        String notice = null;
        if (!current && !SUPERSEDED.equals(status) && !APPROVED.equals(status)) {
            notice = currentKey == null
                    ? "The agent has removed this playbook from DB1."
                    : "The agent has written a newer version of this playbook to DB1. It appears here as a new request within a few seconds.";
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("dcId", req.get("dc_id"));
        out.put("businessDate", req.get("business_date"));
        out.put("dateLabel", req.get("date_label"));
        out.put("forecast", header(req, f, dataSource, current));
        out.put("notice", notice);
        if (f != null) out.putAll(stats(f));

        Map<String, Object> approval = db2.one(
                "select r.review_cycle, r.decided_at, r.comment, u.display_name, u.title from workflow.forecast_review r "
                        + "join workflow.app_user u on u.user_id = r.reviewer_id where r.request_id = ? and r.decision = 'APPROVED'", requestId);
        if (approval != null) {
            Map<String, Object> a = new LinkedHashMap<>();
            a.put("by", approval.get("display_name"));
            a.put("title", approval.get("title"));
            a.put("at", approval.get("decided_at"));
            a.put("cycle", approval.get("review_cycle"));
            a.put("comment", approval.get("comment"));
            out.put("approval", a);
        } else {
            out.put("approval", null);
        }
        out.put("rejection", REJECTED.equals(status) ? lastRejection(requestId) : null);
        out.put("allocation", allocationSummary(requestId));
        out.put("history", history(requestId));

        boolean manager = session.is(Roles.STORE_MANAGER);
        boolean latest = isLatest(req);
        Map<String, Object> perms = new LinkedHashMap<>();
        perms.put("canReview", manager && PENDING.equals(status) && current && f != null);
        perms.put("canReopen", manager && REJECTED.equals(status) && latest && current);
        out.put("permissions", perms);
        return out;
    }

    /**
     * The four KPI cards and the staffing chart of one forecast: "hours" (the chart's x axis), "zones" (one row per zone with
     * required and scheduled staff for each of the 24 hours: the zone chips filter on these) and "summary" (the four cards).
     */
    public static Map<String, Object> stats(AgentForecast f) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("hours", f.calendar().hoursForUi());
        List<Map<String, Object>> zones = new ArrayList<>();
        for (int z = 0; z < f.zones().size(); z++) {
            AgentForecast.Zone zone = f.zones().get(z);
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("zoneId", zone.id());
            m.put("name", zone.name());
            m.put("required", f.required()[z]);
            m.put("scheduled", f.scheduled()[z]);
            zones.add(m);
        }
        out.put("zones", zones);
        Map<String, Object> s = new LinkedHashMap<>();
        s.put("requiredHours", Grid.sum(f.required()));
        s.put("scheduledHours", Grid.sum(f.scheduled()));
        s.put("coverage", Grid.coverage(f.required(), f.scheduled()));
        s.put("criticalHours", Grid.criticalCount(f.required(), f.scheduled()));
        s.put("overstaffedHours", Grid.overstaffedCount(f.required(), f.scheduled()));
        out.put("summary", s);
        return out;
    }

    private Map<String, Object> header(Map<String, Object> req, AgentForecast f, String dataSource, boolean current) {
        Map<String, Object> h = new LinkedHashMap<>();
        h.put("requestId", req.get("request_id"));
        h.put("code", req.get("forecast_code"));
        h.put("dcId", req.get("dc_id"));
        h.put("dcCode", req.get("dc_code"));
        h.put("dcName", req.get("dc_name"));
        h.put("businessDate", req.get("business_date"));
        h.put("dateLabel", req.get("date_label"));
        h.put("version", req.get("version"));
        h.put("status", req.get("status"));
        h.put("reviewCycle", req.get("review_cycle"));
        h.put("rowVersion", req.get("row_version"));
        h.put("generatedAt", req.get("generated_at"));
        h.put("generatedBy", req.get("generated_by"));
        h.put("agentMode", req.get("agent_mode"));
        h.put("receivedAt", req.get("received_at"));
        h.put("playbookId", req.get("playbook_id"));
        h.put("requiredHours", req.get("required_hours"));
        h.put("scheduledHours", req.get("scheduled_hours"));
        h.put("workloadSource", f == null ? null : f.workloadSource());
        h.put("scheduleSource", f == null ? null : f.scheduleSource());
        h.put("coverage", f == null ? null : f.coverage());
        h.put("drivers", f == null ? List.of() : f.drivers());
        h.put("narrative", f == null ? null : f.narrative());
        h.put("dataSource", f == null ? null : dataSource);
        h.put("currentInDb1", current);
        h.put("isLatest", isLatest(req));
        return h;
    }

    private Map<String, Object> lastRejection(int requestId) {
        Map<String, Object> r = db2.one(
                "select r.review_cycle, r.decided_at, r.comment, u.display_name, u.title from workflow.forecast_review r "
                        + "join workflow.app_user u on u.user_id = r.reviewer_id where r.request_id = ? and r.decision = 'REJECTED' "
                        + "order by r.decided_at desc, r.review_id desc limit 1", requestId);
        if (r == null) return null;
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("by", r.get("display_name"));
        m.put("title", r.get("title"));
        m.put("at", r.get("decided_at"));
        m.put("cycle", r.get("review_cycle"));
        m.put("comment", r.get("comment"));
        return m;
    }

    private Map<String, Object> allocationSummary(int requestId) {
        Map<String, Object> a = db2.one("select allocation_id, allocation_code, created_at, coverage from workflow.allocation where request_id = ?",
                requestId);
        if (a == null) return null;
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("allocationId", a.get("allocation_id"));
        m.put("code", a.get("allocation_code"));
        m.put("createdAt", a.get("created_at"));
        m.put("coverage", a.get("coverage"));
        return m;
    }

    /** Review history of one request (DB2): received, each decision with its comment, and the allocation. Newest first. */
    public List<Map<String, Object>> history(int requestId) {
        return db2.rows(
                "select h.\"at\", h.\"cycle\", h.\"action\", h.\"actor\", h.\"comment\" from ("
                        + " select f.received_at as \"at\", 1 as \"cycle\", 'Received' as \"action\", "
                        + "   f.generated_by || coalesce(' · ' || lower(f.agent_mode) || ' mode', '') as \"actor\", "
                        + "   'Agent wrote playbook #' || f.playbook_id || ' to DB1 (' || to_char(f.generated_at, 'DD Mon YYYY HH24:MI') "
                        + "     || ' UTC); request v' || f.version || ' sent to the store manager' as \"comment\", 0 as seq "
                        + "   from workflow.forecast_request f where f.request_id = ? "
                        + " union all "
                        + " select r.decided_at, r.review_cycle, initcap(r.decision), u.display_name, coalesce(r.comment, ''), 1 "
                        + "   from workflow.forecast_review r join workflow.app_user u on u.user_id = r.reviewer_id "
                        + "   where r.request_id = ? "
                        + " union all "
                        + " select a.created_at, rv.review_cycle, 'Allocated', 'Allocation service', "
                        + "   a.allocation_code || ' ready in DB2 · schedule covers ' || round(a.coverage) || '% of the approved need', 2 "
                        + "   from workflow.allocation a join workflow.forecast_review rv on rv.review_id = a.review_id where a.request_id = ? "
                        + ") h order by h.\"at\" desc, h.seq desc", requestId, requestId, requestId);
    }

    // ------------------------------------------------------------------ DB2 snapshot

    /** The forecast of a request as it was decided (DB2 snapshot), or null while it is still pending. */
    public AgentForecast decidedForecast(int requestId) {
        return snapshot(request(requestId, false));
    }

    /** The forecast as it was decided, rebuilt from the DB2 snapshot, or null if there is none. */
    AgentForecast snapshot(Map<String, Object> req) {
        int requestId = Rows.i(req, "request_id");
        Map<String, Object> s = db2.one("select * from workflow.forecast_snapshot where request_id = ?", requestId);
        if (s == null) return null;
        ShiftCalendar cal = ShiftCalendar.ofDayStart(Rows.i(s, "day_start_hour"));
        List<Map<String, Object>> lines = db2.rows("select * from workflow.forecast_snapshot_line where request_id = ? "
                + "order by zone_order, hour_index", requestId);
        List<AgentForecast.Zone> zones = new ArrayList<>();
        Map<Integer, Integer> zi = new LinkedHashMap<>();
        for (Map<String, Object> l : lines) {
            int id = Rows.i(l, "zone_id");
            if (!zi.containsKey(id)) {
                zi.put(id, zones.size());
                zones.add(new AgentForecast.Zone(id, Rows.s(l, "zone_code"), Rows.s(l, "zone_name"), Rows.s(l, "skill")));
            }
        }
        int nz = zones.size();
        int[][] workload = new int[nz][24], required = new int[nz][24], scheduled = new int[nz][24];
        for (Map<String, Object> l : lines) {
            int z = zi.get(Rows.i(l, "zone_id")), h = Rows.i(l, "hour_index");
            workload[z][h] = Rows.i(l, "workload");
            required[z][h] = Rows.i(l, "required_staff");
            scheduled[z][h] = Rows.i(l, "scheduled_staff");
        }
        String drivers = Rows.s(s, "drivers");
        return new AgentForecast(Rows.i(req, "playbook_id"), Rows.s(req, "source_key"), null, Rows.i(req, "dc_id"),
                Rows.s(req, "dc_code"), Rows.s(req, "dc_name"), Rows.s(req, "business_date"), Rows.s(req, "date_label"),
                Rows.s(req, "generated_at"), Rows.s(req, "generated_by"), Rows.s(req, "agent_mode"), Rows.s(s, "workload_source"),
                Rows.s(s, "schedule_source"), Rows.s(s, "coverage"),
                drivers == null || drivers.isBlank() ? List.of() : List.of(drivers.split("\n")), Rows.s(s, "narrative"),
                cal, zones, workload, required, scheduled);
    }

    /** Copies the forecast into DB2 at decision time. approved = true writes approved_staff (= the forecast, no changes). */
    private void writeSnapshot(int requestId, int reviewId, AgentForecast f, boolean approved) {
        db2.exec("delete from workflow.forecast_snapshot where request_id = ?", requestId);
        db2.exec("insert into workflow.forecast_snapshot (request_id, review_id, workload_source, schedule_source, coverage, drivers, "
                        + "narrative, day_start_hour, required_hours, approved_hours, scheduled_hours) "
                        + "values (?, ?, ?::text, ?::text, ?::text, ?::text, ?::text, ?, ?, ?::int, ?)",
                requestId, reviewId, f.workloadSource(), f.scheduleSource(), f.coverage(), String.join("\n", f.drivers()), f.narrative(),
                f.calendar().dayStartHour(), f.requiredHours(), approved ? f.requiredHours() : null, f.scheduledHours());
        StringBuilder sql = new StringBuilder("insert into workflow.forecast_snapshot_line (request_id, zone_id, zone_order, zone_code, "
                + "zone_name, skill, hour_index, local_hour, shift_code, workload, required_staff, scheduled_staff, approved_staff) values ");
        List<Object> args = new ArrayList<>();
        for (int z = 0; z < f.zones().size(); z++) {
            AgentForecast.Zone zone = f.zones().get(z);
            for (int h = 0; h < 24; h++) {
                if (!args.isEmpty()) sql.append(',');
                sql.append("(?, ?, ?, ?::text, ?::text, ?::text, ?, ?, ?::text, ?, ?, ?, ?::int)");
                args.add(requestId);
                args.add(zone.id());
                args.add(z);
                args.add(zone.code());
                args.add(zone.name());
                args.add(zone.skill() == null ? "" : zone.skill());
                args.add(h);
                args.add(f.calendar().localHour(h));
                args.add(f.calendar().shiftAt(h).code());
                args.add(f.workload()[z][h]);
                args.add(f.required()[z][h]);
                args.add(f.scheduled()[z][h]);
                args.add(approved ? f.required()[z][h] : null);
            }
        }
        if (!args.isEmpty()) db2.exec(sql.toString(), args.toArray());
    }

    // ------------------------------------------------------------------ decisions

    /** Body: { rowVersion, comment? }. Approves the forecast as the agent sent it and creates the allocation (ready at once). */
    @Transactional
    public Map<String, Object> approve(Session session, int requestId, Map<String, Object> body) {
        Map<String, Object> req = request(requestId, true);
        guardPending(req, "approved");
        guardVersion(req, body);
        AgentForecast f = currentForecast(req);
        String comment = blankToNull(Rows.s(body, "comment"));
        String code = Rows.s(req, "forecast_code");

        int n = db2.exec("update workflow.forecast_request set status = 'APPROVED', row_version = row_version + 1 "
                + "where request_id = ? and row_version = ? and status = 'PENDING_REVIEW'", requestId, Rows.i(req, "row_version"));
        if (n == 0) throw ApiException.conflict("This forecast changed since you opened it. Refresh and review again.");
        int cycle = Rows.i(req, "review_cycle");
        int reviewId = Rows.i(db2.one("insert into workflow.forecast_review (request_id, review_cycle, decision, reviewer_id, comment) "
                + "values (?, ?, 'APPROVED', ?, ?::text) returning review_id", requestId, cycle, session.userId(), comment), "review_id");
        writeSnapshot(requestId, reviewId, f, true);
        audit.record(session.displayName(), session.role(), "APPROVED", requestId, null, Rows.s(req, "source_key"),
                "Approved " + code + " (cycle " + cycle + ")" + (comment != null ? "; comment: " + comment : ""));

        // The forecast allocation (DB2): created once, automatically, on approval, and final at once.
        int allocationId = Rows.i(db2.one("select nextval('workflow.allocation_id_seq')::int as id"), "id");
        String allocationCode = "ALLOC-" + Rows.s(req, "dc_code") + "-" + Rows.s(req, "business_date").substring(5).replace("-", "")
                + "-" + String.format("%03d", allocationId);
        double coverage = Grid.coverage(f.required(), f.scheduled());
        db2.exec("insert into workflow.allocation (allocation_id, allocation_code, request_id, review_id, status, changes, "
                        + "approved_hours, scheduled_hours, coverage) values (?, ?::text, ?, ?, ?::text, 0, ?, ?, ?::numeric)",
                allocationId, allocationCode, requestId, reviewId, ALLOCATION_READY, f.requiredHours(), f.scheduledHours(), coverage);
        audit.record("Allocation service", "SYSTEM", "ALLOCATED", requestId, allocationId, Rows.s(req, "source_key"),
                "Allocation " + allocationCode + " ready for " + code + " · approved need " + f.requiredHours()
                        + " staff-h, schedule covers " + Math.round(coverage) + "%");

        notifications.settleRequestPrompt(requestId);
        String title = "Forecast approved · " + code;
        String text = session.displayName() + " approved " + code + " for " + Rows.s(req, "dc_name") + ", " + Rows.s(req, "date_label")
                + ". Allocation " + allocationCode + " is ready.";
        notifications.notifyRole(Roles.ALLOCATOR, NotificationService.FORECAST_APPROVED, title, text, requestId, allocationId);
        notifications.notifyRole(Roles.ADMIN, NotificationService.FORECAST_APPROVED, title, text, requestId, allocationId);
        return view(session, requestId);
    }

    /** Body: { rowVersion, comment? }. Nothing is allocated. */
    @Transactional
    public Map<String, Object> reject(Session session, int requestId, Map<String, Object> body) {
        Map<String, Object> req = request(requestId, true);
        guardPending(req, "rejected");
        guardVersion(req, body);
        AgentForecast f = currentForecast(req);
        String comment = blankToNull(Rows.s(body, "comment"));
        String code = Rows.s(req, "forecast_code");
        int n = db2.exec("update workflow.forecast_request set status = 'REJECTED', row_version = row_version + 1 "
                + "where request_id = ? and row_version = ? and status = 'PENDING_REVIEW'", requestId, Rows.i(req, "row_version"));
        if (n == 0) throw ApiException.conflict("This forecast changed since you opened it. Refresh and review again.");
        int cycle = Rows.i(req, "review_cycle");
        int reviewId = Rows.i(db2.one("insert into workflow.forecast_review (request_id, review_cycle, decision, reviewer_id, comment) "
                + "values (?, ?, 'REJECTED', ?, ?::text) returning review_id", requestId, cycle, session.userId(), comment), "review_id");
        writeSnapshot(requestId, reviewId, f, false);
        audit.record(session.displayName(), session.role(), "REJECTED", requestId, null, Rows.s(req, "source_key"),
                "Rejected " + code + " (cycle " + cycle + ")" + (comment != null ? "; comment: " + comment : ""));
        notifications.settleRequestPrompt(requestId);
        String title = "Forecast rejected · " + code;
        String text = session.displayName() + " rejected " + code + " for " + Rows.s(req, "dc_name") + ", " + Rows.s(req, "date_label")
                + (comment != null ? ": \"" + comment + "\"" : "") + ". No allocation was made.";
        notifications.notifyRole(Roles.ALLOCATOR, NotificationService.FORECAST_REJECTED, title, text, requestId, null);
        notifications.notifyRole(Roles.ADMIN, NotificationService.FORECAST_REJECTED, title, text, requestId, null);
        return view(session, requestId);
    }

    /** Body: { rowVersion, comment? }. Rejected -> pending again, review cycle + 1. */
    @Transactional
    public Map<String, Object> reopen(Session session, int requestId, Map<String, Object> body) {
        Map<String, Object> req = request(requestId, true);
        String code = Rows.s(req, "forecast_code");
        if (!REJECTED.equals(Rows.s(req, "status"))) {
            throw ApiException.conflict("Only a rejected forecast can be reopened; " + code + " is "
                    + Rows.s(req, "status").toLowerCase().replace('_', ' ') + ".");
        }
        if (!isLatest(req)) throw ApiException.conflict(code + " has a newer version. Review that one instead.");
        guardVersion(req, body);
        currentForecast(req);
        String comment = blankToNull(Rows.s(body, "comment"));
        int cycle = Rows.i(req, "review_cycle") + 1;
        int n = db2.exec("update workflow.forecast_request set status = 'PENDING_REVIEW', review_cycle = ?, row_version = row_version + 1 "
                + "where request_id = ? and row_version = ? and status = 'REJECTED'", cycle, requestId, Rows.i(req, "row_version"));
        if (n == 0) throw ApiException.conflict("This forecast changed since you opened it. Refresh and try again.");
        db2.exec("insert into workflow.forecast_review (request_id, review_cycle, decision, reviewer_id, comment) values (?, ?, 'REOPENED', ?, ?::text)",
                requestId, cycle, session.userId(), comment);
        db2.exec("delete from workflow.forecast_snapshot where request_id = ?", requestId); // pending again: read live from DB1
        audit.record(session.displayName(), session.role(), "REOPENED", requestId, null, Rows.s(req, "source_key"),
                "Reopened " + code + " for review (cycle " + cycle + ")" + (comment != null ? "; comment: " + comment : ""));
        String text = session.displayName() + " reopened " + code + " for another review (cycle " + cycle + ").";
        notifications.notifyRole(Roles.ALLOCATOR, NotificationService.FORECAST_REOPENED, "Forecast reopened · " + code, text, requestId, null);
        notifications.notifyRole(Roles.ADMIN, NotificationService.FORECAST_REOPENED, "Forecast reopened · " + code, text, requestId, null);
        return view(session, requestId);
    }

    // ------------------------------------------------------------------ helpers

    private Map<String, Object> request(int requestId, boolean lock) {
        Map<String, Object> r = db2.one("select r.*, r.business_date::text as business_date, "
                + "to_char(r.business_date, 'Dy DD Mon YYYY') as date_label from workflow.forecast_request r where r.request_id = ?"
                + (lock ? " for update" : ""), requestId);
        if (r == null) throw ApiException.notFound("Forecast request " + requestId + " not found.");
        return r;
    }

    private boolean isLatest(Map<String, Object> req) {
        return db2.intValue("select count(*) from workflow.forecast_request where dc_id = ? and business_date = ?::date and version > ?",
                Rows.i(req, "dc_id"), Rows.s(req, "business_date"), Rows.i(req, "version")) == 0;
    }

    /** The forecast as DB1 holds it now; 409 when the agent has replaced or removed this publication. */
    private AgentForecast currentForecast(Map<String, Object> req) {
        AgentForecast f = agent.read(Rows.i(req, "playbook_id"));
        if (f == null) throw ApiException.conflict("The agent has removed playbook #" + Rows.i(req, "playbook_id") + " from DB1.");
        if (!Rows.s(req, "source_key").equals(f.sourceKey())) {
            throw ApiException.conflict("The agent has written a newer version of this forecast to DB1 since it was sent. "
                    + "Refresh: the new version arrives as a new request within a few seconds.");
        }
        return f;
    }

    private void guardPending(Map<String, Object> req, String action) {
        String status = Rows.s(req, "status");
        if (PENDING.equals(status)) return;
        String code = Rows.s(req, "forecast_code");
        throw ApiException.conflict(switch (status) {
            case APPROVED -> code + " is already approved; it cannot be " + action + " again.";
            case REJECTED -> code + " was rejected. Reopen it before you review it again.";
            case SUPERSEDED -> code + " was replaced by a newer version from the agent.";
            default -> code + " is " + status + ".";
        });
    }

    private static void guardVersion(Map<String, Object> req, Map<String, Object> body) {
        Integer rowVersion = Rows.iOrNull(body, "rowVersion");
        if (rowVersion == null) throw ApiException.badRequest("rowVersion is required.");
        if (rowVersion != Rows.i(req, "row_version")) {
            throw ApiException.conflict("This forecast changed since you opened it. Refresh and review again.");
        }
    }

    public static String validDate(String date) {
        try {
            return java.time.LocalDate.parse(date).toString();
        } catch (RuntimeException e) {
            throw ApiException.badRequest("Business date must look like 2026-10-09.");
        }
    }

    static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
