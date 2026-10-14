-- Schema-only copy of Neon project 'Supply Chain' (delicate-mountain-71297589), branch production, database neondb
-- Source server: PostgreSQL 18.6 (c021049)
-- Generated 2026-10-09 05:59 UTC by replicate_schema.py. Contains no table data.
-- Apply to an empty database:  psql -v ON_ERROR_STOP=1 -1 -d <db> -f <this file>
--                          or:  py replicate_schema.py --from-sql <this file> --target-db <db>
-- replicate_schema: {"schemas": ["public", "legacy"], "expected": {"check constraints": 19, "comments": 72, "foreign keys": 88, "indexes": 103, "materialized views": 4, "not-null columns": 404, "primary keys": 49, "sequences": 13, "tables": 49, "unique constraints": 14, "views": 25}}

SET client_min_messages = warning;
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);

-- Schemas and extensions (2)

CREATE SCHEMA IF NOT EXISTS legacy;

CREATE SCHEMA IF NOT EXISTS labor_allocation;


-- Sequences (13)

CREATE SEQUENCE legacy.agent_benefits_id_seq AS integer START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1;

CREATE SEQUENCE legacy.agent_recommendations_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1;

CREATE SEQUENCE legacy.agents_id_seq AS integer START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1;

CREATE SEQUENCE legacy.categories_id_seq AS integer START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1;

CREATE SEQUENCE legacy.customers_id_seq AS integer START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1;

CREATE SEQUENCE legacy.inventory_snapshots_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1;

CREATE SEQUENCE legacy.labor_shifts_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1;

CREATE SEQUENCE legacy.order_items_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1;

CREATE SEQUENCE legacy.orders_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1;

CREATE SEQUENCE legacy.products_id_seq AS integer START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1;

CREATE SEQUENCE legacy.shipments_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1;

CREATE SEQUENCE legacy.warehouse_risk_scores_id_seq AS bigint START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1;

CREATE SEQUENCE legacy.warehouses_id_seq AS integer START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1;


-- Tables (49)

CREATE TABLE legacy.categories (
    id integer DEFAULT nextval('legacy.categories_id_seq'::regclass) NOT NULL,
    name text NOT NULL,
    description text
);

