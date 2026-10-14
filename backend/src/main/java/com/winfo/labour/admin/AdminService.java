package com.winfo.labour.admin;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;

import com.winfo.labour.agent.AgentPlaybookReader;
import com.winfo.labour.audit.AuditService;
import com.winfo.labour.config.AppSettings;
import com.winfo.labour.db.Db2;
import com.winfo.labour.db.Rows;

/**
 * Admin page: every forecast request with its status, the store manager's decision and its allocation (DB2), the agent's
 * latest writes in DB1 and what the app did with each, and the audit log. Read-only.
 * Reads DB1 and DB2 separately and joins in Java (they may be different databases).
 */
@Service
public class AdminService {

    private final Db2 db2;
    private final AgentPlaybookReader agent;
    private final AuditService audit;
    private final AppSettings settings;

    public AdminService(Db2 db2, AgentPlaybookReader agent, AuditService audit, AppSettings settings) {
        this.db2 = db2;
        this.agent = agent;
        this.audit = audit;
        this.settings = settings;
    }

    public Map<String, Object> overview() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("requestStatuses", settings.requestStatuses());

        out.put("requests", db2.rows("select r.request_id as \"requestId\", r.forecast_code as code, r.dc_id as \"dcId\", r.dc_code as \"dcCode\", "
                + "r.dc_name as \"dcName\", r.business_date::text as \"businessDate\", to_char(r.business_date, 'Dy DD Mon YYYY') as \"dateLabel\", "
                + "r.version, r.status, r.review_cycle as \"reviewCycle\", r.generated_at as \"generatedAt\", r.generated_by as \"generatedBy\", "
                + "r.agent_mode as \"agentMode\", r.received_at as \"receivedAt\", r.playbook_id as \"playbookId\", "
                + "r.required_hours as \"requiredHours\", r.scheduled_hours as \"scheduledHours\", "
                + "lr.decision, lr.display_name as \"decidedBy\", lr.decided_at as \"decidedAt\", lr.comment as \"decisionComment\", "
                + "a.allocation_id as \"allocationId\", a.allocation_code as \"allocationCode\", a.coverage "
                + "from workflow.forecast_request r "
                + "left join lateral (select v.decision, u.display_name, v.decided_at, v.comment from workflow.forecast_review v "
                + "  join workflow.app_user u on u.user_id = v.reviewer_id where v.request_id = r.request_id "
                + "  order by v.decided_at desc, v.review_id desc limit 1) lr on true "
                + "left join workflow.allocation a on a.request_id = r.request_id "
                + "order by r.received_at desc, r.request_id desc limit 100"));

        // Agent writes in DB1, marked with what the app did with each one (DB2).
        Map<String, Map<String, Object>> byKey = new HashMap<>();
        for (Map<String, Object> r : db2.rows("select source_key, forecast_code, status, request_id from workflow.forecast_request")) {
            byKey.put(Rows.s(r, "source_key"), r);
        }
        Map<String, Boolean> ignored = new HashMap<>();
        for (Map<String, Object> r : db2.rows("select distinct source_key from workflow.audit_event where event_type = 'IGNORED' and source_key is not null")) {
            ignored.put(Rows.s(r, "source_key"), true);
        }
        List<Map<String, Object>> dumps = agent.recentDumps(30);
        for (Map<String, Object> d : dumps) {
            Map<String, Object> r = byKey.get(Rows.s(d, "sourceKey"));
            d.put("requestId", r == null ? null : r.get("request_id"));
            d.put("forecastCode", r == null ? null : r.get("forecast_code"));
            d.put("requestStatus", r == null ? null : r.get("status"));
            d.put("ignored", ignored.containsKey(Rows.s(d, "sourceKey")));
            d.put("isRequestStatus", settings.requestStatuses().contains(Rows.s(d, "status")));
        }
        out.put("dumps", dumps);
        out.put("permissions", permissions());
        out.put("integrations", integrations(dumps));
        out.put("audit", audit.latest(80));
        return out;
    }

    /** Role permissions for the forecast and allocation workflow (what each sign-in can do). */
    private static List<Map<String, Object>> permissions() {
        return List.of(
                perm("View AI labour forecast", "Yes", "—", "View"),
                perm("Approve or reject forecast", "Yes", "—", "—"),
                perm("Reopen rejected forecast", "Yes", "—", "—"),
                perm("Allocation run", "On approval", "—", "—"),
                perm("View allocation and outcome", "—", "View", "View"));
    }

    private static Map<String, Object> perm(String capability, String storeManager, String user, String admin) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("capability", capability);
        m.put("storeManager", storeManager);
        m.put("user", user);
        m.put("admin", admin);
        return m;
    }

    /** The systems the workflow touches, with a live status taken from the latest agent write in DB1. */
    private List<Map<String, Object>> integrations(List<Map<String, Object>> dumps) {
        Object last = dumps.isEmpty() ? null : dumps.get(0).get("generatedAt");
        return List.of(
                integration("Labor Agent forecast store (DB1)", "Agent writes agent_playbook + lines; app polls for status "
                        + String.join(" or ", settings.requestStatuses()), last == null ? "Waiting for the agent" : "Last agent write", last),
                integration("Forecast review (DB2)", "Store manager approves, rejects or reopens; comment, snapshot and audit stored", "Live", null),
                integration("Allocation (DB2)", "Created once on approval, final; read-only for the user", "Live", null),
                integration("Notifications", "Popup + bell: store manager (new request), user (decision), admin (bell only)", "Live", null));
    }

    private static Map<String, Object> integration(String system, String mode, String status, Object at) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("system", system);
        m.put("mode", mode);
        m.put("status", status);
        m.put("at", at);
        return m;
    }
}
