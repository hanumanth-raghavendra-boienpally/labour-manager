package com.winfo.labour.allocation;

import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.stereotype.Service;

import com.winfo.labour.agent.AgentForecast;
import com.winfo.labour.audit.AuditService;
import com.winfo.labour.auth.Session;
import com.winfo.labour.db.Db2;
import com.winfo.labour.db.Rows;
import com.winfo.labour.forecast.ForecastService;
import com.winfo.labour.web.ApiException;

/**
 * Page 2 (user): what happened to the agent's forecast request, read from DB2 only. Read-only: there is no commit step.
 *
 *   PENDING    the store manager has not decided yet
 *   SUPERSEDED the agent sent a newer version before anyone decided
 *   REJECTED   rejected: who, when and the comment; nothing was allocated
 *   ALLOCATED  approved: the forecast allocation card (ready at once), four KPI cards, zone coverage, unfilled shortages and remaining surplus from the DB2 snapshot
 * Every state also carries the request's audit trail (workflow.audit_event).
 */
@Service
public class AllocationService {

    private final Db2 db2;
    private final ForecastService forecasts;
    private final AuditService audit;

    public AllocationService(Db2 db2, ForecastService forecasts, AuditService audit) {
        this.db2 = db2;
        this.forecasts = forecasts;
        this.audit = audit;
    }

    public Map<String, Object> viewLatest(Session session, int dcId, String date) {
        Integer id = forecasts.latestRequestId(dcId, date);
        if (id != null) return view(session, id);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("state", "NO_REQUEST");
        out.put("dcId", dcId);
        out.put("businessDate", ForecastService.validDate(date));
        out.put("dateLabel", Rows.s(db2.one("select to_char(?::date, 'Dy DD Mon YYYY') as l", ForecastService.validDate(date)), "l"));
        return out;
    }

    public Map<String, Object> view(Session session, int requestId) {
        Map<String, Object> r = db2.one("select r.request_id, r.forecast_code, r.status, r.version, r.review_cycle, r.generated_by, "
                + "r.agent_mode, r.generated_at, r.received_at, r.dc_id, r.dc_code, r.dc_name, r.business_date::text as business_date, "
                + "to_char(r.business_date, 'Dy DD Mon YYYY') as date_label, r.required_hours, r.scheduled_hours, r.playbook_id "
                + "from workflow.forecast_request r where r.request_id = ?", requestId);
        if (r == null) throw ApiException.notFound("Forecast request " + requestId + " not found.");
        String status = Rows.s(r, "status");

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("dcId", r.get("dc_id"));
        out.put("businessDate", r.get("business_date"));
        out.put("dateLabel", r.get("date_label"));
        Map<String, Object> req = new LinkedHashMap<>();
        req.put("requestId", r.get("request_id"));
        req.put("code", r.get("forecast_code"));
        req.put("status", status);
        req.put("version", r.get("version"));
        req.put("reviewCycle", r.get("review_cycle"));
        req.put("generatedBy", r.get("generated_by"));
        req.put("agentMode", r.get("agent_mode"));
        req.put("generatedAt", r.get("generated_at"));
        req.put("receivedAt", r.get("received_at"));
        req.put("dcCode", r.get("dc_code"));
        req.put("dcName", r.get("dc_name"));
        req.put("dateLabel", r.get("date_label"));
        req.put("playbookId", r.get("playbook_id"));
        req.put("requiredHours", r.get("required_hours"));
        req.put("scheduledHours", r.get("scheduled_hours"));
        out.put("request", req);

        switch (status) {
            case ForecastService.PENDING -> out.put("state", "PENDING");
            case ForecastService.SUPERSEDED -> out.put("state", "SUPERSEDED");
            case ForecastService.REJECTED -> {
                out.put("state", "REJECTED");
                Map<String, Object> rej = db2.one("select v.decided_at, v.comment, v.review_cycle, u.display_name, u.title "
                        + "from workflow.forecast_review v join workflow.app_user u on u.user_id = v.reviewer_id "
                        + "where v.request_id = ? and v.decision = 'REJECTED' order by v.decided_at desc, v.review_id desc limit 1", requestId);
                Map<String, Object> m = new LinkedHashMap<>();
                if (rej != null) {
                    m.put("by", rej.get("display_name"));
                    m.put("title", rej.get("title"));
                    m.put("at", rej.get("decided_at"));
                    m.put("cycle", rej.get("review_cycle"));
                    m.put("comment", rej.get("comment"));
                }
                out.put("rejection", m);
            }
            default -> addAllocation(requestId, out);
        }
        out.put("audit", audit.forRequest(requestId));
        return out;
    }

    private void addAllocation(int requestId, Map<String, Object> out) {
        Map<String, Object> a = db2.one("select a.allocation_id, a.allocation_code, a.created_at, a.approved_hours, a.scheduled_hours, "
                + "a.coverage, v.decided_at as approved_at, v.comment as approval_comment, u.display_name as approved_by, "
                + "u.title as approver_title from workflow.allocation a "
                + "join workflow.forecast_review v on v.review_id = a.review_id join workflow.app_user u on u.user_id = v.reviewer_id "
                + "where a.request_id = ?", requestId);
        if (a == null) {
            out.put("state", "NOT_ALLOCATED");
            return;
        }
        out.put("state", "ALLOCATED");
        Map<String, Object> alloc = new LinkedHashMap<>();
        alloc.put("allocationId", a.get("allocation_id"));
        alloc.put("code", a.get("allocation_code"));
        alloc.put("createdAt", a.get("created_at"));
        alloc.put("approvedHours", a.get("approved_hours"));
        alloc.put("scheduledHours", a.get("scheduled_hours"));
        alloc.put("coverage", a.get("coverage"));
        alloc.put("approvedBy", a.get("approved_by"));
        alloc.put("approverTitle", a.get("approver_title"));
        alloc.put("approvedAt", a.get("approved_at"));
        alloc.put("approvalComment", a.get("approval_comment"));
        out.put("allocation", alloc);

        // Coverage of the approved need, from the DB2 snapshot taken at approval (the staffing chart stays on the Forecast page).
        AgentForecast f = forecasts.decidedForecast(requestId);
        if (f != null) out.putAll(AllocationBreakdown.of(f));
    }
}
