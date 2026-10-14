-- =====================================================================================================
-- DB2 · WINFO Labour Manager workflow database
--
--   AI agent ──writes──> DB1 (labor_allocation.agent_playbook + agent_playbook_line)
--                          │  the app polls DB1 every few seconds, reads only
--                          ▼
--   Forecast page (store manager) ── approve / reject ──> DB2 (this file, schema "workflow")
--                                                          │
--                                                          ▼
--                                        Allocation page (user) · Admin page (both)
--
-- DB2 can be its own database (recommended, e.g. "labour_db2") or the same database as DB1: everything here lives
-- in the "workflow" schema, and the app never joins across the two, so both set-ups work.
-- Idempotent: the backend runs this file on every start-up; it is also safe to run by hand in pgAdmin.
-- =====================================================================================================

CREATE SCHEMA IF NOT EXISTS workflow;

-- Sign-in accounts: store manager, user (allocation), admin. Passwords are PBKDF2 hashes.
CREATE TABLE IF NOT EXISTS workflow.app_user (
  user_id       serial PRIMARY KEY,
  username      text NOT NULL UNIQUE,
  display_name  text NOT NULL,
  role          text NOT NULL CHECK (role IN ('STORE_MANAGER', 'ALLOCATOR', 'ADMIN')),
  title         text NOT NULL,
  password_hash text NOT NULL,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- One row per agent publication found in DB1. A publication is one agent_playbook row at one generated_at:
-- if the agent writes the same DC and date again (new generated_at), that becomes the next version.
CREATE TABLE IF NOT EXISTS workflow.forecast_request (
  request_id      serial PRIMARY KEY,
  forecast_code   text NOT NULL UNIQUE,                 -- FC-DAL01-20261009-v1
  source_key      text NOT NULL UNIQUE,                 -- "<playbook_id>@<generated_at in UTC, microseconds>"
  playbook_id     int NOT NULL,                         -- labor_allocation.agent_playbook.playbook_id in DB1 (other database: no FK)
  dc_id           smallint NOT NULL,
  dc_code         text NOT NULL,
  dc_name         text NOT NULL,
  business_date   date NOT NULL,
  version         int NOT NULL,
  status          text NOT NULL CHECK (status IN ('PENDING_REVIEW', 'APPROVED', 'REJECTED', 'SUPERSEDED')),
  review_cycle    int NOT NULL DEFAULT 1,
  row_version     int NOT NULL DEFAULT 1,               -- optimistic locking for approve / reject / reopen
  generated_at    timestamptz NOT NULL,                 -- when the agent wrote it (DB1)
  generated_by    text NOT NULL,
  agent_mode      text,
  received_at     timestamptz NOT NULL DEFAULT now(),   -- when the app picked it up and notified the store manager
  required_hours  int NOT NULL,
  scheduled_hours int NOT NULL,
  UNIQUE (dc_id, business_date, version)
);
CREATE INDEX IF NOT EXISTS forecast_request_dc_date_idx ON workflow.forecast_request (dc_id, business_date, version DESC);

-- Store manager decisions, one row per action.
CREATE TABLE IF NOT EXISTS workflow.forecast_review (
  review_id    serial PRIMARY KEY,
  request_id   int NOT NULL REFERENCES workflow.forecast_request (request_id) ON DELETE CASCADE,
  review_cycle int NOT NULL,
  decision     text NOT NULL CHECK (decision IN ('APPROVED', 'REJECTED', 'REOPENED')),
  reviewer_id  int NOT NULL REFERENCES workflow.app_user (user_id),
  decided_at   timestamptz NOT NULL DEFAULT now(),
  comment      text
);
CREATE UNIQUE INDEX IF NOT EXISTS forecast_review_one_approval ON workflow.forecast_review (request_id) WHERE decision = 'APPROVED';

-- Requirement values the store manager changed before approving. Not used by the current app (approval takes the forecast as sent);
-- kept for possible later changes.
CREATE TABLE IF NOT EXISTS workflow.requirement_override (
  review_id   int NOT NULL REFERENCES workflow.forecast_review (review_id) ON DELETE CASCADE,
  zone_id     smallint NOT NULL,
  hour_index  smallint NOT NULL CHECK (hour_index BETWEEN 0 AND 23),
  from_value  smallint NOT NULL,
  to_value    smallint NOT NULL,
  PRIMARY KEY (review_id, zone_id, hour_index)
);

-- The AI labour forecast exactly as it was approved or rejected, copied from DB1 at decision time,
-- so DB2 is complete on its own (the agent may overwrite its playbook later).
CREATE TABLE IF NOT EXISTS workflow.forecast_snapshot (
  request_id      int PRIMARY KEY REFERENCES workflow.forecast_request (request_id) ON DELETE CASCADE,
  review_id       int NOT NULL REFERENCES workflow.forecast_review (review_id) ON DELETE CASCADE,
  taken_at        timestamptz NOT NULL DEFAULT now(),
  workload_source text NOT NULL,
  schedule_source text NOT NULL,
  coverage        text NOT NULL,
  drivers         text,                                 -- one chip per line
  narrative       text,
  day_start_hour  smallint NOT NULL,                    -- business day starts here (06:00 in the sample data)
  required_hours  int NOT NULL,
  approved_hours  int,                                  -- null when rejected
  scheduled_hours int NOT NULL
);

CREATE TABLE IF NOT EXISTS workflow.forecast_snapshot_line (
  request_id      int NOT NULL REFERENCES workflow.forecast_snapshot (request_id) ON DELETE CASCADE,
  zone_id         smallint NOT NULL,
  zone_order      smallint NOT NULL,
  zone_code       text NOT NULL,
  zone_name       text NOT NULL,
  skill           text NOT NULL,
  hour_index      smallint NOT NULL CHECK (hour_index BETWEEN 0 AND 23),
  local_hour      smallint NOT NULL CHECK (local_hour BETWEEN 0 AND 23),
  shift_code      text NOT NULL,
  workload        int NOT NULL,
  required_staff  smallint NOT NULL,
  scheduled_staff smallint NOT NULL,
  approved_staff  smallint,                             -- null when rejected
  PRIMARY KEY (request_id, zone_id, hour_index)
);

-- Forecast allocation: created once, automatically, when a forecast is approved, and final at once.
-- The current app writes status COMMITTED (shown as "Ready"); committed_by / committed_at / commit_comment stay empty
-- because there is no separate commit step. PROPOSED only appears in rows written by older versions.
CREATE TABLE IF NOT EXISTS workflow.allocation (
  allocation_id   int PRIMARY KEY,
  allocation_code text NOT NULL UNIQUE,                 -- ALLOC-DAL01-1009-001
  request_id      int NOT NULL UNIQUE REFERENCES workflow.forecast_request (request_id) ON DELETE CASCADE,
  review_id       int NOT NULL REFERENCES workflow.forecast_review (review_id) ON DELETE CASCADE,
  status          text NOT NULL CHECK (status IN ('PROPOSED', 'COMMITTED')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  changes         int NOT NULL,                         -- requirement values changed by the approver
  approved_hours  int NOT NULL,
  scheduled_hours int NOT NULL,
  coverage        numeric(5, 1) NOT NULL,               -- % of the approved need the schedule covers
  committed_by    int REFERENCES workflow.app_user (user_id),
  committed_at    timestamptz,
  commit_comment  text
);
CREATE SEQUENCE IF NOT EXISTS workflow.allocation_id_seq OWNED BY workflow.allocation.allocation_id;

-- Bell and popups.
CREATE TABLE IF NOT EXISTS workflow.notification (
  notification_id serial PRIMARY KEY,
  user_id         int NOT NULL REFERENCES workflow.app_user (user_id) ON DELETE CASCADE,
  type            text NOT NULL,                        -- REQUEST_RECEIVED, FORECAST_APPROVED, FORECAST_REJECTED, FORECAST_REOPENED
  title           text NOT NULL,
  body            text NOT NULL,
  request_id      int REFERENCES workflow.forecast_request (request_id) ON DELETE CASCADE,
  allocation_id   int REFERENCES workflow.allocation (allocation_id) ON DELETE CASCADE,
  created_at      timestamptz NOT NULL DEFAULT now(),
  read_at         timestamptz
);
CREATE INDEX IF NOT EXISTS notification_user_idx ON workflow.notification (user_id, created_at DESC);

-- Append-only audit log: received, superseded, ignored, approved, rejected, reopened, allocated.
CREATE TABLE IF NOT EXISTS workflow.audit_event (
  event_id      bigserial PRIMARY KEY,
  occurred_at   timestamptz NOT NULL DEFAULT now(),
  actor         text NOT NULL,
  actor_role    text NOT NULL,
  event_type    text NOT NULL,
  request_id    int REFERENCES workflow.forecast_request (request_id) ON DELETE SET NULL,
  allocation_id int REFERENCES workflow.allocation (allocation_id) ON DELETE SET NULL,
  source_key    text,
  detail        text NOT NULL
);
CREATE INDEX IF NOT EXISTS audit_event_time_idx ON workflow.audit_event (occurred_at DESC);
CREATE INDEX IF NOT EXISTS audit_event_source_idx ON workflow.audit_event (source_key) WHERE source_key IS NOT NULL;

CREATE OR REPLACE FUNCTION workflow.audit_event_append_only() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND (NEW.request_id IS NULL AND OLD.request_id IS NOT NULL
                           OR NEW.allocation_id IS NULL AND OLD.allocation_id IS NOT NULL) THEN
    RETURN NEW; -- only the ON DELETE SET NULL of a removed request or allocation
  END IF;
  RAISE EXCEPTION 'workflow.audit_event is append-only';
END;
$$;

CREATE OR REPLACE TRIGGER audit_event_append_only
  BEFORE UPDATE OR DELETE ON workflow.audit_event
  FOR EACH ROW EXECUTE FUNCTION workflow.audit_event_append_only();

-- Not used by the current app: the agent writes into DB1 by itself and is never started from here. Kept for possible later changes.
-- (Was: every time this application asked the AI agent to produce a forecast, and what became of it.)
-- REQUESTED = being sent, ACCEPTED = the agent said OK (it is working), COMPLETED = its forecast arrived in DB1 and became a request,
-- FAILED = the agent could not be reached or refused, TIMED_OUT = accepted but no forecast arrived in time.
CREATE TABLE IF NOT EXISTS workflow.agent_run (
  run_id            serial PRIMARY KEY,
  dc_id             int NOT NULL,
  dc_code           text NOT NULL,
  business_date     date NOT NULL,
  trigger_type      text NOT NULL,            -- MANUAL | SCHEDULED
  requested_by      text NOT NULL,
  requested_by_role text NOT NULL,
  status            text NOT NULL DEFAULT 'REQUESTED',
  http_status       int,
  message           text,
  requested_at      timestamptz NOT NULL DEFAULT now(),
  finished_at       timestamptz,
  request_id        int REFERENCES workflow.forecast_request (request_id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS agent_run_dc_date_idx ON workflow.agent_run (dc_id, business_date, run_id DESC);
CREATE INDEX IF NOT EXISTS agent_run_open_idx ON workflow.agent_run (status) WHERE status IN ('REQUESTED', 'ACCEPTED');