CREATE TABLE legacy.agents (
    id integer DEFAULT nextval('legacy.agents_id_seq'::regclass) NOT NULL,
    code text NOT NULL,
    title text NOT NULL,
    category_id integer,
    priority text,
    problem_statement text,
    capabilities text,
    business_impact text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE legacy.agent_benefits (
    id integer DEFAULT nextval('legacy.agent_benefits_id_seq'::regclass) NOT NULL,
    agent_id integer NOT NULL,
    benefit text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL
);

CREATE TABLE legacy.warehouses (
    id integer DEFAULT nextval('legacy.warehouses_id_seq'::regclass) NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    city text NOT NULL,
    state text NOT NULL,
    region text NOT NULL,
    sqft integer NOT NULL,
    opened_on date NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);

CREATE TABLE legacy.products (
    id integer DEFAULT nextval('legacy.products_id_seq'::regclass) NOT NULL,
    sku text NOT NULL,
    name text NOT NULL,
    category text NOT NULL,
    subcategory text NOT NULL,
    unit_cost numeric(10,2) NOT NULL,
    unit_price numeric(10,2) NOT NULL,
    weight_lbs numeric(6,2) NOT NULL,
    is_hazmat boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE legacy.customers (
    id integer DEFAULT nextval('legacy.customers_id_seq'::regclass) NOT NULL,
    external_id text NOT NULL,
    full_name text NOT NULL,
    email text NOT NULL,
    city text NOT NULL,
    state text NOT NULL,
    segment text NOT NULL,
    signup_date date NOT NULL
);

CREATE TABLE legacy.inventory_snapshots (
    id bigint DEFAULT nextval('legacy.inventory_snapshots_id_seq'::regclass) NOT NULL,
    warehouse_id integer NOT NULL,
    product_id integer NOT NULL,
    snapshot_date date NOT NULL,
    on_hand_qty integer NOT NULL,
    reserved_qty integer NOT NULL,
    reorder_point integer NOT NULL
);

CREATE TABLE legacy.orders (
    id bigint DEFAULT nextval('legacy.orders_id_seq'::regclass) NOT NULL,
    order_number text NOT NULL,
    customer_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    channel text NOT NULL,
    status text NOT NULL,
    order_ts timestamp with time zone NOT NULL,
    promised_date date,
    shipped_ts timestamp with time zone,
    delivered_ts timestamp with time zone,
    subtotal numeric(12,2) NOT NULL,
    shipping_cost numeric(10,2) DEFAULT 0 NOT NULL,
    total numeric(12,2) NOT NULL
);

CREATE TABLE legacy.order_items (
    id bigint DEFAULT nextval('legacy.order_items_id_seq'::regclass) NOT NULL,
    order_id bigint NOT NULL,
    product_id integer NOT NULL,
    qty integer NOT NULL,
    unit_price numeric(10,2) NOT NULL,
    line_total numeric(12,2) NOT NULL
);

CREATE TABLE legacy.shipments (
    id bigint DEFAULT nextval('legacy.shipments_id_seq'::regclass) NOT NULL,
    shipment_number text NOT NULL,
    order_id bigint NOT NULL,
    warehouse_id integer NOT NULL,
    carrier text NOT NULL,
    service_level text NOT NULL,
    ship_ts timestamp with time zone NOT NULL,
    est_delivery_date date,
    actual_delivery_ts timestamp with time zone,
    on_time boolean,
    freight_cost numeric(10,2) NOT NULL
);

CREATE TABLE legacy.labor_shifts (
    id bigint DEFAULT nextval('legacy.labor_shifts_id_seq'::regclass) NOT NULL,
    warehouse_id integer NOT NULL,
    shift_date date NOT NULL,
    shift_name text NOT NULL,
    zone text NOT NULL,
    scheduled_headcount integer NOT NULL,
    actual_headcount integer NOT NULL,
    units_processed integer NOT NULL,
    overtime_hours numeric(6,2) DEFAULT 0 NOT NULL
);

CREATE TABLE legacy.agent_recommendations (
    id bigint DEFAULT nextval('legacy.agent_recommendations_id_seq'::regclass) NOT NULL,
    agent_id integer NOT NULL,
    warehouse_id integer,
    product_id integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    recommendation_type text NOT NULL,
    severity text NOT NULL,
    message text NOT NULL,
    projected_impact_usd numeric(12,2),
    status text DEFAULT 'Open'::text NOT NULL
);

CREATE TABLE legacy.warehouse_risk_scores (
    id bigint DEFAULT nextval('legacy.warehouse_risk_scores_id_seq'::regclass) NOT NULL,
    warehouse_id integer NOT NULL,
    as_of_date date NOT NULL,
    inventory_risk numeric(6,2) NOT NULL,
    delivery_risk numeric(6,2) NOT NULL,
    labor_risk numeric(6,2) NOT NULL,
    composite_score numeric(6,2) NOT NULL,
    computed_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE labor_allocation.ai_opportunity (
    opportunity_code text NOT NULL,
    sheet_reference text NOT NULL,
    title text NOT NULL,
    category text NOT NULL,
    priority text NOT NULL,
    problem_statement text,
    business_need text,
    capabilities text[],
    expected_benefits text[],
    in_poc_scope boolean DEFAULT false NOT NULL,
    source_note text
);

CREATE TABLE labor_allocation.poc_config (
    key text NOT NULL,
    value text NOT NULL,
    description text
);

CREATE TABLE labor_allocation.poc_kpi_target (
    kpi_code text NOT NULL,
    kpi_name text NOT NULL,
    unit text NOT NULL,
    better_direction text NOT NULL,
    target_improvement text NOT NULL,
    definition text NOT NULL,
    exec_owner text NOT NULL
);

CREATE TABLE labor_allocation.dc (
    dc_id smallint NOT NULL,
    dc_code text NOT NULL,
    dc_name text NOT NULL,
    city text NOT NULL,
    state character(2) NOT NULL,
    region text NOT NULL,
    timezone text NOT NULL,
    dc_type text NOT NULL,
    building_sqft integer NOT NULL,
    inbound_doors smallint NOT NULL,
    outbound_doors smallint NOT NULL,
    shifts_operated smallint NOT NULL,
    operating_days text NOT NULL,
    volume_uom text NOT NULL,
    design_daily_volume integer NOT NULL,
    agent_cohort text NOT NULL,
    general_manager text NOT NULL,
    wms_platform text NOT NULL,
    lms_platform text NOT NULL,
    wfm_platform text NOT NULL
);

CREATE TABLE labor_allocation.labor_function (
    function_code text NOT NULL,
    function_name text NOT NULL,
    flow_stage smallint NOT NULL,
    is_direct boolean NOT NULL,
    description text NOT NULL
);

CREATE TABLE labor_allocation.dc_zone (
    zone_id smallint NOT NULL,
    dc_id smallint NOT NULL,
    zone_code text NOT NULL,
    zone_name text NOT NULL,
    function_code text NOT NULL,
    uom text NOT NULL,
    units_per_uom real NOT NULL,
    standard_uph real NOT NULL,
    aging_sla_min smallint NOT NULL,
    min_headcount smallint NOT NULL,
    max_headcount smallint NOT NULL,
    requires_pit boolean NOT NULL,
    primary_skill_code text NOT NULL,
    work_source text,
    flow_chain text,
    is_deferrable boolean NOT NULL,
    operating_shifts text NOT NULL,
    building_area text NOT NULL,
    floor_level smallint NOT NULL
);

CREATE TABLE labor_allocation.zone_flow (
    from_zone_id smallint NOT NULL,
    to_zone_id smallint NOT NULL,
    conversion_factor real NOT NULL,
    flow_share real NOT NULL,
    transit_min smallint NOT NULL
);

CREATE TABLE labor_allocation.zone_travel_time (
    from_zone_id smallint NOT NULL,
    to_zone_id smallint NOT NULL,
    walk_minutes real NOT NULL,
    ppe_change boolean NOT NULL,
    same_floor boolean NOT NULL
);

CREATE TABLE labor_allocation.skill (
    skill_code text NOT NULL,
    skill_name text NOT NULL,
    function_code text,
    is_certification boolean NOT NULL,
    certifying_standard text,
    validity_months smallint,
    equipment text,
    training_hours smallint NOT NULL,
    description text
);

CREATE TABLE labor_allocation.zone_skill_requirement (
    zone_id smallint NOT NULL,
    skill_code text NOT NULL,
    min_proficiency smallint NOT NULL,
    is_mandatory boolean NOT NULL
);

CREATE TABLE labor_allocation.shift_definition (
    dc_id smallint NOT NULL,
    shift_code text NOT NULL,
    shift_name text NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    paid_hours real NOT NULL,
    unpaid_meal_min smallint NOT NULL,
    paid_breaks smallint NOT NULL,
    is_part_time boolean NOT NULL
);

CREATE TABLE labor_allocation.carrier_cutoff (
    cutoff_id smallint NOT NULL,
    dc_id smallint NOT NULL,
    flow_chain text NOT NULL,
    carrier text NOT NULL,
    service_level text NOT NULL,
    pull_time time without time zone NOT NULL,
    lead_time_min smallint NOT NULL,
    miss_cost_per_unit numeric(6,2) NOT NULL
);

CREATE TABLE labor_allocation.labor_constraint_rule (
    rule_code text NOT NULL,
    rule_name text NOT NULL,
    rule_type text NOT NULL,
    category text NOT NULL,
    source text NOT NULL,
    description text NOT NULL,
    parameters jsonb,
    applies_to_dc text,
    soft_penalty_weight real,
    is_active boolean DEFAULT true NOT NULL
);

CREATE TABLE labor_allocation.pay_rate_card (
    dc_id smallint NOT NULL,
    job_title text NOT NULL,
    base_rate numeric(6,2) NOT NULL,
    temp_bill_rate numeric(6,2) NOT NULL,
    ot_multiplier numeric(3,2) NOT NULL,
    benefits_burden_pct numeric(4,1) NOT NULL
);

CREATE TABLE labor_allocation.ops_supervisor (
    supervisor_id smallint NOT NULL,
    dc_id smallint NOT NULL,
    full_name text NOT NULL,
    title text NOT NULL,
    shift_code text NOT NULL,
    area text NOT NULL,
    years_experience smallint NOT NULL,
    agent_adoption_score real
);

CREATE TABLE labor_allocation.associate (
    associate_id integer NOT NULL,
    kronos_person_num text NOT NULL,
    badge_id text NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    dc_id smallint NOT NULL,
    home_zone_id smallint NOT NULL,
    shift_code text NOT NULL,
    work_pattern text NOT NULL,
    employment_type text NOT NULL,
    staffing_agency text,
    job_title text NOT NULL,
    hourly_rate numeric(6,2) NOT NULL,
    hire_date date NOT NULL,
    termination_date date,
    termination_reason text,
    status text NOT NULL,
    is_lead boolean DEFAULT false NOT NULL,
    is_flex_pool boolean DEFAULT false NOT NULL,
    restrictions text[],
    base_performance real NOT NULL
);

CREATE TABLE labor_allocation.associate_skill (
    associate_id integer NOT NULL,
    skill_code text NOT NULL,
    proficiency smallint NOT NULL,
    certified_on date NOT NULL,
    expires_on date,
    source text NOT NULL,
    recommended_by_rec_id integer
);

CREATE TABLE labor_allocation.agent_rollout (
    dc_id smallint NOT NULL,
    phase text NOT NULL,
    start_date date NOT NULL,
    end_date date,
    description text NOT NULL
);

CREATE TABLE labor_allocation.agent_model_version (
    model_version_id smallint NOT NULL,
    component text NOT NULL,
    version text NOT NULL,
    algorithm text NOT NULL,
    key_features text[],
    deployed_on date NOT NULL,
    retired_on date,
    release_notes text
);

CREATE TABLE labor_allocation.agent_training_run (
    run_id integer NOT NULL,
    model_version_id smallint NOT NULL,
    run_at timestamp with time zone NOT NULL,
    scope_dc_id smallint,
    train_start date NOT NULL,
    train_end date NOT NULL,
    training_rows integer NOT NULL,
    metrics jsonb NOT NULL,
    promoted boolean NOT NULL,
    notes text
);

CREATE TABLE labor_allocation.wfm_static_labor_plan (
    dc_id smallint NOT NULL,
    business_date date NOT NULL,
    shift_code text NOT NULL,
    zone_id smallint NOT NULL,
    planned_volume integer NOT NULL,
    required_headcount real NOT NULL,
    scheduled_headcount smallint NOT NULL,
    planning_basis text NOT NULL,
    published_at timestamp with time zone NOT NULL
);

CREATE TABLE labor_allocation.wfm_timecard (
    associate_id integer NOT NULL,
    business_date date NOT NULL,
    dc_id smallint NOT NULL,
    shift_code text NOT NULL,
    home_zone_id smallint NOT NULL,
    clock_in timestamp with time zone,
    clock_out timestamp with time zone,
    unpaid_meal_min smallint NOT NULL,
    regular_hours real NOT NULL,
    overtime_hours real NOT NULL,
    vto_hours real NOT NULL,
    absence_code text,
    late_minutes smallint NOT NULL,
    ot_type text,
    labor_cost_usd real NOT NULL
);

CREATE TABLE labor_allocation.lms_associate_daily (
    associate_id integer NOT NULL,
    business_date date NOT NULL,
    zone_id smallint NOT NULL,
    dc_id smallint NOT NULL,
    direct_hours real NOT NULL,
    indirect_hours real NOT NULL,
    idle_hours real NOT NULL,
    workload_done real NOT NULL,
    earned_hours real NOT NULL,
    pct_to_standard real,
    reallocated_in boolean NOT NULL
);

CREATE TABLE labor_allocation.wms_inbound_appointment (
    appt_id integer NOT NULL,
    dc_id smallint NOT NULL,
    appt_number text NOT NULL,
    vendor text NOT NULL,
    load_type text NOT NULL,
    scheduled_at timestamp with time zone NOT NULL,
    arrived_at timestamp with time zone,
    door smallint,
    cartons integer NOT NULL,
    pallets smallint NOT NULL,
    status text NOT NULL,
    lateness_min smallint
);

CREATE TABLE labor_allocation.wms_equipment_downtime (
    event_id integer NOT NULL,
    dc_id smallint NOT NULL,
    zone_id smallint NOT NULL,
    equipment text NOT NULL,
    cause text NOT NULL,
    started_at timestamp with time zone NOT NULL,
    ended_at timestamp with time zone NOT NULL,
    capacity_loss_pct smallint NOT NULL
);

CREATE TABLE labor_allocation.wms_zone_interval (
    zone_id smallint NOT NULL,
    interval_start timestamp with time zone NOT NULL,
    dc_id smallint NOT NULL,
    business_date date NOT NULL,
    local_slot smallint NOT NULL,
    workload_in integer NOT NULL,
    workload_done integer NOT NULL,
    queue_depth integer NOT NULL,
    oldest_task_age_min smallint NOT NULL,
    avg_task_age_min smallint NOT NULL,
    hc_planned real,
    hc_actual real NOT NULL,
    direct_hours real NOT NULL,
    idle_hours real NOT NULL,
    fcst_dayahead integer,
    fcst_intraday integer,
    is_bottleneck boolean NOT NULL
);

CREATE TABLE labor_allocation.ops_bottleneck_episode (
    episode_id integer NOT NULL,
    dc_id smallint NOT NULL,
    zone_id smallint NOT NULL,
    business_date date NOT NULL,
    started_at timestamp with time zone NOT NULL,
    ended_at timestamp with time zone,
    duration_min smallint NOT NULL,
    peak_queue integer NOT NULL,
    peak_oldest_age_min smallint NOT NULL,
    root_cause text NOT NULL,
    agent_mode text NOT NULL,
    first_alert_id integer,
    alert_lead_min smallint
);

CREATE TABLE labor_allocation.ops_firefighting_event (
    event_id integer NOT NULL,
    dc_id smallint NOT NULL,
    zone_id smallint,
    occurred_at timestamp with time zone NOT NULL,
    event_type text NOT NULL,
    trigger text NOT NULL,
    associates_affected smallint NOT NULL,
    supervisor_minutes smallint NOT NULL,
    added_cost_usd real NOT NULL,
    supervisor_id smallint,
    episode_id integer,
    notes text
);

CREATE TABLE labor_allocation.ops_cutoff_performance (
    dc_id smallint NOT NULL,
    business_date date NOT NULL,
    cutoff_id smallint NOT NULL,
    pull_at timestamp with time zone NOT NULL,
    units_due integer NOT NULL,
    units_on_time integer NOT NULL,
    units_missed integer NOT NULL,
    backlog_at_pull integer NOT NULL,
    miss_cost_usd real NOT NULL
);

CREATE TABLE labor_allocation.ops_labor_move (
    move_id integer NOT NULL,
    dc_id smallint NOT NULL,
    business_date date NOT NULL,
    associate_id integer NOT NULL,
    from_zone_id smallint NOT NULL,
    to_zone_id smallint NOT NULL,
    move_source text NOT NULL,
    rec_id integer,
    firefight_event_id integer,
    requested_at timestamp with time zone NOT NULL,
    started_at timestamp with time zone NOT NULL,
    ended_at timestamp with time zone NOT NULL,
    travel_min real NOT NULL,
    target_skill_proficiency smallint,
    est_workload_done real NOT NULL
);

CREATE TABLE labor_allocation.agent_bottleneck_alert (
    alert_id integer NOT NULL,
    dc_id smallint NOT NULL,
    zone_id smallint NOT NULL,
    detected_at timestamp with time zone NOT NULL,
    agent_mode text NOT NULL,
    model_version_id smallint NOT NULL,
    signal_type text NOT NULL,
    severity text NOT NULL,
    queue_depth integer NOT NULL,
    queue_growth_pct_per_hr real,
    oldest_task_age_min smallint NOT NULL,
    throughput_trend_pct real,
    projected_wait_min smallint,
    projected_breach_at timestamp with time zone,
    lead_time_min smallint,
    projected_units_at_risk integer,
    cutoff_id smallint,
    probable_cause text,
    status text NOT NULL,
    closed_at timestamp with time zone,
    episode_id integer
);

CREATE TABLE labor_allocation.agent_recommendation (
    rec_id integer NOT NULL,
    dc_id smallint NOT NULL,
    alert_id integer,
    created_at timestamp with time zone NOT NULL,
    agent_mode text NOT NULL,
    model_version_id smallint NOT NULL,
    rec_type text NOT NULL,
    priority text NOT NULL,
    from_zone_id smallint,
    to_zone_id smallint,
    headcount smallint,
    skill_code text,
    window_start timestamp with time zone,
    window_end timestamp with time zone,
    expected_workload_gain integer,
    expected_aging_reduction_min smallint,
    expected_sla_units_protected integer,
    expected_benefit_usd real,
    expected_cost_usd real,
    confidence real NOT NULL,
    hard_constraints_checked smallint NOT NULL,
    soft_constraints_flagged text[],
    rationale text NOT NULL,
    status text NOT NULL,
    decided_by_supervisor_id smallint,
    decided_at timestamp with time zone,
    rejection_reason text
);

CREATE TABLE labor_allocation.agent_outcome (
    rec_id integer NOT NULL,
    evaluated_at timestamp with time zone NOT NULL,
    actual_workload_gain integer,
    actual_aging_reduction_min smallint,
    actual_sla_units_protected integer,
    realized_benefit_usd real,
    realized_cost_usd real,
    outcome_label text NOT NULL,
    reward real NOT NULL,
    learning_note text
);

CREATE TABLE labor_allocation.agent_playbook (
    playbook_id integer NOT NULL,
    dc_id smallint NOT NULL,
    business_date date NOT NULL,
    generated_at timestamp with time zone NOT NULL,
    model_version_id smallint NOT NULL,
    agent_mode text NOT NULL,
    status text NOT NULL,
    acknowledged_by_supervisor_id smallint,
    fcst_volume integer NOT NULL,
    fcst_volume_p10 integer NOT NULL,
    fcst_volume_p90 integer NOT NULL,
    actual_volume integer,
    static_plan_hours real NOT NULL,
    recommended_hours real NOT NULL,
    recommended_vet_hours real NOT NULL,
    recommended_vto_hours real NOT NULL,
    risk_windows jsonb,
    narrative text NOT NULL
);

CREATE TABLE labor_allocation.agent_playbook_line (
    playbook_id integer NOT NULL,
    zone_id smallint NOT NULL,
    local_hour smallint NOT NULL,
    fcst_workload integer NOT NULL,
    required_hours real NOT NULL,
    recommended_hc smallint NOT NULL,
    static_plan_hc smallint NOT NULL,
    flex_in smallint NOT NULL,
    flex_out smallint NOT NULL
);

CREATE TABLE labor_allocation.agent_workload_forecast (
    zone_id smallint NOT NULL,
    interval_start timestamp with time zone NOT NULL,
    dc_id smallint NOT NULL,
    business_date date NOT NULL,
    local_slot smallint NOT NULL,
    generated_at timestamp with time zone NOT NULL,
    model_version_id smallint NOT NULL,
    fcst_p10 integer NOT NULL,
    fcst_p50 integer NOT NULL,
    fcst_p90 integer NOT NULL,
    required_hc_p50 real NOT NULL
);


-- Sequence ownership (13)

ALTER SEQUENCE legacy.agent_benefits_id_seq OWNED BY legacy.agent_benefits.id;

ALTER SEQUENCE legacy.agent_recommendations_id_seq OWNED BY legacy.agent_recommendations.id;

ALTER SEQUENCE legacy.agents_id_seq OWNED BY legacy.agents.id;

ALTER SEQUENCE legacy.categories_id_seq OWNED BY legacy.categories.id;

ALTER SEQUENCE legacy.customers_id_seq OWNED BY legacy.customers.id;

ALTER SEQUENCE legacy.inventory_snapshots_id_seq OWNED BY legacy.inventory_snapshots.id;

ALTER SEQUENCE legacy.labor_shifts_id_seq OWNED BY legacy.labor_shifts.id;

ALTER SEQUENCE legacy.order_items_id_seq OWNED BY legacy.order_items.id;

ALTER SEQUENCE legacy.orders_id_seq OWNED BY legacy.orders.id;

ALTER SEQUENCE legacy.products_id_seq OWNED BY legacy.products.id;

ALTER SEQUENCE legacy.shipments_id_seq OWNED BY legacy.shipments.id;

ALTER SEQUENCE legacy.warehouse_risk_scores_id_seq OWNED BY legacy.warehouse_risk_scores.id;

ALTER SEQUENCE legacy.warehouses_id_seq OWNED BY legacy.warehouses.id;


-- Primary keys, unique, check and exclusion constraints (82)

ALTER TABLE legacy.agent_benefits ADD CONSTRAINT agent_benefits_pkey PRIMARY KEY (id);

ALTER TABLE legacy.agent_recommendations ADD CONSTRAINT agent_recommendations_pkey PRIMARY KEY (id);

ALTER TABLE legacy.agents ADD CONSTRAINT agents_pkey PRIMARY KEY (id);

ALTER TABLE legacy.categories ADD CONSTRAINT categories_pkey PRIMARY KEY (id);

ALTER TABLE legacy.customers ADD CONSTRAINT customers_pkey PRIMARY KEY (id);

ALTER TABLE legacy.inventory_snapshots ADD CONSTRAINT inventory_snapshots_pkey PRIMARY KEY (id);

ALTER TABLE legacy.labor_shifts ADD CONSTRAINT labor_shifts_pkey PRIMARY KEY (id);

ALTER TABLE legacy.order_items ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);

ALTER TABLE legacy.orders ADD CONSTRAINT orders_pkey PRIMARY KEY (id);

ALTER TABLE legacy.products ADD CONSTRAINT products_pkey PRIMARY KEY (id);

ALTER TABLE legacy.shipments ADD CONSTRAINT shipments_pkey PRIMARY KEY (id);

ALTER TABLE legacy.warehouse_risk_scores ADD CONSTRAINT warehouse_risk_scores_pkey PRIMARY KEY (id);

ALTER TABLE legacy.warehouses ADD CONSTRAINT warehouses_pkey PRIMARY KEY (id);

ALTER TABLE labor_allocation.agent_bottleneck_alert ADD CONSTRAINT agent_bottleneck_alert_pkey PRIMARY KEY (alert_id);

ALTER TABLE labor_allocation.agent_model_version ADD CONSTRAINT agent_model_version_pkey PRIMARY KEY (model_version_id);

ALTER TABLE labor_allocation.agent_outcome ADD CONSTRAINT agent_outcome_pkey PRIMARY KEY (rec_id);

ALTER TABLE labor_allocation.agent_playbook ADD CONSTRAINT agent_playbook_pkey PRIMARY KEY (playbook_id);

ALTER TABLE labor_allocation.agent_playbook_line ADD CONSTRAINT agent_playbook_line_pkey PRIMARY KEY (playbook_id, zone_id, local_hour);

ALTER TABLE labor_allocation.agent_recommendation ADD CONSTRAINT agent_recommendation_pkey PRIMARY KEY (rec_id);

ALTER TABLE labor_allocation.agent_rollout ADD CONSTRAINT agent_rollout_pkey PRIMARY KEY (dc_id, phase);

ALTER TABLE labor_allocation.agent_training_run ADD CONSTRAINT agent_training_run_pkey PRIMARY KEY (run_id);

ALTER TABLE labor_allocation.agent_workload_forecast ADD CONSTRAINT agent_workload_forecast_pkey PRIMARY KEY (zone_id, interval_start);

ALTER TABLE labor_allocation.ai_opportunity ADD CONSTRAINT ai_opportunity_pkey PRIMARY KEY (opportunity_code);

ALTER TABLE labor_allocation.associate ADD CONSTRAINT associate_pkey PRIMARY KEY (associate_id);

ALTER TABLE labor_allocation.associate_skill ADD CONSTRAINT associate_skill_pkey PRIMARY KEY (associate_id, skill_code);

ALTER TABLE labor_allocation.carrier_cutoff ADD CONSTRAINT carrier_cutoff_pkey PRIMARY KEY (cutoff_id);

ALTER TABLE labor_allocation.dc ADD CONSTRAINT dc_pkey PRIMARY KEY (dc_id);

ALTER TABLE labor_allocation.dc_zone ADD CONSTRAINT dc_zone_pkey PRIMARY KEY (zone_id);

ALTER TABLE labor_allocation.labor_constraint_rule ADD CONSTRAINT labor_constraint_rule_pkey PRIMARY KEY (rule_code);

ALTER TABLE labor_allocation.labor_function ADD CONSTRAINT labor_function_pkey PRIMARY KEY (function_code);

ALTER TABLE labor_allocation.lms_associate_daily ADD CONSTRAINT lms_associate_daily_pkey PRIMARY KEY (associate_id, business_date, zone_id);

ALTER TABLE labor_allocation.ops_bottleneck_episode ADD CONSTRAINT ops_bottleneck_episode_pkey PRIMARY KEY (episode_id);

ALTER TABLE labor_allocation.ops_cutoff_performance ADD CONSTRAINT ops_cutoff_performance_pkey PRIMARY KEY (dc_id, business_date, cutoff_id);

ALTER TABLE labor_allocation.ops_firefighting_event ADD CONSTRAINT ops_firefighting_event_pkey PRIMARY KEY (event_id);

ALTER TABLE labor_allocation.ops_labor_move ADD CONSTRAINT ops_labor_move_pkey PRIMARY KEY (move_id);

ALTER TABLE labor_allocation.ops_supervisor ADD CONSTRAINT ops_supervisor_pkey PRIMARY KEY (supervisor_id);

ALTER TABLE labor_allocation.pay_rate_card ADD CONSTRAINT pay_rate_card_pkey PRIMARY KEY (dc_id, job_title);

ALTER TABLE labor_allocation.poc_config ADD CONSTRAINT poc_config_pkey PRIMARY KEY (key);

ALTER TABLE labor_allocation.poc_kpi_target ADD CONSTRAINT poc_kpi_target_pkey PRIMARY KEY (kpi_code);

ALTER TABLE labor_allocation.shift_definition ADD CONSTRAINT shift_definition_pkey PRIMARY KEY (dc_id, shift_code);

ALTER TABLE labor_allocation.skill ADD CONSTRAINT skill_pkey PRIMARY KEY (skill_code);

ALTER TABLE labor_allocation.wfm_static_labor_plan ADD CONSTRAINT wfm_static_labor_plan_pkey PRIMARY KEY (dc_id, business_date, shift_code, zone_id);

ALTER TABLE labor_allocation.wfm_timecard ADD CONSTRAINT wfm_timecard_pkey PRIMARY KEY (associate_id, business_date);

ALTER TABLE labor_allocation.wms_equipment_downtime ADD CONSTRAINT wms_equipment_downtime_pkey PRIMARY KEY (event_id);

ALTER TABLE labor_allocation.wms_inbound_appointment ADD CONSTRAINT wms_inbound_appointment_pkey PRIMARY KEY (appt_id);

ALTER TABLE labor_allocation.wms_zone_interval ADD CONSTRAINT wms_zone_interval_pkey PRIMARY KEY (zone_id, interval_start);

ALTER TABLE labor_allocation.zone_flow ADD CONSTRAINT zone_flow_pkey PRIMARY KEY (from_zone_id, to_zone_id);

ALTER TABLE labor_allocation.zone_skill_requirement ADD CONSTRAINT zone_skill_requirement_pkey PRIMARY KEY (zone_id, skill_code);

ALTER TABLE labor_allocation.zone_travel_time ADD CONSTRAINT zone_travel_time_pkey PRIMARY KEY (from_zone_id, to_zone_id);

ALTER TABLE legacy.agents ADD CONSTRAINT agents_code_key UNIQUE (code);

ALTER TABLE legacy.categories ADD CONSTRAINT categories_name_key UNIQUE (name);

ALTER TABLE legacy.customers ADD CONSTRAINT customers_external_id_key UNIQUE (external_id);

ALTER TABLE legacy.inventory_snapshots ADD CONSTRAINT inventory_snapshots_warehouse_id_product_id_snapshot_date_key UNIQUE (warehouse_id, product_id, snapshot_date);

ALTER TABLE legacy.orders ADD CONSTRAINT orders_order_number_key UNIQUE (order_number);

ALTER TABLE legacy.products ADD CONSTRAINT products_sku_key UNIQUE (sku);

ALTER TABLE legacy.shipments ADD CONSTRAINT shipments_shipment_number_key UNIQUE (shipment_number);

ALTER TABLE legacy.warehouse_risk_scores ADD CONSTRAINT warehouse_risk_scores_warehouse_id_as_of_date_key UNIQUE (warehouse_id, as_of_date);

ALTER TABLE legacy.warehouses ADD CONSTRAINT warehouses_code_key UNIQUE (code);

ALTER TABLE labor_allocation.agent_model_version ADD CONSTRAINT agent_model_version_component_version_key UNIQUE (component, version);

ALTER TABLE labor_allocation.agent_playbook ADD CONSTRAINT agent_playbook_dc_id_business_date_key UNIQUE (dc_id, business_date);

ALTER TABLE labor_allocation.associate ADD CONSTRAINT associate_kronos_person_num_key UNIQUE (kronos_person_num);

ALTER TABLE labor_allocation.dc ADD CONSTRAINT dc_dc_code_key UNIQUE (dc_code);

ALTER TABLE labor_allocation.dc_zone ADD CONSTRAINT dc_zone_dc_id_zone_code_key UNIQUE (dc_id, zone_code);

ALTER TABLE legacy.agent_recommendations ADD CONSTRAINT agent_recommendations_severity_check CHECK ((severity = ANY (ARRAY['Low'::text, 'Medium'::text, 'High'::text, 'Critical'::text])));

ALTER TABLE legacy.agent_recommendations ADD CONSTRAINT agent_recommendations_status_check CHECK ((status = ANY (ARRAY['Open'::text, 'Accepted'::text, 'Dismissed'::text, 'Resolved'::text])));

ALTER TABLE legacy.agents ADD CONSTRAINT agents_priority_check CHECK ((priority = ANY (ARRAY['Low'::text, 'Medium'::text, 'High'::text])));

ALTER TABLE labor_allocation.agent_bottleneck_alert ADD CONSTRAINT agent_bottleneck_alert_severity_check CHECK ((severity = ANY (ARRAY['LOW'::text, 'MEDIUM'::text, 'HIGH'::text, 'CRITICAL'::text])));

ALTER TABLE labor_allocation.agent_bottleneck_alert ADD CONSTRAINT agent_bottleneck_alert_status_check CHECK ((status = ANY (ARRAY['OPEN'::text, 'MITIGATED'::text, 'BREACHED'::text, 'FALSE_POSITIVE'::text])));

ALTER TABLE labor_allocation.agent_outcome ADD CONSTRAINT agent_outcome_outcome_label_check CHECK ((outcome_label = ANY (ARRAY['EFFECTIVE'::text, 'PARTIALLY_EFFECTIVE'::text, 'INEFFECTIVE'::text, 'ADVERSE'::text])));

ALTER TABLE labor_allocation.agent_playbook ADD CONSTRAINT agent_playbook_status_check CHECK ((status = ANY (ARRAY['SHADOW'::text, 'DRAFT'::text, 'PUBLISHED'::text, 'ACKNOWLEDGED'::text])));

ALTER TABLE labor_allocation.agent_recommendation ADD CONSTRAINT agent_recommendation_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'ACCEPTED'::text, 'REJECTED'::text, 'EXPIRED'::text, 'AUTO_EXECUTED'::text, 'SHADOW_LOGGED'::text])));

