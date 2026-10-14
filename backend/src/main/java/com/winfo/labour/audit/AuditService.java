package com.winfo.labour.audit;

import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;

import com.winfo.labour.db.Db2;

/** Writes to the append-only DB2 table workflow.audit_event. */
@Service
public class AuditService {

    private final Db2 db2;

    public AuditService(Db2 db2) {
        this.db2 = db2;
    }

    public void record(String actor, String actorRole, String eventType, Integer requestId, Integer allocationId,
                       String sourceKey, String detail) {
        db2.exec("insert into workflow.audit_event (actor, actor_role, event_type, request_id, allocation_id, source_key, detail) "
                        + "values (?::text, ?::text, ?::text, ?::int, ?::int, ?::text, ?::text)",
                actor, actorRole, eventType, requestId, allocationId, sourceKey, detail);
    }

    public List<Map<String, Object>> latest(int limit) {
        return db2.rows("select a.event_id as \"eventId\", a.occurred_at as \"occurredAt\", a.actor, a.actor_role as \"actorRole\", "
                + "a.event_type as \"eventType\", a.detail, r.forecast_code as \"forecastCode\", r.dc_code as \"dcCode\" "
                + "from workflow.audit_event a left join workflow.forecast_request r on r.request_id = a.request_id "
                + "order by a.occurred_at desc, a.event_id desc limit ?", limit);
    }

    /** Audit trail of one forecast request, newest first. */
    public List<Map<String, Object>> forRequest(int requestId) {
        return db2.rows("select a.event_id as \"eventId\", a.occurred_at as \"occurredAt\", a.actor, a.actor_role as \"actorRole\", "
                + "a.event_type as \"eventType\", a.detail from workflow.audit_event a where a.request_id = ? "
                + "order by a.occurred_at desc, a.event_id desc", requestId);
    }
}
