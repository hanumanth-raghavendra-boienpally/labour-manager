package com.winfo.labour.agent;

import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.winfo.labour.audit.AuditService;
import com.winfo.labour.auth.Roles;
import com.winfo.labour.db.Db2;
import com.winfo.labour.db.Rows;
import com.winfo.labour.notify.NotificationService;

/**
 * DB1 -> page 1. Registers one agent publication in DB2 as a request waiting for the store manager and notifies
 * the store manager (popup + bell) and the admin (bell).
 *
 *   - Already registered (same source key): nothing happens.
 *   - The previous version for that DC and date is still pending: it becomes SUPERSEDED, the new one is pending.
 *   - The previous version was already approved: the publication is ignored (approved forecasts are final) and audited once.
 */
@Service
public class RequestIntake {

    public static final String AGENT_ROLE = "AGENT";

    private final Db2 db2;
    private final AuditService audit;
    private final NotificationService notifications;

    public RequestIntake(Db2 db2, AuditService audit, NotificationService notifications) {
        this.db2 = db2;
        this.audit = audit;
        this.notifications = notifications;
    }

    /** True when this publication was already registered or already ignored, so the watcher can skip reading DB1 for it. */
    public boolean known(String sourceKey) {
        return db2.intValue("select (select count(*) from workflow.forecast_request where source_key = ?::text) "
                + "+ (select count(*) from workflow.audit_event where event_type = 'IGNORED' and source_key = ?::text)",
                sourceKey, sourceKey) > 0;
    }

    /** @return the new request id, or null when nothing was registered. */
    @Transactional
    public Integer register(AgentForecast f) {
        if (db2.intValue("select count(*) from workflow.forecast_request where source_key = ?::text", f.sourceKey()) > 0) return null;

        Map<String, Object> latest = db2.one(
                "select request_id, forecast_code, version, status from workflow.forecast_request "
                        + "where dc_id = ? and business_date = ?::date order by version desc limit 1 for update",
                f.dcId(), f.businessDate());
        if (latest != null && "APPROVED".equals(Rows.s(latest, "status"))) {
            if (db2.intValue("select count(*) from workflow.audit_event where event_type = 'IGNORED' and source_key = ?::text",
                    f.sourceKey()) == 0) {
                audit.record(f.generatedBy(), AGENT_ROLE, "IGNORED", Rows.i(latest, "request_id"), null, f.sourceKey(),
                        "The agent published playbook #" + f.playbookId() + " again for " + f.dcCode() + " " + f.businessDate()
                                + ", but " + Rows.s(latest, "forecast_code") + " is already approved. Approved forecasts are final; not a new request.");
            }
            return null;
        }

        int version = latest == null ? 1 : Rows.i(latest, "version") + 1;
        String code = "FC-" + f.dcCode() + "-" + f.businessDate().replace("-", "") + "-v" + version;
        if (latest != null && "PENDING_REVIEW".equals(Rows.s(latest, "status"))) {
            db2.exec("update workflow.forecast_request set status = 'SUPERSEDED', row_version = row_version + 1 where request_id = ?",
                    Rows.i(latest, "request_id"));
            audit.record(f.generatedBy(), AGENT_ROLE, "SUPERSEDED", Rows.i(latest, "request_id"), null, f.sourceKey(),
                    Rows.s(latest, "forecast_code") + " was replaced by " + code + " before review (the agent published again).");
            notifications.settleRequestPrompt(Rows.i(latest, "request_id")); // the old version no longer needs a decision
        }

        Map<String, Object> row = db2.one(
                "insert into workflow.forecast_request (forecast_code, source_key, playbook_id, dc_id, dc_code, dc_name, business_date, "
                        + "version, status, generated_at, generated_by, agent_mode, required_hours, scheduled_hours) "
                        + "values (?::text, ?::text, ?, ?, ?::text, ?::text, ?::date, ?, 'PENDING_REVIEW', ?::timestamptz, ?::text, ?::text, ?, ?) "
                        + "returning request_id",
                code, f.sourceKey(), f.playbookId(), f.dcId(), f.dcCode(), f.dcName(), f.businessDate(), version,
                f.generatedAt(), f.generatedBy(), f.agentMode(), f.requiredHours(), f.scheduledHours());
        int id = Rows.i(row, "request_id");

        audit.record(f.generatedBy(), AGENT_ROLE, "RECEIVED", id, null, f.sourceKey(),
                "Agent wrote playbook #" + f.playbookId() + " to DB1 (" + f.agentMode() + " mode); request " + code
                        + " is waiting for the store manager · required " + f.requiredHours() + " staff-h vs scheduled "
                        + f.scheduledHours() + " staff-h");

        String title = "New forecast request: " + code;
        String body = f.generatedBy() + " sent " + code + " for " + f.dcName() + ", " + f.dateLabel() + ": "
                + f.requiredHours() + " staff-h required vs " + f.scheduledHours() + " scheduled. Approve or reject it.";
        notifications.notifyRole(Roles.STORE_MANAGER, NotificationService.REQUEST_RECEIVED, title, body, id, null);
        notifications.notifyRole(Roles.ADMIN, NotificationService.REQUEST_RECEIVED, title, body, id, null);
        return id;
    }
}