ALTER TABLE labor_allocation.agent_rollout ADD CONSTRAINT agent_rollout_phase_check CHECK ((phase = ANY (ARRAY['BASELINE'::text, 'SHADOW'::text, 'ASSISTED'::text, 'AUTO'::text])));

ALTER TABLE labor_allocation.ai_opportunity ADD CONSTRAINT ai_opportunity_priority_check CHECK ((priority = ANY (ARRAY['High'::text, 'Medium'::text, 'Low'::text])));

ALTER TABLE labor_allocation.associate ADD CONSTRAINT associate_employment_type_check CHECK ((employment_type = ANY (ARRAY['FT'::text, 'PT'::text, 'TEMP'::text])));

ALTER TABLE labor_allocation.associate ADD CONSTRAINT associate_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'TERMINATED'::text])));

ALTER TABLE labor_allocation.associate_skill ADD CONSTRAINT associate_skill_proficiency_check CHECK (((proficiency >= 1) AND (proficiency <= 4)));

ALTER TABLE labor_allocation.associate_skill ADD CONSTRAINT associate_skill_source_check CHECK ((source = ANY (ARRAY['HOME_ROLE'::text, 'CROSS_TRAINED'::text, 'AGENT_CROSS_TRAIN'::text])));

ALTER TABLE labor_allocation.dc ADD CONSTRAINT dc_agent_cohort_check CHECK ((agent_cohort = ANY (ARRAY['PILOT_WAVE_1'::text, 'PILOT_WAVE_2'::text, 'CONTROL'::text])));

ALTER TABLE labor_allocation.dc ADD CONSTRAINT dc_dc_type_check CHECK ((dc_type = ANY (ARRAY['ECOM_FC'::text, 'OMNI_DC'::text, 'RETAIL_DC'::text])));

ALTER TABLE labor_allocation.labor_constraint_rule ADD CONSTRAINT labor_constraint_rule_rule_type_check CHECK ((rule_type = ANY (ARRAY['HARD'::text, 'SOFT'::text])));

ALTER TABLE labor_allocation.ops_labor_move ADD CONSTRAINT ops_labor_move_move_source_check CHECK ((move_source = ANY (ARRAY['AGENT_ASSISTED'::text, 'AGENT_AUTO'::text, 'PLAYBOOK'::text, 'SUPERVISOR_ADHOC'::text])));

ALTER TABLE labor_allocation.poc_kpi_target ADD CONSTRAINT poc_kpi_target_better_direction_check CHECK ((better_direction = ANY (ARRAY['UP'::text, 'DOWN'::text])));


-- Indexes on tables (37)

CREATE INDEX idx_inv_snap_date ON legacy.inventory_snapshots USING btree (snapshot_date);

CREATE INDEX idx_inv_snap_wh_prod ON legacy.inventory_snapshots USING btree (warehouse_id, product_id);

CREATE INDEX idx_orders_ts ON legacy.orders USING btree (order_ts);

CREATE INDEX idx_orders_wh ON legacy.orders USING btree (warehouse_id);

CREATE INDEX idx_orders_customer ON legacy.orders USING btree (customer_id);

CREATE INDEX idx_orders_status ON legacy.orders USING btree (status);

CREATE INDEX idx_order_items_order ON legacy.order_items USING btree (order_id);

CREATE INDEX idx_order_items_product ON legacy.order_items USING btree (product_id);

CREATE INDEX idx_shipments_order ON legacy.shipments USING btree (order_id);

CREATE INDEX idx_shipments_wh ON legacy.shipments USING btree (warehouse_id);

CREATE INDEX idx_labor_wh_date ON legacy.labor_shifts USING btree (warehouse_id, shift_date);

CREATE INDEX idx_agent_rec_agent ON legacy.agent_recommendations USING btree (agent_id);

CREATE INDEX idx_agent_rec_wh ON legacy.agent_recommendations USING btree (warehouse_id);

CREATE INDEX idx_agent_rec_status ON legacy.agent_recommendations USING btree (status);

CREATE INDEX ix_associate_dc ON labor_allocation.associate USING btree (dc_id, status);

CREATE INDEX ix_associate_zone ON labor_allocation.associate USING btree (home_zone_id);

CREATE INDEX ix_askill_skill ON labor_allocation.associate_skill USING btree (skill_code, proficiency);

CREATE INDEX ix_plan_date ON labor_allocation.wfm_static_labor_plan USING btree (business_date);

CREATE INDEX ix_timecard_dc_date ON labor_allocation.wfm_timecard USING btree (dc_id, business_date);

CREATE INDEX ix_timecard_open ON labor_allocation.wfm_timecard USING btree (dc_id) WHERE ((clock_in IS NOT NULL) AND (clock_out IS NULL));

CREATE INDEX ix_lms_brin_date ON labor_allocation.lms_associate_daily USING brin (business_date);

CREATE INDEX ix_lms_zone_date ON labor_allocation.lms_associate_daily USING btree (zone_id, business_date);

CREATE INDEX ix_appt_dc_time ON labor_allocation.wms_inbound_appointment USING btree (dc_id, scheduled_at);

CREATE INDEX ix_equip_dc_time ON labor_allocation.wms_equipment_downtime USING btree (dc_id, started_at);

CREATE INDEX ix_interval_brin_date ON labor_allocation.wms_zone_interval USING brin (business_date);

CREATE INDEX ix_interval_brin_ts ON labor_allocation.wms_zone_interval USING brin (interval_start);

CREATE INDEX ix_episode_dc_date ON labor_allocation.ops_bottleneck_episode USING btree (dc_id, business_date);

CREATE INDEX ix_ff_dc_time ON labor_allocation.ops_firefighting_event USING btree (dc_id, occurred_at);

CREATE INDEX ix_cutoff_perf_date ON labor_allocation.ops_cutoff_performance USING btree (business_date);

CREATE INDEX ix_move_dc_date ON labor_allocation.ops_labor_move USING btree (dc_id, business_date);

CREATE INDEX ix_move_associate ON labor_allocation.ops_labor_move USING btree (associate_id);

CREATE INDEX ix_move_rec ON labor_allocation.ops_labor_move USING btree (rec_id);

CREATE INDEX ix_alert_dc_time ON labor_allocation.agent_bottleneck_alert USING btree (dc_id, detected_at);

CREATE INDEX ix_alert_open ON labor_allocation.agent_bottleneck_alert USING btree (dc_id) WHERE (status = 'OPEN'::text);

CREATE INDEX ix_rec_dc_time ON labor_allocation.agent_recommendation USING btree (dc_id, created_at);

CREATE INDEX ix_rec_status ON labor_allocation.agent_recommendation USING btree (status, rec_type);

CREATE INDEX ix_fcst_dc_date ON labor_allocation.agent_workload_forecast USING btree (dc_id, business_date);


-- Foreign keys (88)

ALTER TABLE legacy.agent_benefits ADD CONSTRAINT agent_benefits_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES legacy.agents(id) ON DELETE CASCADE;

ALTER TABLE legacy.agent_recommendations ADD CONSTRAINT agent_recommendations_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES legacy.agents(id);

ALTER TABLE legacy.agent_recommendations ADD CONSTRAINT agent_recommendations_product_id_fkey FOREIGN KEY (product_id) REFERENCES legacy.products(id);

ALTER TABLE legacy.agent_recommendations ADD CONSTRAINT agent_recommendations_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES legacy.warehouses(id);

ALTER TABLE legacy.agents ADD CONSTRAINT agents_category_id_fkey FOREIGN KEY (category_id) REFERENCES legacy.categories(id);

ALTER TABLE legacy.inventory_snapshots ADD CONSTRAINT inventory_snapshots_product_id_fkey FOREIGN KEY (product_id) REFERENCES legacy.products(id);

ALTER TABLE legacy.inventory_snapshots ADD CONSTRAINT inventory_snapshots_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES legacy.warehouses(id);

ALTER TABLE legacy.labor_shifts ADD CONSTRAINT labor_shifts_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES legacy.warehouses(id);

ALTER TABLE legacy.order_items ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES legacy.orders(id) ON DELETE CASCADE;

ALTER TABLE legacy.order_items ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES legacy.products(id);

ALTER TABLE legacy.orders ADD CONSTRAINT orders_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES legacy.customers(id);

ALTER TABLE legacy.orders ADD CONSTRAINT orders_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES legacy.warehouses(id);

ALTER TABLE legacy.shipments ADD CONSTRAINT shipments_order_id_fkey FOREIGN KEY (order_id) REFERENCES legacy.orders(id) ON DELETE CASCADE;

ALTER TABLE legacy.shipments ADD CONSTRAINT shipments_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES legacy.warehouses(id);

ALTER TABLE legacy.warehouse_risk_scores ADD CONSTRAINT warehouse_risk_scores_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES legacy.warehouses(id);

ALTER TABLE labor_allocation.agent_bottleneck_alert ADD CONSTRAINT agent_bottleneck_alert_cutoff_id_fkey FOREIGN KEY (cutoff_id) REFERENCES labor_allocation.carrier_cutoff(cutoff_id);

ALTER TABLE labor_allocation.agent_bottleneck_alert ADD CONSTRAINT agent_bottleneck_alert_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.agent_bottleneck_alert ADD CONSTRAINT agent_bottleneck_alert_episode_id_fkey FOREIGN KEY (episode_id) REFERENCES labor_allocation.ops_bottleneck_episode(episode_id);

ALTER TABLE labor_allocation.agent_bottleneck_alert ADD CONSTRAINT agent_bottleneck_alert_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES labor_allocation.agent_model_version(model_version_id);

ALTER TABLE labor_allocation.agent_bottleneck_alert ADD CONSTRAINT agent_bottleneck_alert_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.agent_outcome ADD CONSTRAINT agent_outcome_rec_id_fkey FOREIGN KEY (rec_id) REFERENCES labor_allocation.agent_recommendation(rec_id);

ALTER TABLE labor_allocation.agent_playbook ADD CONSTRAINT agent_playbook_acknowledged_by_supervisor_id_fkey FOREIGN KEY (acknowledged_by_supervisor_id) REFERENCES labor_allocation.ops_supervisor(supervisor_id);

ALTER TABLE labor_allocation.agent_playbook ADD CONSTRAINT agent_playbook_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.agent_playbook ADD CONSTRAINT agent_playbook_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES labor_allocation.agent_model_version(model_version_id);

ALTER TABLE labor_allocation.agent_playbook_line ADD CONSTRAINT agent_playbook_line_playbook_id_fkey FOREIGN KEY (playbook_id) REFERENCES labor_allocation.agent_playbook(playbook_id);

ALTER TABLE labor_allocation.agent_playbook_line ADD CONSTRAINT agent_playbook_line_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.agent_recommendation ADD CONSTRAINT agent_recommendation_alert_id_fkey FOREIGN KEY (alert_id) REFERENCES labor_allocation.agent_bottleneck_alert(alert_id);

ALTER TABLE labor_allocation.agent_recommendation ADD CONSTRAINT agent_recommendation_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.agent_recommendation ADD CONSTRAINT agent_recommendation_decided_by_supervisor_id_fkey FOREIGN KEY (decided_by_supervisor_id) REFERENCES labor_allocation.ops_supervisor(supervisor_id);

