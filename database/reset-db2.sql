-- Run on DB2. Clears every request, decision, allocation, notification and audit entry so the demo starts again
-- from "waiting for the agent". Keeps the sign-in accounts. Does NOT touch DB1.
-- Tip: also run  SELECT agent_sim.cleanup();  on DB1, otherwise PUBLISHED playbooks there are picked up again at once.
BEGIN;
ALTER TABLE workflow.audit_event DISABLE TRIGGER audit_event_append_only;
TRUNCATE workflow.agent_run, workflow.notification, workflow.allocation, workflow.forecast_snapshot_line, workflow.forecast_snapshot,
         workflow.requirement_override, workflow.forecast_review, workflow.forecast_request, workflow.audit_event RESTART IDENTITY;
ALTER TABLE workflow.audit_event ENABLE TRIGGER audit_event_append_only;
ALTER SEQUENCE workflow.allocation_id_seq RESTART WITH 1;
COMMIT;