ALTER TABLE labor_allocation.agent_recommendation ADD CONSTRAINT agent_recommendation_from_zone_id_fkey FOREIGN KEY (from_zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.agent_recommendation ADD CONSTRAINT agent_recommendation_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES labor_allocation.agent_model_version(model_version_id);

ALTER TABLE labor_allocation.agent_recommendation ADD CONSTRAINT agent_recommendation_skill_code_fkey FOREIGN KEY (skill_code) REFERENCES labor_allocation.skill(skill_code);

ALTER TABLE labor_allocation.agent_recommendation ADD CONSTRAINT agent_recommendation_to_zone_id_fkey FOREIGN KEY (to_zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.agent_rollout ADD CONSTRAINT agent_rollout_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.agent_training_run ADD CONSTRAINT agent_training_run_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES labor_allocation.agent_model_version(model_version_id);

ALTER TABLE labor_allocation.agent_training_run ADD CONSTRAINT agent_training_run_scope_dc_id_fkey FOREIGN KEY (scope_dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.agent_workload_forecast ADD CONSTRAINT agent_workload_forecast_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.agent_workload_forecast ADD CONSTRAINT agent_workload_forecast_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES labor_allocation.agent_model_version(model_version_id);

ALTER TABLE labor_allocation.agent_workload_forecast ADD CONSTRAINT agent_workload_forecast_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.associate ADD CONSTRAINT associate_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.associate ADD CONSTRAINT associate_dc_id_shift_code_fkey FOREIGN KEY (dc_id, shift_code) REFERENCES labor_allocation.shift_definition(dc_id, shift_code);

ALTER TABLE labor_allocation.associate ADD CONSTRAINT associate_home_zone_id_fkey FOREIGN KEY (home_zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.associate_skill ADD CONSTRAINT associate_skill_associate_id_fkey FOREIGN KEY (associate_id) REFERENCES labor_allocation.associate(associate_id);

ALTER TABLE labor_allocation.associate_skill ADD CONSTRAINT associate_skill_recommended_by_rec_id_fkey FOREIGN KEY (recommended_by_rec_id) REFERENCES labor_allocation.agent_recommendation(rec_id);

ALTER TABLE labor_allocation.associate_skill ADD CONSTRAINT associate_skill_skill_code_fkey FOREIGN KEY (skill_code) REFERENCES labor_allocation.skill(skill_code);

ALTER TABLE labor_allocation.carrier_cutoff ADD CONSTRAINT carrier_cutoff_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.dc_zone ADD CONSTRAINT dc_zone_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.dc_zone ADD CONSTRAINT dc_zone_function_code_fkey FOREIGN KEY (function_code) REFERENCES labor_allocation.labor_function(function_code);

ALTER TABLE labor_allocation.dc_zone ADD CONSTRAINT dc_zone_primary_skill_code_fkey FOREIGN KEY (primary_skill_code) REFERENCES labor_allocation.skill(skill_code);

ALTER TABLE labor_allocation.lms_associate_daily ADD CONSTRAINT lms_associate_daily_associate_id_fkey FOREIGN KEY (associate_id) REFERENCES labor_allocation.associate(associate_id);

ALTER TABLE labor_allocation.lms_associate_daily ADD CONSTRAINT lms_associate_daily_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.lms_associate_daily ADD CONSTRAINT lms_associate_daily_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.ops_bottleneck_episode ADD CONSTRAINT ops_bottleneck_episode_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.ops_bottleneck_episode ADD CONSTRAINT ops_bottleneck_episode_first_alert_id_fkey FOREIGN KEY (first_alert_id) REFERENCES labor_allocation.agent_bottleneck_alert(alert_id);

ALTER TABLE labor_allocation.ops_bottleneck_episode ADD CONSTRAINT ops_bottleneck_episode_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.ops_cutoff_performance ADD CONSTRAINT ops_cutoff_performance_cutoff_id_fkey FOREIGN KEY (cutoff_id) REFERENCES labor_allocation.carrier_cutoff(cutoff_id);

ALTER TABLE labor_allocation.ops_cutoff_performance ADD CONSTRAINT ops_cutoff_performance_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.ops_firefighting_event ADD CONSTRAINT ops_firefighting_event_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.ops_firefighting_event ADD CONSTRAINT ops_firefighting_event_episode_id_fkey FOREIGN KEY (episode_id) REFERENCES labor_allocation.ops_bottleneck_episode(episode_id);

ALTER TABLE labor_allocation.ops_firefighting_event ADD CONSTRAINT ops_firefighting_event_supervisor_id_fkey FOREIGN KEY (supervisor_id) REFERENCES labor_allocation.ops_supervisor(supervisor_id);

ALTER TABLE labor_allocation.ops_firefighting_event ADD CONSTRAINT ops_firefighting_event_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.ops_labor_move ADD CONSTRAINT ops_labor_move_associate_id_fkey FOREIGN KEY (associate_id) REFERENCES labor_allocation.associate(associate_id);

ALTER TABLE labor_allocation.ops_labor_move ADD CONSTRAINT ops_labor_move_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.ops_labor_move ADD CONSTRAINT ops_labor_move_firefight_event_id_fkey FOREIGN KEY (firefight_event_id) REFERENCES labor_allocation.ops_firefighting_event(event_id);

ALTER TABLE labor_allocation.ops_labor_move ADD CONSTRAINT ops_labor_move_from_zone_id_fkey FOREIGN KEY (from_zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.ops_labor_move ADD CONSTRAINT ops_labor_move_rec_id_fkey FOREIGN KEY (rec_id) REFERENCES labor_allocation.agent_recommendation(rec_id);

ALTER TABLE labor_allocation.ops_labor_move ADD CONSTRAINT ops_labor_move_to_zone_id_fkey FOREIGN KEY (to_zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.ops_supervisor ADD CONSTRAINT ops_supervisor_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.pay_rate_card ADD CONSTRAINT pay_rate_card_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.shift_definition ADD CONSTRAINT shift_definition_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.skill ADD CONSTRAINT skill_function_code_fkey FOREIGN KEY (function_code) REFERENCES labor_allocation.labor_function(function_code);

ALTER TABLE labor_allocation.wfm_static_labor_plan ADD CONSTRAINT wfm_static_labor_plan_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.wfm_static_labor_plan ADD CONSTRAINT wfm_static_labor_plan_dc_id_shift_code_fkey FOREIGN KEY (dc_id, shift_code) REFERENCES labor_allocation.shift_definition(dc_id, shift_code);

ALTER TABLE labor_allocation.wfm_static_labor_plan ADD CONSTRAINT wfm_static_labor_plan_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.wfm_timecard ADD CONSTRAINT wfm_timecard_associate_id_fkey FOREIGN KEY (associate_id) REFERENCES labor_allocation.associate(associate_id);

ALTER TABLE labor_allocation.wfm_timecard ADD CONSTRAINT wfm_timecard_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.wfm_timecard ADD CONSTRAINT wfm_timecard_home_zone_id_fkey FOREIGN KEY (home_zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.wms_equipment_downtime ADD CONSTRAINT wms_equipment_downtime_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.wms_equipment_downtime ADD CONSTRAINT wms_equipment_downtime_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.wms_inbound_appointment ADD CONSTRAINT wms_inbound_appointment_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.wms_zone_interval ADD CONSTRAINT wms_zone_interval_dc_id_fkey FOREIGN KEY (dc_id) REFERENCES labor_allocation.dc(dc_id);

ALTER TABLE labor_allocation.wms_zone_interval ADD CONSTRAINT wms_zone_interval_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.zone_flow ADD CONSTRAINT zone_flow_from_zone_id_fkey FOREIGN KEY (from_zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.zone_flow ADD CONSTRAINT zone_flow_to_zone_id_fkey FOREIGN KEY (to_zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.zone_skill_requirement ADD CONSTRAINT zone_skill_requirement_skill_code_fkey FOREIGN KEY (skill_code) REFERENCES labor_allocation.skill(skill_code);

ALTER TABLE labor_allocation.zone_skill_requirement ADD CONSTRAINT zone_skill_requirement_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.zone_travel_time ADD CONSTRAINT zone_travel_time_from_zone_id_fkey FOREIGN KEY (from_zone_id) REFERENCES labor_allocation.dc_zone(zone_id);

ALTER TABLE labor_allocation.zone_travel_time ADD CONSTRAINT zone_travel_time_to_zone_id_fkey FOREIGN KEY (to_zone_id) REFERENCES labor_allocation.dc_zone(zone_id);


-- Views and materialized views (29)

CREATE VIEW legacy.v_executive_summary AS
SELECT 'impact_by_severity'::text AS section,
    agent_recommendations.severity AS key,
    NULL::text AS key2,
    (count(*))::numeric AS metric1,
    sum(agent_recommendations.projected_impact_usd) AS metric2
   FROM legacy.agent_recommendations
  WHERE (agent_recommendations.status = 'Open'::text)
  GROUP BY agent_recommendations.severity
UNION ALL
 SELECT 'top_risk_warehouses'::text AS section,
    w.code AS key,
    w.region AS key2,
    r.composite_score AS metric1,
    NULL::numeric AS metric2
   FROM (legacy.warehouse_risk_scores r
     JOIN legacy.warehouses w ON ((w.id = r.warehouse_id)))
  WHERE (r.as_of_date = ( SELECT max(warehouse_risk_scores.as_of_date) AS max
           FROM legacy.warehouse_risk_scores))
  ORDER BY 1, 4 DESC NULLS LAST;

CREATE MATERIALIZED VIEW labor_allocation.mv_zone_daily AS
SELECT dc_id,
    zone_id,
    business_date,
    sum(workload_in) AS workload_in,
    sum(workload_done) AS workload_done,
    round((sum(direct_hours))::numeric, 2) AS direct_hours,
    round((sum(idle_hours))::numeric, 2) AS idle_hours,
    ((count(*) FILTER (WHERE is_bottleneck) * 15))::integer AS bottleneck_minutes,
    max(queue_depth) AS peak_queue,
    max(oldest_task_age_min) AS peak_task_age_min,
    round((avg(hc_actual))::numeric, 2) AS avg_hc_actual,
    round((avg(hc_planned))::numeric, 2) AS avg_hc_planned,
    sum(fcst_dayahead) AS fcst_dayahead,
    (count(*))::integer AS intervals
   FROM labor_allocation.wms_zone_interval i
  GROUP BY dc_id, zone_id, business_date
WITH DATA;

CREATE MATERIALIZED VIEW labor_allocation.mv_dc_daily AS
WITH tc AS (
         SELECT wfm_timecard.dc_id,
            wfm_timecard.business_date,
            count(*) FILTER (WHERE (wfm_timecard.clock_in IS NOT NULL)) AS associates_worked,
            count(*) FILTER (WHERE (wfm_timecard.absence_code = ANY (ARRAY['CALLOUT'::text, 'NCNS'::text, 'FMLA'::text]))) AS unplanned_absences,
            count(*) AS associates_scheduled,
            sum(wfm_timecard.regular_hours) AS regular_hours,
            sum(wfm_timecard.overtime_hours) AS overtime_hours,
            COALESCE(sum(wfm_timecard.overtime_hours) FILTER (WHERE (wfm_timecard.ot_type = 'VET'::text)), (0)::real) AS vet_hours,
            COALESCE(sum(wfm_timecard.overtime_hours) FILTER (WHERE (wfm_timecard.ot_type = ANY (ARRAY['SCHEDULED'::text, 'MANDATORY'::text]))), (0)::real) AS mandatory_ot_hours,
            sum(wfm_timecard.vto_hours) AS vto_hours,
            sum(wfm_timecard.labor_cost_usd) AS labor_cost_usd
           FROM labor_allocation.wfm_timecard
          GROUP BY wfm_timecard.dc_id, wfm_timecard.business_date
        ), zd AS (
         SELECT m.dc_id,
            m.business_date,
            sum(m.direct_hours) AS direct_hours,
            sum(m.idle_hours) AS idle_hours,
            sum(m.bottleneck_minutes) AS bottleneck_minutes,
            sum(((m.workload_done)::double precision * z.units_per_uom)) FILTER (WHERE (z.function_code = 'SHIP'::text)) AS units_shipped
           FROM (labor_allocation.mv_zone_daily m
             JOIN labor_allocation.dc_zone z USING (zone_id))
          GROUP BY m.dc_id, m.business_date
        ), co AS (
         SELECT ops_cutoff_performance.dc_id,
            ops_cutoff_performance.business_date,
            sum(ops_cutoff_performance.units_due) AS units_due,
            sum(ops_cutoff_performance.units_on_time) AS units_on_time,
            sum(ops_cutoff_performance.units_missed) AS units_missed,
            sum(ops_cutoff_performance.miss_cost_usd) AS miss_cost_usd
           FROM labor_allocation.ops_cutoff_performance
          GROUP BY ops_cutoff_performance.dc_id, ops_cutoff_performance.business_date
        ), ff AS (
         SELECT f.dc_id,
            (((f.occurred_at AT TIME ZONE d_1.timezone) - '06:00:00'::interval))::date AS business_date,
            count(*) AS firefighting_events,
            sum(f.supervisor_minutes) AS firefighting_minutes
           FROM (labor_allocation.ops_firefighting_event f
             JOIN labor_allocation.dc d_1 USING (dc_id))
          GROUP BY f.dc_id, ((((f.occurred_at AT TIME ZONE d_1.timezone) - '06:00:00'::interval))::date)
        ), ep AS (
         SELECT ops_bottleneck_episode.dc_id,
            ops_bottleneck_episode.business_date,
            count(*) AS bottleneck_episodes
           FROM labor_allocation.ops_bottleneck_episode
          GROUP BY ops_bottleneck_episode.dc_id, ops_bottleneck_episode.business_date
        ), mv AS (
         SELECT ops_labor_move.dc_id,
            ops_labor_move.business_date,
            count(*) AS labor_moves,
            count(*) FILTER (WHERE (ops_labor_move.move_source = ANY (ARRAY['AGENT_ASSISTED'::text, 'AGENT_AUTO'::text, 'PLAYBOOK'::text]))) AS agent_moves
           FROM labor_allocation.ops_labor_move
          GROUP BY ops_labor_move.dc_id, ops_labor_move.business_date
        ), rc AS (
         SELECT r.dc_id,
            (((r.created_at AT TIME ZONE d_1.timezone) - '06:00:00'::interval))::date AS business_date,
            count(*) AS recommendations,
            count(*) FILTER (WHERE (r.status = ANY (ARRAY['ACCEPTED'::text, 'AUTO_EXECUTED'::text]))) AS recommendations_executed
           FROM (labor_allocation.agent_recommendation r
             JOIN labor_allocation.dc d_1 USING (dc_id))
          GROUP BY r.dc_id, ((((r.created_at AT TIME ZONE d_1.timezone) - '06:00:00'::interval))::date)
        )
 SELECT tc.dc_id,
    d.dc_code,
    d.dc_type,
    d.agent_cohort,
    tc.business_date,
    ro.phase AS agent_mode,
    (tc.business_date <= ( SELECT (poc_config.value)::date AS value
           FROM labor_allocation.poc_config
          WHERE (poc_config.key = 'data_window_end'::text))) AS is_complete_day,
    (COALESCE(zd.units_shipped, (0)::double precision))::numeric(14,1) AS units_shipped,
    tc.associates_scheduled,
    tc.associates_worked,
    tc.unplanned_absences,
    (tc.regular_hours)::numeric(12,2) AS regular_hours,
    (tc.overtime_hours)::numeric(12,2) AS overtime_hours,
    (tc.vet_hours)::numeric(12,2) AS vet_hours,
    (tc.mandatory_ot_hours)::numeric(12,2) AS mandatory_ot_hours,
    (tc.vto_hours)::numeric(12,2) AS vto_hours,
    ((tc.regular_hours + tc.overtime_hours))::numeric(12,2) AS paid_hours,
    (tc.labor_cost_usd)::numeric(14,2) AS labor_cost_usd,
    (zd.direct_hours)::numeric(12,2) AS direct_hours,
    (zd.idle_hours)::numeric(12,2) AS idle_hours,
    COALESCE(zd.bottleneck_minutes, (0)::bigint) AS bottleneck_minutes,
    COALESCE(ep.bottleneck_episodes, (0)::bigint) AS bottleneck_episodes,
    COALESCE(co.units_due, (0)::bigint) AS units_due,
    COALESCE(co.units_on_time, (0)::bigint) AS units_on_time,
    COALESCE(co.units_missed, (0)::bigint) AS units_missed,
    (COALESCE(co.miss_cost_usd, (0)::real))::numeric(12,2) AS sla_miss_cost_usd,
    COALESCE(ff.firefighting_events, (0)::bigint) AS firefighting_events,
    COALESCE(ff.firefighting_minutes, (0)::bigint) AS firefighting_minutes,
    COALESCE(mv.labor_moves, (0)::bigint) AS labor_moves,
    COALESCE(mv.agent_moves, (0)::bigint) AS agent_moves,
    COALESCE(rc.recommendations, (0)::bigint) AS recommendations,
    COALESCE(rc.recommendations_executed, (0)::bigint) AS recommendations_executed
   FROM ((((((((tc
     JOIN labor_allocation.dc d USING (dc_id))
     LEFT JOIN zd USING (dc_id, business_date))
     LEFT JOIN co USING (dc_id, business_date))
     LEFT JOIN ff USING (dc_id, business_date))
     LEFT JOIN ep USING (dc_id, business_date))
     LEFT JOIN mv USING (dc_id, business_date))
     LEFT JOIN rc USING (dc_id, business_date))
     JOIN LATERAL ( SELECT r.phase
           FROM labor_allocation.agent_rollout r
          WHERE ((r.dc_id = tc.dc_id) AND ((tc.business_date >= r.start_date) AND (tc.business_date <= COALESCE(r.end_date, '9999-12-31'::date))))
         LIMIT 1) ro ON (true))
WITH DATA;

CREATE MATERIALIZED VIEW labor_allocation.mv_forecast_accuracy AS
WITH h AS (
         SELECT i.dc_id,
            i.zone_id,
            i.business_date,
            (i.local_slot / 4) AS local_hour,
            sum(i.workload_in) AS actual,
            sum(i.fcst_dayahead) AS fcst_dayahead,
            sum(i.fcst_intraday) AS fcst_intraday
           FROM (labor_allocation.wms_zone_interval i
             JOIN labor_allocation.dc_zone z_1 USING (zone_id))
          WHERE ((i.fcst_dayahead IS NOT NULL) AND (z_1.work_source IS NOT NULL) AND (i.business_date <= ( SELECT (poc_config.value)::date AS value
                   FROM labor_allocation.poc_config
                  WHERE (poc_config.key = 'data_window_end'::text))))
          GROUP BY i.dc_id, i.zone_id, i.business_date, (i.local_slot / 4)
        )
 SELECT h.dc_id,
    (date_trunc('week'::text, (h.business_date)::timestamp with time zone))::date AS week_start,
    z.function_code,
    (sum(h.actual))::bigint AS actual_workload,
    (sum(abs((h.actual - h.fcst_dayahead))))::bigint AS abs_error_dayahead,
    (sum(abs((h.actual - h.fcst_intraday))))::bigint AS abs_error_intraday,
    (sum((h.fcst_dayahead - h.actual)))::bigint AS bias_dayahead
   FROM (h
     JOIN labor_allocation.dc_zone z USING (zone_id))
  GROUP BY h.dc_id, ((date_trunc('week'::text, (h.business_date)::timestamp with time zone))::date), z.function_code
WITH DATA;

CREATE MATERIALIZED VIEW labor_allocation.mv_bottleneck_heatmap AS
SELECT d.agent_cohort,
        CASE
            WHEN (ro.phase = ANY (ARRAY['ASSISTED'::text, 'AUTO'::text])) THEN 'AGENT_LIVE'::text
            ELSE 'STATIC_PLAN'::text
        END AS operating_model,
    z.function_code,
    (i.local_slot / 4) AS local_hour,
    (count(*))::integer AS intervals,
    (count(*) FILTER (WHERE i.is_bottleneck))::integer AS bottleneck_intervals,
    round(((100.0 * (count(*) FILTER (WHERE i.is_bottleneck))::numeric) / (count(*))::numeric), 2) AS bottleneck_pct,
    round(((avg((i.idle_hours / NULLIF((i.idle_hours + i.direct_hours), (0)::double precision))))::numeric * (100)::numeric), 1) AS idle_pct
   FROM (((labor_allocation.wms_zone_interval i
     JOIN labor_allocation.dc_zone z USING (zone_id))
     JOIN labor_allocation.dc d ON ((d.dc_id = i.dc_id)))
     JOIN labor_allocation.agent_rollout ro ON (((ro.dc_id = i.dc_id) AND ((i.business_date >= ro.start_date) AND (i.business_date <= COALESCE(ro.end_date, '9999-12-31'::date))))))
  WHERE (i.business_date <= ( SELECT (poc_config.value)::date AS value
           FROM labor_allocation.poc_config
          WHERE (poc_config.key = 'data_window_end'::text)))
  GROUP BY d.agent_cohort,
        CASE
            WHEN (ro.phase = ANY (ARRAY['ASSISTED'::text, 'AUTO'::text])) THEN 'AGENT_LIVE'::text
            ELSE 'STATIC_PLAN'::text
        END, z.function_code, (i.local_slot / 4)
WITH DATA;

CREATE VIEW labor_allocation.vw_dc_daily_kpi AS
SELECT dc_id,
    dc_code,
    dc_type,
    agent_cohort,
    business_date,
    agent_mode,
    is_complete_day,
    units_shipped,
    associates_scheduled,
    associates_worked,
    unplanned_absences,
    regular_hours,
    overtime_hours,
    vet_hours,
    mandatory_ot_hours,
    vto_hours,
    paid_hours,
    labor_cost_usd,
    direct_hours,
    idle_hours,
    bottleneck_minutes,
    bottleneck_episodes,
    units_due,
    units_on_time,
    units_missed,
    sla_miss_cost_usd,
    firefighting_events,
    firefighting_minutes,
    labor_moves,
    agent_moves,
    recommendations,
    recommendations_executed,
    round((units_shipped / NULLIF(paid_hours, (0)::numeric)), 2) AS units_per_labor_hour,
    round((((100)::numeric * idle_hours) / NULLIF((idle_hours + direct_hours), (0)::numeric)), 2) AS idle_pct,
    round(((100.0 * (units_on_time)::numeric) / (NULLIF(units_due, 0))::numeric), 2) AS sla_pct,
    round((((100)::numeric * overtime_hours) / NULLIF(paid_hours, (0)::numeric)), 2) AS overtime_pct,
    round((labor_cost_usd / NULLIF(units_shipped, (0)::numeric)), 4) AS labor_cost_per_unit,
    round(((100.0 * (unplanned_absences)::numeric) / (NULLIF(associates_scheduled, 0))::numeric), 2) AS absenteeism_pct
   FROM labor_allocation.mv_dc_daily m;

CREATE VIEW labor_allocation.vw_dc_zone_daily AS
SELECT d.dc_code,
    z.zone_code,
    z.zone_name,
    z.function_code,
    z.uom,
    m.dc_id,
    m.zone_id,
    m.business_date,
    m.workload_in,
    m.workload_done,
    m.direct_hours,
    m.idle_hours,
    m.bottleneck_minutes,
    m.peak_queue,
    m.peak_task_age_min,
    m.avg_hc_actual,
    m.avg_hc_planned,
    m.fcst_dayahead,
    m.intervals,
    round((((100)::numeric * m.idle_hours) / NULLIF((m.idle_hours + m.direct_hours), (0)::numeric)), 2) AS idle_pct,
    round(((((m.workload_done)::numeric / NULLIF(m.direct_hours, (0)::numeric)) / (z.standard_uph)::numeric) * (100)::numeric), 1) AS pct_to_standard
   FROM ((labor_allocation.mv_zone_daily m
     JOIN labor_allocation.dc_zone z USING (zone_id))
     JOIN labor_allocation.dc d ON ((d.dc_id = m.dc_id)));

CREATE VIEW labor_allocation.vw_exec_poc_scorecard AS
WITH win AS (
         SELECT 'PILOT_WAVE_1'::text AS comparison,
            (split_part(a.value, '..'::text, 1))::date AS pre_s,
            (split_part(a.value, '..'::text, 2))::date AS pre_e,
            (split_part(b.value, '..'::text, 1))::date AS post_s,
            (split_part(b.value, '..'::text, 2))::date AS post_e
           FROM labor_allocation.poc_config a,
            labor_allocation.poc_config b
          WHERE ((a.key = 'did_pre_window'::text) AND (b.key = 'did_post_window'::text))
        UNION ALL
         SELECT 'PILOT_WAVE_2'::text,
            (split_part(a.value, '..'::text, 1))::date AS split_part,
            (split_part(a.value, '..'::text, 2))::date AS split_part,
            (split_part(b.value, '..'::text, 1))::date AS split_part,
            (split_part(b.value, '..'::text, 2))::date AS split_part
           FROM labor_allocation.poc_config a,
            labor_allocation.poc_config b
          WHERE ((a.key = 'did_pre_window_wave2'::text) AND (b.key = 'did_post_window_wave2'::text))
        ), g AS (
         SELECT w.comparison,
                CASE
                    WHEN (m.agent_cohort = w.comparison) THEN 'PILOT'::text
                    ELSE 'CONTROL'::text
                END AS grp,
                CASE
                    WHEN (m.business_date <= w.pre_e) THEN 'PRE'::text
                    ELSE 'POST'::text
                END AS period,
            count(*) AS dc_days,
            sum(m.units_shipped) AS units,
            sum(m.paid_hours) AS paid_hours,
            sum(m.overtime_hours) AS ot_hours,
            sum(m.direct_hours) AS direct_hours,
            sum(m.idle_hours) AS idle_hours,
            sum(m.bottleneck_minutes) AS bn_min,
            sum(m.units_due) AS due,
            sum(m.units_on_time) AS on_time,
            sum(m.firefighting_events) AS ff,
            sum(m.labor_cost_usd) AS cost,
            sum(m.associates_worked) AS heads
           FROM (labor_allocation.mv_dc_daily m
             JOIN win w ON (((m.agent_cohort = w.comparison) OR (m.agent_cohort = 'CONTROL'::text))))
          WHERE (((m.business_date >= w.pre_s) AND (m.business_date <= w.pre_e)) OR ((m.business_date >= w.post_s) AND (m.business_date <= w.post_e)))
          GROUP BY w.comparison,
                CASE
                    WHEN (m.agent_cohort = w.comparison) THEN 'PILOT'::text
                    ELSE 'CONTROL'::text
                END,
                CASE
                    WHEN (m.business_date <= w.pre_e) THEN 'PRE'::text
                    ELSE 'POST'::text
                END
        ), k AS (
         SELECT g.comparison,
            g.grp,
            g.period,
            v.kpi_code,
            v.val
           FROM g,
            LATERAL ( VALUES ('UPLH'::text,(g.units / NULLIF(g.paid_hours, (0)::numeric))), ('IDLE_PCT'::text,(((100)::numeric * g.idle_hours) / NULLIF((g.idle_hours + g.direct_hours), (0)::numeric))), ('BOTTLENECK_MIN'::text,(g.bn_min / (g.dc_days)::numeric)), ('SLA_PCT'::text,((100.0 * g.on_time) / NULLIF(g.due, (0)::numeric))), ('OT_PCT'::text,(((100)::numeric * g.ot_hours) / NULLIF(g.paid_hours, (0)::numeric))), ('FIREFIGHT_PER_DAY'::text,(g.ff / (g.dc_days)::numeric)), ('COST_PER_UNIT'::text,(g.cost / NULLIF(g.units, (0)::numeric))), ('HEADCOUNT'::text,(g.heads / (g.dc_days)::numeric))) v(kpi_code, val)
        ), p AS (
         SELECT k.comparison,
            k.kpi_code,
            max(k.val) FILTER (WHERE ((k.grp = 'PILOT'::text) AND (k.period = 'PRE'::text))) AS pilot_pre,
            max(k.val) FILTER (WHERE ((k.grp = 'PILOT'::text) AND (k.period = 'POST'::text))) AS pilot_post,
            max(k.val) FILTER (WHERE ((k.grp = 'CONTROL'::text) AND (k.period = 'PRE'::text))) AS control_pre,
            max(k.val) FILTER (WHERE ((k.grp = 'CONTROL'::text) AND (k.period = 'POST'::text))) AS control_post
           FROM k
          GROUP BY k.comparison, k.kpi_code
        )
 SELECT p.comparison,
    t.kpi_code,
    t.kpi_name,
    t.unit,
    t.better_direction,
    round(p.pilot_pre, 3) AS pilot_pre,
    round(p.pilot_post, 3) AS pilot_post,
    round(((100)::numeric * ((p.pilot_post / NULLIF(p.pilot_pre, (0)::numeric)) - (1)::numeric)), 1) AS pilot_change_pct,
    round(p.control_pre, 3) AS control_pre,
    round(p.control_post, 3) AS control_post,
    round(((100)::numeric * ((p.control_post / NULLIF(p.control_pre, (0)::numeric)) - (1)::numeric)), 1) AS control_change_pct,
    round(((p.pilot_post - p.pilot_pre) - (p.control_post - p.control_pre)), 3) AS did_abs,
    round(((100)::numeric * (((p.pilot_post / NULLIF(p.pilot_pre, (0)::numeric)) / NULLIF((p.control_post / NULLIF(p.control_pre, (0)::numeric)), (0)::numeric)) - (1)::numeric)), 1) AS did_rel_pct,
    t.target_improvement,
        CASE
            WHEN (((t.better_direction = 'UP'::text) AND ((p.pilot_post - p.pilot_pre) > (p.control_post - p.control_pre))) OR ((t.better_direction = 'DOWN'::text) AND ((p.pilot_post - p.pilot_pre) < (p.control_post - p.control_pre)))) THEN 'IMPROVED vs control'::text
            ELSE 'NOT IMPROVED vs control'::text
        END AS verdict
   FROM (p
     JOIN labor_allocation.poc_kpi_target t USING (kpi_code))
  ORDER BY p.comparison, (array_position(ARRAY['UPLH'::text, 'COST_PER_UNIT'::text, 'IDLE_PCT'::text, 'OT_PCT'::text, 'SLA_PCT'::text, 'BOTTLENECK_MIN'::text, 'FIREFIGHT_PER_DAY'::text, 'HEADCOUNT'::text], t.kpi_code));

CREATE VIEW labor_allocation.vw_exec_weekly_trend AS
SELECT (date_trunc('week'::text, (business_date)::timestamp with time zone))::date AS week_start,
    agent_cohort,
    count(DISTINCT dc_id) AS dcs,
    round((sum(units_shipped) / NULLIF(sum(paid_hours), (0)::numeric)), 2) AS units_per_labor_hour,
    round((((100)::numeric * sum(idle_hours)) / NULLIF((sum(idle_hours) + sum(direct_hours)), (0)::numeric)), 2) AS idle_pct,
    round(((100.0 * sum(units_on_time)) / NULLIF(sum(units_due), (0)::numeric)), 2) AS sla_pct,
    round((((100)::numeric * sum(overtime_hours)) / NULLIF(sum(paid_hours), (0)::numeric)), 2) AS overtime_pct,
    round((sum(bottleneck_minutes) / (count(*))::numeric), 0) AS bottleneck_min_per_dc_day,
    round((sum(firefighting_events) / (count(*))::numeric), 2) AS firefighting_per_dc_day,
    round((sum(labor_cost_usd) / NULLIF(sum(units_shipped), (0)::numeric)), 4) AS labor_cost_per_unit,
    round(sum(units_shipped)) AS units_shipped,
    sum(agent_moves) AS agent_moves
   FROM labor_allocation.mv_dc_daily
  WHERE is_complete_day
  GROUP BY ((date_trunc('week'::text, (business_date)::timestamp with time zone))::date), agent_cohort
  ORDER BY ((date_trunc('week'::text, (business_date)::timestamp with time zone))::date), agent_cohort;

CREATE VIEW labor_allocation.vw_exec_roi AS
WITH s AS (
         SELECT vw_exec_poc_scorecard.comparison,
            vw_exec_poc_scorecard.kpi_code,
            vw_exec_poc_scorecard.kpi_name,
            vw_exec_poc_scorecard.unit,
            vw_exec_poc_scorecard.better_direction,
            vw_exec_poc_scorecard.pilot_pre,
            vw_exec_poc_scorecard.pilot_post,
            vw_exec_poc_scorecard.pilot_change_pct,
            vw_exec_poc_scorecard.control_pre,
            vw_exec_poc_scorecard.control_post,
            vw_exec_poc_scorecard.control_change_pct,
            vw_exec_poc_scorecard.did_abs,
            vw_exec_poc_scorecard.did_rel_pct,
            vw_exec_poc_scorecard.target_improvement,
            vw_exec_poc_scorecard.verdict
           FROM labor_allocation.vw_exec_poc_scorecard
        ), base AS (
         SELECT w.comparison,
            ((sum(m.units_shipped) / (count(DISTINCT m.business_date))::numeric) * (365)::numeric) AS annual_units,
            ((sum(m.units_due) / (count(DISTINCT m.business_date))::numeric) * (365)::numeric) AS annual_units_due,
            (sum(m.sla_miss_cost_usd) / NULLIF(sum(m.units_missed), (0)::numeric)) AS miss_cost_per_unit,
            count(DISTINCT m.dc_id) AS dcs
           FROM (labor_allocation.mv_dc_daily m
             JOIN ( SELECT 'PILOT_WAVE_1'::text AS comparison,
                    (split_part(poc_config.value, '..'::text, 1))::date AS s,
                    (split_part(poc_config.value, '..'::text, 2))::date AS e
                   FROM labor_allocation.poc_config
                  WHERE (poc_config.key = 'did_post_window'::text)
                UNION ALL
                 SELECT 'PILOT_WAVE_2'::text,
                    (split_part(poc_config.value, '..'::text, 1))::date AS split_part,
                    (split_part(poc_config.value, '..'::text, 2))::date AS split_part
                   FROM labor_allocation.poc_config
                  WHERE (poc_config.key = 'did_post_window_wave2'::text)) w ON (((m.agent_cohort = w.comparison) AND ((m.business_date >= w.s) AND (m.business_date <= w.e)))))
          GROUP BY w.comparison
        ), network AS (
         SELECT ((sum(mv_dc_daily.units_shipped) / (count(DISTINCT mv_dc_daily.business_date))::numeric) * (365)::numeric) AS annual_units_network
           FROM labor_allocation.mv_dc_daily
          WHERE ((mv_dc_daily.business_date >= '2026-06-22'::date) AND (mv_dc_daily.business_date <= ( SELECT (poc_config.value)::date AS value
                   FROM labor_allocation.poc_config
                  WHERE (poc_config.key = 'data_window_end'::text))))
        ), lever AS (
         SELECT b.comparison,
            b.dcs,
            ((((c.pilot_pre * c.control_post) / c.control_pre) - c.pilot_post) * b.annual_units) AS labor_savings,
            ((((((100)::numeric - ((s.pilot_pre * s.control_post) / s.control_pre)) - ((100)::numeric - s.pilot_post)) / (100)::numeric) * b.annual_units_due) * b.miss_cost_per_unit) AS sla_value,
            ((((((((f.pilot_pre * f.control_post) / f.control_pre) - f.pilot_post) * (365)::numeric) * (b.dcs)::numeric) * (32)::numeric) / 60.0) * (48)::numeric) AS supervisor_value,
            ((((c.pilot_pre * c.control_post) / c.control_pre) - c.pilot_post) / ((c.pilot_pre * c.control_post) / c.control_pre)) AS cost_per_unit_reduction
           FROM (((base b
             JOIN s c ON (((c.comparison = b.comparison) AND (c.kpi_code = 'COST_PER_UNIT'::text))))
             JOIN s s ON (((s.comparison = b.comparison) AND (s.kpi_code = 'SLA_PCT'::text))))
             JOIN s f ON (((f.comparison = b.comparison) AND (f.kpi_code = 'FIREFIGHT_PER_DAY'::text))))
        )
 SELECT l.comparison,
    v.lever,
    (round(v.annual_usd))::bigint AS annual_value_usd,
    v.basis
   FROM (lever l
     CROSS JOIN network n),
    LATERAL ( VALUES ('Labor productivity (cost per unit vs control trend)'::text,l.labor_savings,'Counterfactual cost/unit = pilot pre x (control post / control pre); x annualized pilot units'::text), ('Service-level misses avoided'::text,l.sla_value,'Counterfactual miss rate vs actual x annualized units due x average miss cost'::text), ('Supervisor time released from firefighting'::text,l.supervisor_value,'Events avoided x 32 min x $48/h, annualized'::text), ('TOTAL - pilot DCs'::text,((l.labor_savings + l.sla_value) + l.supervisor_value),'Sum of levers for the pilot DCs in this wave'::text), ('Network scale-out (all 8 DCs, labor lever only)'::text,((l.cost_per_unit_reduction * n.annual_units_network) * ( SELECT (sum(mv_dc_daily.labor_cost_usd) / sum(mv_dc_daily.units_shipped))
                   FROM labor_allocation.mv_dc_daily
                  WHERE mv_dc_daily.is_complete_day)),'Relative cost/unit reduction applied to annualized network volume at network average cost/unit'::text)) v(lever, annual_usd, basis)
  ORDER BY l.comparison;

CREATE VIEW labor_allocation.vw_agent_forecast_accuracy AS
SELECT d.dc_code,
    f.week_start,
    f.function_code,
    mv.version AS forecaster_version,
    f.actual_workload,
    round(((100.0 * (f.abs_error_dayahead)::numeric) / (NULLIF(f.actual_workload, 0))::numeric), 1) AS wmape_dayahead_pct,
    round(((100.0 * (f.abs_error_intraday)::numeric) / (NULLIF(f.actual_workload, 0))::numeric), 1) AS wmape_intraday_pct,
    round(((100.0 * (f.bias_dayahead)::numeric) / (NULLIF(f.actual_workload, 0))::numeric), 1) AS bias_dayahead_pct
   FROM ((labor_allocation.mv_forecast_accuracy f
     JOIN labor_allocation.dc d USING (dc_id))
     LEFT JOIN labor_allocation.agent_model_version mv ON (((mv.component = 'WORKLOAD_FORECASTER'::text) AND (((f.week_start + 3) >= mv.deployed_on) AND ((f.week_start + 3) <= COALESCE(mv.retired_on, '9999-12-31'::date))))))
  ORDER BY d.dc_code, f.week_start, f.function_code;

CREATE VIEW labor_allocation.vw_agent_alert_performance AS
WITH al AS (
         SELECT a.dc_id,
            (date_trunc('week'::text, a.detected_at))::date AS week_start,
            a.agent_mode,
            count(*) AS alerts,
            count(*) FILTER (WHERE (a.status = ANY (ARRAY['BREACHED'::text, 'MITIGATED'::text]))) AS true_positive,
            count(*) FILTER (WHERE (a.status = 'FALSE_POSITIVE'::text)) AS false_positive,
            count(*) FILTER (WHERE (a.status = 'MITIGATED'::text)) AS mitigated
           FROM labor_allocation.agent_bottleneck_alert a
          GROUP BY a.dc_id, ((date_trunc('week'::text, a.detected_at))::date), a.agent_mode
        ), ep AS (
         SELECT e.dc_id,
            (date_trunc('week'::text, e.started_at))::date AS week_start,
            count(*) AS episodes,
            count(e.first_alert_id) AS episodes_predicted,
            percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((e.alert_lead_min)::double precision)) AS median_lead_min
           FROM labor_allocation.ops_bottleneck_episode e
          WHERE (e.agent_mode <> 'BASELINE'::text)
          GROUP BY e.dc_id, ((date_trunc('week'::text, e.started_at))::date)
        )
 SELECT d.dc_code,
    al.week_start,
    al.agent_mode,
    al.alerts,
    al.true_positive,
    al.false_positive,
    al.mitigated,
    round(((100.0 * (al.true_positive)::numeric) / (NULLIF((al.true_positive + al.false_positive), 0))::numeric), 1) AS precision_pct,
    ep.episodes,
    ep.episodes_predicted,
    round(((100.0 * (ep.episodes_predicted)::numeric) / (NULLIF(ep.episodes, 0))::numeric), 1) AS episode_recall_pct,
    ep.median_lead_min
   FROM ((al
     JOIN labor_allocation.dc d USING (dc_id))
     LEFT JOIN ep USING (dc_id, week_start))
  ORDER BY d.dc_code, al.week_start;

CREATE VIEW labor_allocation.vw_agent_recommendation_funnel AS
SELECT d.dc_code,
    (date_trunc('month'::text, r.created_at))::date AS month,
    r.agent_mode,
    r.rec_type,
    count(*) AS generated,
    count(*) FILTER (WHERE (r.status = 'SHADOW_LOGGED'::text)) AS shadow_logged,
    count(*) FILTER (WHERE (r.status = 'ACCEPTED'::text)) AS accepted,
    count(*) FILTER (WHERE (r.status = 'AUTO_EXECUTED'::text)) AS auto_executed,
    count(*) FILTER (WHERE (r.status = 'REJECTED'::text)) AS rejected,
    count(*) FILTER (WHERE (r.status = 'EXPIRED'::text)) AS expired,
    count(*) FILTER (WHERE (r.status = 'PENDING'::text)) AS pending,
    round(((100.0 * (count(*) FILTER (WHERE (r.status = ANY (ARRAY['ACCEPTED'::text, 'AUTO_EXECUTED'::text]))))::numeric) / (NULLIF(count(*) FILTER (WHERE (r.status = ANY (ARRAY['ACCEPTED'::text, 'AUTO_EXECUTED'::text, 'REJECTED'::text, 'EXPIRED'::text]))), 0))::numeric), 1) AS acceptance_pct,
    count(o.rec_id) AS evaluated,
    round(((100.0 * (count(*) FILTER (WHERE (o.outcome_label = ANY (ARRAY['EFFECTIVE'::text, 'PARTIALLY_EFFECTIVE'::text]))))::numeric) / (NULLIF(count(o.rec_id), 0))::numeric), 1) AS effective_pct,
    round((sum(o.realized_benefit_usd))::numeric, 0) AS realized_benefit_usd,
    round((avg(r.confidence))::numeric, 3) AS avg_confidence
   FROM ((labor_allocation.agent_recommendation r
     JOIN labor_allocation.dc d USING (dc_id))
     LEFT JOIN labor_allocation.agent_outcome o USING (rec_id))
  GROUP BY d.dc_code, ((date_trunc('month'::text, r.created_at))::date), r.agent_mode, r.rec_type
  ORDER BY d.dc_code, ((date_trunc('month'::text, r.created_at))::date), r.agent_mode, r.rec_type;

CREATE VIEW labor_allocation.vw_agent_rejection_reasons AS
SELECT d.dc_code,
    r.agent_mode,
    r.rejection_reason,
    count(*) AS rejections,
    round(((100.0 * (count(*))::numeric) / sum(count(*)) OVER (PARTITION BY d.dc_code, r.agent_mode)), 1) AS share_pct
   FROM (labor_allocation.agent_recommendation r
     JOIN labor_allocation.dc d USING (dc_id))
  WHERE (r.status = 'REJECTED'::text)
  GROUP BY d.dc_code, r.agent_mode, r.rejection_reason
  ORDER BY d.dc_code, r.agent_mode, (count(*)) DESC;

CREATE VIEW labor_allocation.vw_agent_learning_curve AS
SELECT mv.component,
    mv.version,
    (t.run_at)::date AS run_date,
    t.promoted,
    ((t.metrics ->> 'wmape_hourly_zone'::text))::numeric AS wmape_hourly_zone_pct,
    ((t.metrics ->> 'precision'::text))::numeric AS alert_precision,
    ((t.metrics ->> 'episode_recall'::text))::numeric AS episode_recall,
    ((t.metrics ->> 'median_lead_min'::text))::numeric AS median_lead_min,
    ((t.metrics ->> 'acceptance_rate'::text))::numeric AS acceptance_rate,
    ((t.metrics ->> 'effective_rate'::text))::numeric AS effective_rate,
    ((t.metrics ->> 'mean_reward'::text))::numeric AS mean_reward,
    t.training_rows,
    t.notes
   FROM (labor_allocation.agent_training_run t
     JOIN labor_allocation.agent_model_version mv USING (model_version_id))
  ORDER BY mv.component, t.run_at;

CREATE VIEW labor_allocation.vw_exec_agent_kpis AS
WITH fa AS (
         SELECT min(mv_forecast_accuracy.week_start) AS first_week,
            max(mv_forecast_accuracy.week_start) AS last_week
           FROM labor_allocation.mv_forecast_accuracy
        ), fc AS (
         SELECT round(((100.0 * sum(mv_forecast_accuracy.abs_error_dayahead) FILTER (WHERE (mv_forecast_accuracy.week_start < (fa.first_week + 28)))) / NULLIF(sum(mv_forecast_accuracy.actual_workload) FILTER (WHERE (mv_forecast_accuracy.week_start < (fa.first_week + 28))), (0)::numeric)), 1) AS first_4w,
            round(((100.0 * sum(mv_forecast_accuracy.abs_error_dayahead) FILTER (WHERE (mv_forecast_accuracy.week_start > (fa.last_week - 28)))) / NULLIF(sum(mv_forecast_accuracy.actual_workload) FILTER (WHERE (mv_forecast_accuracy.week_start > (fa.last_week - 28))), (0)::numeric)), 1) AS last_4w
           FROM labor_allocation.mv_forecast_accuracy,
            fa
        ), alerts AS (
         SELECT round(((100.0 * (count(*) FILTER (WHERE (agent_bottleneck_alert.status = ANY (ARRAY['BREACHED'::text, 'MITIGATED'::text]))))::numeric) / (NULLIF(count(*) FILTER (WHERE (agent_bottleneck_alert.status <> 'OPEN'::text)), 0))::numeric), 1) AS precision_pct
           FROM labor_allocation.agent_bottleneck_alert
          WHERE (agent_bottleneck_alert.agent_mode = ANY (ARRAY['ASSISTED'::text, 'AUTO'::text]))
        ), lead AS (
         SELECT percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((ops_bottleneck_episode.alert_lead_min)::double precision)) AS median_lead,
            round(((100.0 * (count(ops_bottleneck_episode.first_alert_id))::numeric) / (count(*))::numeric), 1) AS recall_pct
           FROM labor_allocation.ops_bottleneck_episode
          WHERE (ops_bottleneck_episode.agent_mode = ANY (ARRAY['ASSISTED'::text, 'AUTO'::text]))
        ), recs AS (
         SELECT round(((100.0 * (count(*) FILTER (WHERE (agent_recommendation.status = ANY (ARRAY['ACCEPTED'::text, 'AUTO_EXECUTED'::text]))))::numeric) / (NULLIF(count(*) FILTER (WHERE (agent_recommendation.status = ANY (ARRAY['ACCEPTED'::text, 'AUTO_EXECUTED'::text, 'REJECTED'::text, 'EXPIRED'::text]))), 0))::numeric), 1) AS accept_pct
           FROM labor_allocation.agent_recommendation
          WHERE ((agent_recommendation.rec_type = 'REALLOCATE'::text) AND (agent_recommendation.agent_mode = ANY (ARRAY['ASSISTED'::text, 'AUTO'::text])))
        ), eff AS (
         SELECT round(((100.0 * (count(*) FILTER (WHERE (agent_outcome.outcome_label = ANY (ARRAY['EFFECTIVE'::text, 'PARTIALLY_EFFECTIVE'::text]))))::numeric) / (NULLIF(count(*), 0))::numeric), 1) AS eff_pct,
            round((sum(agent_outcome.realized_benefit_usd))::double precision) AS benefit
           FROM labor_allocation.agent_outcome
        ), xt AS (
         SELECT count(DISTINCT associate_skill.associate_id) AS cross_trained
           FROM labor_allocation.associate_skill
          WHERE (associate_skill.source = 'AGENT_CROSS_TRAIN'::text)
        )
 SELECT kpi_code,
    kpi_name,
    value
   FROM ( VALUES ('FCST_WMAPE_FIRST_4W'::text,'Hourly zone forecast wMAPE - first 4 weeks live (%)'::text,( SELECT fc.first_4w
                   FROM fc)), ('FCST_WMAPE_LAST_4W'::text,'Hourly zone forecast wMAPE - last 4 weeks (%)'::text,( SELECT fc.last_4w
                   FROM fc)), ('ALERT_PRECISION'::text,'Bottleneck alert precision, assisted/auto (%)'::text,( SELECT alerts.precision_pct
                   FROM alerts)), ('ALERT_RECALL'::text,'Bottleneck episodes flagged in advance (%)'::text,( SELECT lead.recall_pct
                   FROM lead)), ('ALERT_LEAD'::text,'Median alert lead time before breach (min)'::text,( SELECT (lead.median_lead)::numeric AS median_lead
                   FROM lead)), ('REC_ACCEPT'::text,'Reallocation recommendations accepted or auto-run (%)'::text,( SELECT recs.accept_pct
                   FROM recs)), ('REC_EFFECTIVE'::text,'Executed recommendations rated effective (%)'::text,( SELECT eff.eff_pct
                   FROM eff)), ('REALIZED_BENEFIT'::text,'Measured benefit of executed recommendations (USD)'::text,( SELECT eff.benefit
                   FROM eff)), ('CROSS_TRAINED'::text,'Associates certified in a new skill via agent cross-training recs'::text,( SELECT (xt.cross_trained)::numeric AS cross_trained
                   FROM xt))) t(kpi_code, kpi_name, value);

CREATE VIEW labor_allocation.vw_skill_coverage AS
WITH asof AS (
         SELECT (poc_config.value)::date AS d
           FROM labor_allocation.poc_config
          WHERE (poc_config.key = 'live_day'::text)
        ), req AS (
         SELECT zone_skill_requirement.zone_id,
            zone_skill_requirement.skill_code,
            zone_skill_requirement.min_proficiency
           FROM labor_allocation.zone_skill_requirement
          WHERE zone_skill_requirement.is_mandatory
        ), act AS (
         SELECT a.associate_id,
            a.kronos_person_num,
            a.badge_id,
            a.first_name,
            a.last_name,
            a.dc_id,
            a.home_zone_id,
            a.shift_code,
            a.work_pattern,
            a.employment_type,
            a.staffing_agency,
            a.job_title,
            a.hourly_rate,
            a.hire_date,
            a.termination_date,
            a.termination_reason,
            a.status,
            a.is_lead,
            a.is_flex_pool,
            a.restrictions,
            a.base_performance
           FROM labor_allocation.associate a,
            asof
          WHERE ((a.hire_date <= asof.d) AND ((a.termination_date IS NULL) OR (a.termination_date >= asof.d)))
        ), qual AS (
         SELECT a.associate_id,
            a.home_zone_id,
            a.employment_type,
            z_1.zone_id
           FROM (act a
             JOIN labor_allocation.dc_zone z_1 ON ((z_1.dc_id = a.dc_id))),
            asof
          WHERE ((NOT (EXISTS ( SELECT 1
                   FROM req r
                  WHERE ((r.zone_id = z_1.zone_id) AND (NOT (EXISTS ( SELECT 1
                           FROM labor_allocation.associate_skill s
                          WHERE ((s.associate_id = a.associate_id) AND (s.skill_code = r.skill_code) AND (s.proficiency >= r.min_proficiency) AND (s.certified_on <= asof.d) AND ((s.expires_on IS NULL) OR (s.expires_on >= asof.d)))))))))) AND (NOT ((a.employment_type = 'TEMP'::text) AND z_1.requires_pit AND (z_1.primary_skill_code = ANY (ARRAY['PIT_REACH'::text, 'PIT_ORDER_PICKER'::text, 'PIT_FORKLIFT'::text])))))
        )
 SELECT d.dc_code,
    z.zone_code,
    z.zone_name,
    z.function_code,
    count(*) FILTER (WHERE (q.home_zone_id = z.zone_id)) AS home_associates,
    count(*) FILTER (WHERE (q.home_zone_id <> z.zone_id)) AS qualified_flex_bench,
    round(((count(*) FILTER (WHERE (q.home_zone_id <> z.zone_id)))::numeric / (NULLIF(count(*) FILTER (WHERE (q.home_zone_id = z.zone_id)), 0))::numeric), 2) AS bench_ratio,
    ( SELECT count(DISTINCT s.associate_id) AS count
           FROM (labor_allocation.associate_skill s
             JOIN act a2 USING (associate_id))
          WHERE ((a2.dc_id = z.dc_id) AND (s.skill_code = z.primary_skill_code) AND (s.source = 'AGENT_CROSS_TRAIN'::text))) AS agent_cross_trained
   FROM ((labor_allocation.dc_zone z
     JOIN labor_allocation.dc d ON ((d.dc_id = z.dc_id)))
     LEFT JOIN qual q ON ((q.zone_id = z.zone_id)))
  GROUP BY d.dc_code, z.zone_id, z.zone_code, z.zone_name, z.function_code, z.dc_id, z.primary_skill_code
  ORDER BY d.dc_code, z.zone_id;

CREATE VIEW labor_allocation.vw_supervisor_adoption AS
SELECT d.dc_code,
    s.full_name,
    s.title,
    s.shift_code,
    s.area,
    (date_trunc('month'::text, r.decided_at))::date AS month,
    count(*) AS decisions,
    count(*) FILTER (WHERE (r.status = 'ACCEPTED'::text)) AS accepted,
    round(((100.0 * (count(*) FILTER (WHERE (r.status = 'ACCEPTED'::text)))::numeric) / (count(*))::numeric), 1) AS acceptance_pct,
    round(avg((EXTRACT(epoch FROM (r.decided_at - r.created_at)) / (60)::numeric)), 1) AS avg_response_min
   FROM ((labor_allocation.agent_recommendation r
     JOIN labor_allocation.ops_supervisor s ON ((s.supervisor_id = r.decided_by_supervisor_id)))
     JOIN labor_allocation.dc d ON ((d.dc_id = r.dc_id)))
  WHERE ((r.rec_type = 'REALLOCATE'::text) AND (r.status = ANY (ARRAY['ACCEPTED'::text, 'REJECTED'::text, 'EXPIRED'::text])))
  GROUP BY d.dc_code, s.full_name, s.title, s.shift_code, s.area, ((date_trunc('month'::text, r.decided_at))::date)
  ORDER BY d.dc_code, s.full_name, ((date_trunc('month'::text, r.decided_at))::date);

CREATE VIEW labor_allocation.vw_labor_moves_weekly AS
SELECT d.dc_code,
    (date_trunc('week'::text, (m.business_date)::timestamp with time zone))::date AS week_start,
    m.move_source,
    count(*) AS moves,
    count(DISTINCT m.associate_id) AS associates_moved,
    round((avg(m.travel_min))::numeric, 1) AS avg_walk_min,
    round(((100.0 * (count(*) FILTER (WHERE (m.target_skill_proficiency IS NOT NULL)))::numeric) / (count(*))::numeric), 1) AS skill_matched_pct,
    round(avg((EXTRACT(epoch FROM (m.ended_at - m.started_at)) / (60)::numeric)), 0) AS avg_duration_min,
    round((sum(m.est_workload_done))::numeric) AS est_workload_done
   FROM (labor_allocation.ops_labor_move m
     JOIN labor_allocation.dc d USING (dc_id))
  GROUP BY d.dc_code, ((date_trunc('week'::text, (m.business_date)::timestamp with time zone))::date), m.move_source
  ORDER BY d.dc_code, ((date_trunc('week'::text, (m.business_date)::timestamp with time zone))::date), m.move_source;

CREATE VIEW labor_allocation.vw_cutoff_sla_daily AS
SELECT d.dc_code,
    p.business_date,
    c.carrier,
    c.service_level,
    c.pull_time,
    c.flow_chain,
    p.units_due,
    p.units_on_time,
    p.units_missed,
    round(((100.0 * (p.units_on_time)::numeric) / (NULLIF(p.units_due, 0))::numeric), 2) AS sla_pct,
    p.backlog_at_pull,
    p.miss_cost_usd
   FROM ((labor_allocation.ops_cutoff_performance p
     JOIN labor_allocation.carrier_cutoff c USING (cutoff_id))
     JOIN labor_allocation.dc d ON ((d.dc_id = p.dc_id)))
  ORDER BY d.dc_code, p.business_date, c.pull_time;

CREATE VIEW labor_allocation.vw_live_zone_status AS
WITH cfg AS (
         SELECT (poc_config.value)::date AS live_day
           FROM labor_allocation.poc_config
          WHERE (poc_config.key = 'live_day'::text)
        ), last AS (
         SELECT DISTINCT ON (i.zone_id) i.zone_id,
            i.interval_start,
            i.dc_id,
            i.business_date,
            i.local_slot,
            i.workload_in,
            i.workload_done,
            i.queue_depth,
            i.oldest_task_age_min,
            i.avg_task_age_min,
            i.hc_planned,
            i.hc_actual,
            i.direct_hours,
            i.idle_hours,
            i.fcst_dayahead,
            i.fcst_intraday,
            i.is_bottleneck
           FROM labor_allocation.wms_zone_interval i,
            cfg cfg_1
          WHERE (i.business_date = cfg_1.live_day)
          ORDER BY i.zone_id, i.interval_start DESC
        )
 SELECT d.dc_code,
    z.zone_code,
    z.zone_name,
    z.function_code,
    (l.interval_start + '00:15:00'::interval) AS as_of_utc,
    to_char(((l.interval_start + '00:15:00'::interval) AT TIME ZONE d.timezone), 'HH24:MI'::text) AS as_of_local,
    l.queue_depth,
    z.uom,
    l.oldest_task_age_min,
    z.aging_sla_min,
        CASE
            WHEN ((l.oldest_task_age_min > z.aging_sla_min) AND (NOT z.is_deferrable)) THEN 'BOTTLENECK'::text
            WHEN (((l.oldest_task_age_min)::numeric > (0.7 * (z.aging_sla_min)::numeric)) AND (NOT z.is_deferrable)) THEN 'AT_RISK'::text
            ELSE 'OK'::text
        END AS status,
    l.hc_actual,
    l.hc_planned,
    l.workload_in AS last_15m_in,
    l.workload_done AS last_15m_done,
    ( SELECT count(*) AS count
           FROM labor_allocation.agent_bottleneck_alert a
          WHERE ((a.zone_id = z.zone_id) AND (a.status = 'OPEN'::text))) AS open_alerts,
    ( SELECT count(*) AS count
           FROM labor_allocation.agent_recommendation r
          WHERE ((r.to_zone_id = z.zone_id) AND (r.status = 'PENDING'::text))) AS pending_recommendations,
    z.zone_id,
    d.dc_id,
    z.min_headcount,
    z.max_headcount,
    z.standard_uph,
    z.is_deferrable,
    ( SELECT r.phase
           FROM labor_allocation.agent_rollout r,
            cfg cfg_1
          WHERE ((r.dc_id = d.dc_id) AND ((cfg_1.live_day >= r.start_date) AND (cfg_1.live_day <= COALESCE(r.end_date, '9999-12-31'::date))))
         LIMIT 1) AS agent_mode
   FROM ((last l
     JOIN labor_allocation.dc_zone z USING (zone_id))
     JOIN labor_allocation.dc d ON ((d.dc_id = z.dc_id))),
    cfg
  ORDER BY d.dc_code, z.zone_id;

CREATE VIEW labor_allocation.vw_live_pending_recommendations AS
SELECT d.dc_code,
    r.rec_id,
    r.created_at,
    r.priority,
    r.rec_type,
    fz.zone_code AS from_zone,
    tz.zone_code AS to_zone,
    r.headcount,
    r.skill_code,
    r.window_start,
    r.window_end,
    r.expected_workload_gain,
    r.expected_sla_units_protected,
    r.expected_benefit_usd,
    r.confidence,
    r.soft_constraints_flagged,
    r.rationale,
    ( SELECT string_agg(((a.first_name || ' '::text) || a.last_name), ', '::text ORDER BY a.associate_id) AS string_agg
           FROM ( SELECT DISTINCT a2.associate_id,
                    a2.first_name,
                    a2.last_name
                   FROM ((labor_allocation.wfm_timecard t
                     JOIN labor_allocation.associate a2 USING (associate_id))
                     JOIN labor_allocation.associate_skill s ON (((s.associate_id = a2.associate_id) AND (s.skill_code = r.skill_code) AND (s.proficiency >= 2))))
                  WHERE ((t.home_zone_id = r.from_zone_id) AND (t.clock_in IS NOT NULL) AND (t.clock_out IS NULL))
                  ORDER BY a2.associate_id
                 LIMIT 8) a) AS eligible_associates_on_floor
   FROM (((labor_allocation.agent_recommendation r
     JOIN labor_allocation.dc d USING (dc_id))
     LEFT JOIN labor_allocation.dc_zone fz ON ((fz.zone_id = r.from_zone_id)))
     LEFT JOIN labor_allocation.dc_zone tz ON ((tz.zone_id = r.to_zone_id)))
  WHERE (r.status = 'PENDING'::text)
  ORDER BY r.priority, r.created_at;

CREATE VIEW labor_allocation.vw_live_playbook AS
SELECT d.dc_code,
    p.business_date,
    p.status,
    p.generated_at,
    p.fcst_volume,
    p.fcst_volume_p10,
    p.fcst_volume_p90,
    z.zone_code,
    z.zone_name,
    l.local_hour,
    l.fcst_workload,
    l.required_hours,
    l.recommended_hc,
    l.static_plan_hc,
    (l.recommended_hc - l.static_plan_hc) AS delta_vs_static,
    l.flex_in,
    l.flex_out,
    p.narrative
   FROM (((labor_allocation.agent_playbook p
     JOIN labor_allocation.agent_playbook_line l USING (playbook_id))
     JOIN labor_allocation.dc d ON ((d.dc_id = p.dc_id)))
     JOIN labor_allocation.dc_zone z ON ((z.zone_id = l.zone_id)))
  WHERE (p.business_date >= ( SELECT (poc_config.value)::date AS value
           FROM labor_allocation.poc_config
          WHERE (poc_config.key = 'live_day'::text)))
  ORDER BY d.dc_code, p.business_date, z.zone_id, ((l.local_hour + 18) % 24);

CREATE VIEW labor_allocation.vw_live_on_the_clock AS
SELECT d.dc_code,
    z.zone_code AS home_zone,
    a.associate_id,
    a.first_name,
    a.last_name,
    a.employment_type,
    a.job_title,
    t.shift_code,
    t.clock_in,
    a.is_flex_pool,
    ( SELECT string_agg(((s.skill_code || ':L'::text) || s.proficiency), ', '::text ORDER BY s.proficiency DESC) AS string_agg
           FROM labor_allocation.associate_skill s
          WHERE (s.associate_id = a.associate_id)) AS skills
   FROM (((labor_allocation.wfm_timecard t
     JOIN labor_allocation.associate a USING (associate_id))
     JOIN labor_allocation.dc d ON ((d.dc_id = t.dc_id)))
     JOIN labor_allocation.dc_zone z ON ((z.zone_id = t.home_zone_id)))
  WHERE ((t.clock_in IS NOT NULL) AND (t.clock_out IS NULL))
  ORDER BY d.dc_code, z.zone_id, a.last_name;

CREATE VIEW labor_allocation.vw_live_move_candidates AS
WITH cfg AS (
         SELECT (poc_config.value)::date AS live_day
           FROM labor_allocation.poc_config
          WHERE (poc_config.key = 'live_day'::text)
        ), onclock AS (
         SELECT t.associate_id,
            t.dc_id,
            t.home_zone_id,
            t.shift_code
           FROM labor_allocation.wfm_timecard t,
            cfg cfg_1
          WHERE ((t.business_date = cfg_1.live_day) AND (t.clock_in IS NOT NULL) AND (t.clock_out IS NULL))
        ), req AS (
         SELECT zone_skill_requirement.zone_id,
            zone_skill_requirement.skill_code,
            zone_skill_requirement.min_proficiency
           FROM labor_allocation.zone_skill_requirement
          WHERE zone_skill_requirement.is_mandatory
        ), heavy AS (
         SELECT DISTINCT req.zone_id
           FROM req
          WHERE (req.skill_code = ANY (ARRAY['PIT_REACH'::text, 'PIT_ORDER_PICKER'::text, 'PIT_FORKLIFT'::text]))
        ), moves AS (
         SELECT m_1.associate_id,
            count(*) AS moves_today
           FROM labor_allocation.ops_labor_move m_1,
            cfg cfg_1
          WHERE (m_1.business_date = cfg_1.live_day)
          GROUP BY m_1.associate_id
        )
 SELECT d.dc_code,
    o.associate_id,
    ((a.first_name || ' '::text) || a.last_name) AS associate_name,
    a.employment_type,
    a.job_title,
    o.shift_code,
    o.home_zone_id,
    hz.zone_code AS home_zone,
    tz.zone_id AS target_zone_id,
    tz.zone_code AS target_zone,
    tz.zone_name AS target_zone_name,
    tz.primary_skill_code AS target_skill,
    ps.proficiency AS target_skill_proficiency,
    tt.walk_minutes,
    a.base_performance,
    COALESCE(m.moves_today, (0)::bigint) AS moves_today
   FROM ((((((((onclock o
     CROSS JOIN cfg)
     JOIN labor_allocation.associate a USING (associate_id))
     JOIN labor_allocation.dc d ON ((d.dc_id = o.dc_id)))
     JOIN labor_allocation.dc_zone hz ON ((hz.zone_id = o.home_zone_id)))
     JOIN labor_allocation.dc_zone tz ON (((tz.dc_id = o.dc_id) AND (tz.zone_id <> o.home_zone_id))))
     JOIN labor_allocation.associate_skill ps ON (((ps.associate_id = o.associate_id) AND (ps.skill_code = tz.primary_skill_code))))
     LEFT JOIN labor_allocation.zone_travel_time tt ON (((tt.from_zone_id = o.home_zone_id) AND (tt.to_zone_id = tz.zone_id))))
     LEFT JOIN moves m ON ((m.associate_id = o.associate_id)))
  WHERE ((NOT (EXISTS ( SELECT 1
           FROM req r
          WHERE ((r.zone_id = tz.zone_id) AND (NOT (EXISTS ( SELECT 1
                   FROM labor_allocation.associate_skill s
                  WHERE ((s.associate_id = o.associate_id) AND (s.skill_code = r.skill_code) AND (s.proficiency >= r.min_proficiency) AND (s.certified_on <= cfg.live_day) AND ((s.expires_on IS NULL) OR (s.expires_on >= cfg.live_day)))))))))) AND (NOT ((tz.zone_id IN ( SELECT heavy.zone_id
           FROM heavy)) AND ((a.employment_type = 'TEMP'::text) OR ('NO_PIT'::text = ANY (COALESCE(a.restrictions, '{}'::text[])))))) AND (NOT (('LIFT_25LB'::text = ANY (COALESCE(a.restrictions, '{}'::text[]))) AND (split_part(tz.zone_code, '-'::text, 1) = ANY (ARRAY['RCV'::text, 'SHP'::text, 'BLD'::text])))) AND (COALESCE(m.moves_today, (0)::bigint) < 2));

CREATE VIEW labor_allocation.vw_live_move_options AS
SELECT c.dc_code,
    c.target_zone,
    c.target_zone_name,
    t.status AS target_status,
    t.queue_depth AS target_queue,
    t.oldest_task_age_min AS target_oldest_task_min,
    t.aging_sla_min AS target_sla_min,
    c.associate_id,
    c.associate_name,
    c.employment_type,
    c.home_zone,
    c.target_skill,
    c.target_skill_proficiency,
    c.walk_minutes,
    c.base_performance,
    c.moves_today,
    z.queue_depth AS home_zone_queue,
    z.hc_actual AS home_zone_heads,
    z.min_headcount AS home_zone_min_heads,
    z.is_deferrable AS home_zone_deferrable
   FROM ((labor_allocation.vw_live_move_candidates c
     JOIN labor_allocation.vw_live_zone_status z ON ((z.zone_id = c.home_zone_id)))
     JOIN labor_allocation.vw_live_zone_status t ON ((t.zone_id = c.target_zone_id)))
  WHERE ((z.status = 'OK'::text) AND ((z.hc_actual - (1)::double precision) >= (z.min_headcount)::double precision))
  ORDER BY c.dc_code, c.target_zone, z.is_deferrable DESC, c.target_skill_proficiency DESC, c.walk_minutes;

CREATE VIEW labor_allocation.vw_exec_peak_imbalance AS
SELECT agent_cohort,
    operating_model,
    function_code,
    round((sum((bottleneck_pct * (intervals)::numeric)) / (sum(intervals))::numeric), 1) AS bottleneck_pct_10_to_14,
    round((sum((idle_pct * (intervals)::numeric)) FILTER (WHERE (idle_pct IS NOT NULL)) / (NULLIF(sum(intervals) FILTER (WHERE (idle_pct IS NOT NULL)), 0))::numeric), 1) AS idle_pct_10_to_14
   FROM labor_allocation.mv_bottleneck_heatmap h
  WHERE ((local_hour >= 10) AND (local_hour <= 13))
  GROUP BY agent_cohort, operating_model, function_code
  ORDER BY agent_cohort, operating_model, (round((sum((bottleneck_pct * (intervals)::numeric)) / (sum(intervals))::numeric), 1)) DESC;

CREATE VIEW labor_allocation.vw_exec_example_recommendations AS
SELECT r.rec_id,
    d.dc_code,
    r.created_at,
    r.agent_mode,
    r.status,
    fz.zone_code AS from_zone,
    tz.zone_code AS to_zone,
    r.headcount,
    r.rationale,
    s.full_name AS approved_by,
    o.outcome_label,
    o.actual_workload_gain,
    o.actual_sla_units_protected,
    o.realized_benefit_usd,
    ( SELECT string_agg((((((a.first_name || ' '::text) || a.last_name) || ' (L'::text) || m.target_skill_proficiency) || ')'::text), ', '::text) AS string_agg
           FROM (labor_allocation.ops_labor_move m
             JOIN labor_allocation.associate a USING (associate_id))
          WHERE (m.rec_id = r.rec_id)) AS associates_moved
   FROM (((((labor_allocation.agent_recommendation r
     JOIN labor_allocation.dc d USING (dc_id))
     JOIN labor_allocation.agent_outcome o USING (rec_id))
     LEFT JOIN labor_allocation.dc_zone fz ON ((fz.zone_id = r.from_zone_id)))
     LEFT JOIN labor_allocation.dc_zone tz ON ((tz.zone_id = r.to_zone_id)))
     LEFT JOIN labor_allocation.ops_supervisor s ON ((s.supervisor_id = r.decided_by_supervisor_id)))
  WHERE ((r.rec_type = 'REALLOCATE'::text) AND (o.outcome_label = 'EFFECTIVE'::text))
  ORDER BY o.realized_benefit_usd DESC
 LIMIT 10;

CREATE VIEW labor_allocation.vw_live_playbook_summary AS
SELECT d.dc_code,
    p.business_date,
    p.status,
    p.agent_mode,
    p.fcst_volume,
    p.fcst_volume_p10,
    p.fcst_volume_p90,
    d.volume_uom,
    p.static_plan_hours,
    p.recommended_hours,
    p.recommended_vet_hours,
    p.recommended_vto_hours,
    p.risk_windows,
    p.narrative
   FROM (labor_allocation.agent_playbook p
     JOIN labor_allocation.dc d USING (dc_id))
  WHERE (p.business_date >= ( SELECT (poc_config.value)::date AS value
           FROM labor_allocation.poc_config
          WHERE (poc_config.key = 'live_day'::text)))
  ORDER BY d.dc_code, p.business_date;


-- Indexes on materialized views (3)

CREATE UNIQUE INDEX mv_zone_daily_zone_id_business_date_idx ON labor_allocation.mv_zone_daily USING btree (zone_id, business_date);

CREATE INDEX mv_zone_daily_dc_id_business_date_idx ON labor_allocation.mv_zone_daily USING btree (dc_id, business_date);

CREATE UNIQUE INDEX mv_dc_daily_dc_id_business_date_idx ON labor_allocation.mv_dc_daily USING btree (dc_id, business_date);


-- Comments (73)

COMMENT ON COLUMN labor_allocation.associate.base_performance IS 'Long-run LMS percent-to-standard in the home skill (1.00 = 100%).';

COMMENT ON COLUMN labor_allocation.associate.restrictions IS 'Medical / policy restrictions, e.g. LIFT_25LB, NO_PIT.';

COMMENT ON COLUMN labor_allocation.dc.design_daily_volume IS 'Baseline daily outbound volume the roster was sized for (units for ECOM/OMNI, cases for RETAIL).';

COMMENT ON COLUMN labor_allocation.dc_zone.aging_sla_min IS 'Task age (minutes) above which work in this zone is considered bottlenecked.';

COMMENT ON COLUMN labor_allocation.dc_zone.flow_chain IS 'Outbound chain subject to carrier cutoffs: PARCEL or STORE.';

COMMENT ON COLUMN labor_allocation.dc_zone.is_deferrable IS 'Work that can safely wait (ICQA, returns): the agent treats these zones as a flex-labor source.';

COMMENT ON COLUMN labor_allocation.dc_zone.units_per_uom IS 'Outbound units (eaches, or cases for store flow) represented by one unit of the zone UOM - e.g. a parcel package = 1.59 units. Used to convert SHIP throughput to units shipped.';

COMMENT ON COLUMN labor_allocation.dc_zone.work_source IS 'Exogenous work feed for head-of-flow zones (ORDERS, STORE_WAVES, INBOUND, REPLEN, RETURNS, ICQA). NULL = fed by upstream zones via zone_flow.';

COMMENT ON COLUMN labor_allocation.ops_supervisor.agent_adoption_score IS 'Share of agent recommendations this supervisor accepted (pilot DCs only).';

COMMENT ON COLUMN labor_allocation.wms_zone_interval.fcst_dayahead IS 'Agent day-ahead P50 workload forecast (pilot DCs from shadow start).';

COMMENT ON COLUMN labor_allocation.wms_zone_interval.fcst_intraday IS 'Agent rolling 90-minute nowcast (pilot DCs from shadow start).';

COMMENT ON COLUMN labor_allocation.wms_zone_interval.hc_actual IS 'Associates clocked in and assigned to the zone (excludes unpaid meal).';

COMMENT ON COLUMN labor_allocation.wms_zone_interval.hc_planned IS 'Static plan heads (baseline/control) or agent playbook heads (assisted/auto) for the interval.';

COMMENT ON COLUMN labor_allocation.wms_zone_interval.is_bottleneck IS 'oldest_task_age_min exceeded dc_zone.aging_sla_min.';

COMMENT ON COLUMN labor_allocation.wms_zone_interval.local_slot IS '15-minute slot of the local clock day (0 = 00:00-00:15, 24 = 06:00, 95 = 23:45).';

COMMENT ON COLUMN labor_allocation.wms_zone_interval.queue_depth IS 'Released-but-unworked workload at interval end.';

COMMENT ON MATERIALIZED VIEW labor_allocation.mv_bottleneck_heatmap IS 'Share of 15-minute intervals bottlenecked by function x local hour, static plan vs agent-live, per cohort.';

COMMENT ON MATERIALIZED VIEW labor_allocation.mv_dc_daily IS 'One row per DC per operating day: Kronos hours/cost, LMS direct/idle, WMS throughput and bottlenecks, SLA, firefighting and agent activity.';

COMMENT ON MATERIALIZED VIEW labor_allocation.mv_forecast_accuracy IS 'Hourly zone-level forecast error (head-of-flow zones) by DC, week and function.';

COMMENT ON MATERIALIZED VIEW labor_allocation.mv_zone_daily IS 'Zone x business day rollup of wms_zone_interval.';

COMMENT ON SCHEMA legacy IS 'Archived generic Supply Chain Ops demo tables (pre SC-6B POC). Safe to drop: DROP SCHEMA legacy CASCADE;';

COMMENT ON TABLE labor_allocation.agent_bottleneck_alert IS 'Emerging-bottleneck detections from queue depth, task aging and throughput trend projections. status: MITIGATED (action taken, no breach), BREACHED (breach happened anyway), FALSE_POSITIVE, OPEN (live).';

COMMENT ON TABLE labor_allocation.agent_outcome IS 'Closed-loop evaluation of every executed recommendation; reward feeds the policy learner.';

COMMENT ON TABLE labor_allocation.agent_playbook IS 'Daily labor playbook generated the evening before (includes forward-looking days). narrative is the GM-ready summary.';

COMMENT ON TABLE labor_allocation.agent_playbook_line IS 'Hour-by-zone staffing recommendation vs the static plan. local_hour is clock hour; 00-05 belong to the night shift of the playbook business_date.';

COMMENT ON TABLE labor_allocation.agent_recommendation IS 'Agent actions: REALLOCATE (move qualified associates between zones), VET_OFFER, VTO_OFFER, CROSS_TRAIN. rationale is the human-readable explanation shown to the supervisor.';

COMMENT ON TABLE labor_allocation.agent_rollout IS 'Agent operating mode per DC over time. SHADOW = recommendations logged only; ASSISTED = supervisor approves; AUTO = low-risk moves auto-executed.';

COMMENT ON TABLE labor_allocation.agent_training_run IS 'Weekly retrains - the "continuously learn from outcomes" loop. metrics hold wMAPE, alert precision/recall, acceptance and effectiveness measured on the prior week.';

COMMENT ON TABLE labor_allocation.agent_workload_forecast IS 'Forward-looking 15-minute workload forecast (rest of the live day through the end of the forecast horizon) with P10/P50/P90 bands, pilot DCs.';

COMMENT ON TABLE labor_allocation.ai_opportunity IS 'AI & Advanced Analytics opportunity register (sheet "Supply Chain - AI & Advanced Analytics Opportunities", tab "From Matt"). SC-6B is the use case this POC dataset proves out.';

COMMENT ON TABLE labor_allocation.associate IS 'Kronos person records (incl. agency temps). home_zone_id + shift_code is where the static plan puts them; the agent moves them intraday.';

COMMENT ON TABLE labor_allocation.associate_skill IS 'Skill matrix. Proficiency 1=in training, 2=qualified, 3=proficient, 4=expert/trainer. AGENT_CROSS_TRAIN rows came from agent cross-training recommendations.';

COMMENT ON TABLE labor_allocation.carrier_cutoff IS 'Carrier pulls / store-route departures. Work released less than lead_time_min before a pull is due at the next one.';

COMMENT ON TABLE labor_allocation.dc IS 'Distribution centers in the POC network. agent_cohort drives the difference-in-differences design: PILOT_WAVE_1/2 run the agent, CONTROL stays on static planning.';

COMMENT ON TABLE labor_allocation.dc_zone IS 'Labor zones inside each DC. standard_uph is the engineered LMS standard (zone UOM per direct labor hour).';

COMMENT ON TABLE labor_allocation.labor_constraint_rule IS 'Role, safety, compliance and labor-relations constraints the reallocation optimizer enforces (HARD) or penalizes (SOFT).';

COMMENT ON TABLE labor_allocation.labor_function IS 'Process families (inbound, putaway, replen, pick, pack, sort, ship, returns, ICQA).';

COMMENT ON TABLE labor_allocation.lms_associate_daily IS 'LMS performance per associate, day and zone worked. earned_hours = workload_done / standard_uph; pct_to_standard = earned / direct. reallocated_in = time came from an intraday move.';

COMMENT ON TABLE labor_allocation.ops_bottleneck_episode IS 'Contiguous intervals where a zone breached its aging SLA. first_alert_id / alert_lead_min show whether (and how early) the agent saw it coming. ended_at NULL = still open (live day).';

COMMENT ON TABLE labor_allocation.ops_cutoff_performance IS 'Service level per carrier pull / store route: units due vs shipped on time (units = eaches for parcel, cases for store).';

COMMENT ON TABLE labor_allocation.ops_firefighting_event IS 'Reactive manual interventions logged by supervisors (ad-hoc reassignments, mandatory OT, escalations, carrier holds) - the "reactive firefighting" the agent is meant to eliminate.';

COMMENT ON TABLE labor_allocation.ops_labor_move IS 'Every intraday reallocation of a named associate - agent-driven, playbook-scheduled or ad-hoc by a supervisor. target_skill_proficiency NULL = moved without the target skill (ad-hoc).';

COMMENT ON TABLE labor_allocation.poc_config IS 'POC run parameters: data window, as-of timestamp for the live day, cohort design, generator seed.';

COMMENT ON TABLE labor_allocation.poc_kpi_target IS 'VP-level POC success criteria. Measured values come from vw_exec_poc_scorecard (difference-in-differences vs control DCs).';

COMMENT ON TABLE labor_allocation.shift_definition IS 'Kronos shift templates. Business day starts 06:00 local; S3 (22:00-06:00) belongs to the business date it starts on.';

COMMENT ON TABLE labor_allocation.skill IS 'Skill / certification catalog behind the skill matrix. PIT certifications follow OSHA 29 CFR 1910.178(l) (re-evaluation every 36 months).';

COMMENT ON TABLE labor_allocation.wfm_static_labor_plan IS 'The status-quo plan: headcount fixed per zone per shift from a trailing 4-week same-weekday average. This is what the agent is measured against.';

COMMENT ON TABLE labor_allocation.wfm_timecard IS 'Kronos timecards: one row per scheduled associate-day (plus sixth-day call-ins). absence_code CALLOUT/NCNS/PTO/FMLA marks no-shows; ot_type SCHEDULED (static plan call-in/extension), MANDATORY (end-of-shift holdover) or VET (agent-planned voluntary extra time). clock_out NULL = still on the clock (live day).';

COMMENT ON TABLE labor_allocation.wms_inbound_appointment IS 'Dock/yard appointments - the inbound workload signal. Late trucks bunching up are a classic receiving bottleneck.';

COMMENT ON TABLE labor_allocation.wms_zone_interval IS 'Core real-time signal: one row per zone per 15-minute interval while the zone operates. Quantities are in the zone UOM (dc_zone.uom).';

COMMENT ON TABLE labor_allocation.zone_flow IS 'Process-flow graph: output of from_zone becomes work for to_zone. conversion_factor converts UOM (e.g. units -> packages).';

COMMENT ON TABLE labor_allocation.zone_skill_requirement IS 'Skills an associate must (is_mandatory) or should hold to be assigned to a zone.';

COMMENT ON TABLE labor_allocation.zone_travel_time IS 'Walk time between zones; the optimizer charges it as lost capacity on every move.';

COMMENT ON VIEW labor_allocation.vw_agent_alert_performance IS 'Bottleneck detection quality: precision, episode recall and median lead time per week.';

COMMENT ON VIEW labor_allocation.vw_agent_forecast_accuracy IS 'Hourly zone forecast wMAPE by week - shows the learning curve across forecaster versions.';

COMMENT ON VIEW labor_allocation.vw_agent_learning_curve IS 'Weekly retrain metrics - "continuously learn from outcomes".';

COMMENT ON VIEW labor_allocation.vw_agent_recommendation_funnel IS 'Generated -> accepted/auto -> effective, by DC, month, mode and recommendation type.';

COMMENT ON VIEW labor_allocation.vw_dc_daily_kpi IS 'Daily DC KPIs: UPLH, idle %, SLA %, OT %, labor cost per unit, absenteeism.';

COMMENT ON VIEW labor_allocation.vw_exec_agent_kpis IS 'Agent quality headline numbers for the VP deck.';

COMMENT ON VIEW labor_allocation.vw_exec_example_recommendations IS 'Top 10 executed reallocation recommendations end to end: what the agent saw, who approved, who moved, measured outcome.';

COMMENT ON VIEW labor_allocation.vw_exec_peak_imbalance IS 'The problem in one table: at the 10:00-14:00 peak, share of intervals over the aging SLA vs idle share of available time, by function, cohort and operating model (STATIC_PLAN = before go-live).';

COMMENT ON VIEW labor_allocation.vw_exec_poc_scorecard IS 'VP scorecard: pilot vs control, pre vs post, difference-in-differences (did_abs in KPI units, did_rel_pct relative). Seasonality and volume growth hit both groups, so the DiD isolates the agent effect.';

COMMENT ON VIEW labor_allocation.vw_exec_roi IS 'Annualized value of the agent from the DiD results: labor productivity, SLA misses avoided, supervisor time; plus network scale-out estimate.';

COMMENT ON VIEW labor_allocation.vw_exec_weekly_trend IS 'Weekly KPI trend by cohort (PILOT_WAVE_1 / PILOT_WAVE_2 / CONTROL) - the before/after chart.';

COMMENT ON VIEW labor_allocation.vw_live_move_candidates IS 'Who can be moved right now: every on-the-clock associate x every other zone in their DC they are fully qualified for (hard rules R01-R04, R07 applied). Donor-side minimum staffing (R05) is checked against vw_live_zone_status.';

COMMENT ON VIEW labor_allocation.vw_live_move_options IS 'Move options right now: qualified associates whose home zone stays at or above its minimum staffing if they leave, with the target zone''s live status. Filter by dc_code and target_zone.';

COMMENT ON VIEW labor_allocation.vw_live_on_the_clock IS 'Associates currently clocked in (Kronos) with their skill matrix - the pool the agent can move.';

COMMENT ON VIEW labor_allocation.vw_live_pending_recommendations IS 'Recommendations awaiting a supervisor decision right now, with eligible named associates currently on the clock.';

COMMENT ON VIEW labor_allocation.vw_live_playbook IS 'Today''s and upcoming daily labor playbooks (hour x zone) vs the static plan.';

COMMENT ON VIEW labor_allocation.vw_live_playbook_summary IS 'One row per pilot DC per day for the live day and the week ahead: forecast, recommended vs static-plan hours, VET/VTO, risk windows and the GM-ready narrative.';

COMMENT ON VIEW labor_allocation.vw_live_zone_status IS 'Latest 15-minute state of every zone on the live day - the control-tower view.';

COMMENT ON VIEW labor_allocation.vw_skill_coverage IS 'Skill-matrix depth per zone as of the live day: home associates vs qualified flex bench (all mandatory skills/certs valid).';

COMMENT ON VIEW labor_allocation.vw_supervisor_adoption IS 'Change-management lens: who trusts the agent, and how fast they respond.';
