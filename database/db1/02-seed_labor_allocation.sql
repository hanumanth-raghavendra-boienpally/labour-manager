-- =====================================================================
-- Labor Allocation: SAMPLE DATA SEED
-- Fills the 36 tables in schema labor_allocation (legacy is left empty).
-- Fictional data: 4 DCs, 36 zones, ~14 days of 15-minute zone intervals.
-- Run once on an EMPTY labor_allocation schema. One transaction: if
-- anything fails, nothing is written. Deterministic (fixed random seed).
-- Takes roughly 20-60 seconds.
-- =====================================================================
BEGIN;
SET LOCAL search_path = labor_allocation, pg_catalog;
SELECT setseed(0.2026);

-- ---------------------------------------------------------------------
-- 1. Reference / configuration data
-- ---------------------------------------------------------------------
INSERT INTO poc_config(key, value, description) VALUES
 ('data_window_start',     '2026-09-26', 'First business date with data'),
 ('data_window_end',       '2026-10-09', 'Last complete business date'),
 ('live_day',              '2026-10-10', 'Current (live) business day used by the vw_live_* views'),
 ('did_pre_window',        '2026-09-26..2026-09-30', 'Wave 1 pre period (baseline + shadow)'),
 ('did_post_window',       '2026-10-01..2026-10-09', 'Wave 1 post period (agent live)'),
 ('did_pre_window_wave2',  '2026-09-26..2026-10-06', 'Wave 2 pre period'),
 ('did_post_window_wave2', '2026-10-07..2026-10-09', 'Wave 2 post period'),
 ('cohort_design',         'PILOT_WAVE_1=DAL01; PILOT_WAVE_2=ATL01; CONTROL=PHX01,CLE01', 'Difference-in-differences cohorts'),
 ('generator_seed',        '0.2026', 'setseed() value used by the sample-data script');

INSERT INTO poc_kpi_target(kpi_code, kpi_name, unit, better_direction, target_improvement, definition, exec_owner) VALUES
 ('UPLH',              'Units per labor hour',        'units/hr',      'UP',   '+5% vs control',   'Units shipped / paid hours',                          'VP Fulfillment Operations'),
 ('COST_PER_UNIT',     'Labor cost per unit',         'USD/unit',      'DOWN', '-4% vs control',   'Labor cost / units shipped',                          'VP Supply Chain Finance'),
 ('IDLE_PCT',          'Idle time share',             '%',             'DOWN', '-20% vs control',  'Idle hours / (idle + direct hours)',                  'VP Fulfillment Operations'),
 ('OT_PCT',            'Overtime share of paid hours','%',             'DOWN', '-25% vs control',  'Overtime hours / paid hours',                         'VP Human Resources'),
 ('SLA_PCT',           'Carrier cutoff on-time rate', '%',             'UP',   '+1.0 pt vs control','Units on time / units due at carrier pull',          'VP Transportation'),
 ('BOTTLENECK_MIN',    'Bottleneck minutes per DC-day','min/DC-day',   'DOWN', '-30% vs control',  'Minutes zones exceeded their aging SLA',              'VP Fulfillment Operations'),
 ('FIREFIGHT_PER_DAY', 'Firefighting events per DC-day','events/DC-day','DOWN','-40% vs control',  'Reactive supervisor interventions',                   'VP Fulfillment Operations'),
 ('HEADCOUNT',         'Associates worked per DC-day','heads/DC-day',  'DOWN', '-3% vs control',   'Associates with a clock-in per day',                  'VP Human Resources');

INSERT INTO ai_opportunity(opportunity_code, sheet_reference, title, category, priority, problem_statement, business_need, capabilities, expected_benefits, in_poc_scope, source_note) VALUES
 ('SC-6B', 'Row 14', 'Dynamic labor allocation agent', 'Fulfillment Operations', 'High',
  'Static labor plans cannot react to intraday volume swings, so zones bottleneck while others sit idle.',
  'Move qualified associates between zones in near real time and plan tomorrow''s labor from a workload forecast.',
  ARRAY['Workload forecasting','Bottleneck early warning','Skill-aware reallocation','Daily labor playbook'],
  ARRAY['Higher units per labor hour','Fewer SLA misses','Less overtime','Less supervisor firefighting'], true, 'POC use case'),
 ('SC-2A', 'Row 6',  'Inventory placement optimizer', 'Inventory', 'Medium',
  'Slow-moving stock sits in prime pick locations.', 'Re-slot inventory based on velocity and affinity.',
  ARRAY['Velocity analysis','Slotting recommendations'], ARRAY['Shorter pick paths'], false, NULL),
 ('SC-3C', 'Row 9',  'Carrier delay prediction', 'Transportation', 'Medium',
  'Late carrier arrivals disrupt outbound planning.', 'Predict carrier delays and adjust cutoffs.',
  ARRAY['ETA prediction'], ARRAY['Fewer missed pulls'], false, NULL),
 ('SC-4A', 'Row 11', 'Dock appointment scheduler', 'Inbound', 'Low',
  'Late trucks bunch up at the dock.', 'Smooth dock appointments across the day.',
  ARRAY['Appointment optimization'], ARRAY['Shorter dwell time'], false, NULL),
 ('SC-5D', 'Row 12', 'Predictive equipment maintenance', 'Maintenance', 'Low',
  'Conveyor and truck downtime is reactive.', 'Predict failures before they cause downtime.',
  ARRAY['Anomaly detection'], ARRAY['Less unplanned downtime'], false, NULL),
 ('SC-7A', 'Row 18', 'Returns disposition automation', 'Returns', 'Medium',
  'Returns grading is manual and slow.', 'Auto-route returned items to resale, refurbish or recycle.',
  ARRAY['Image grading'], ARRAY['Faster returns processing'], false, NULL);

INSERT INTO labor_function(function_code, function_name, flow_stage, is_direct, description) VALUES
 ('INBOUND', 'Inbound receiving',  1, true, 'Unload trucks, scan and stage cartons and pallets'),
 ('PUTAWAY', 'Putaway',            2, true, 'Move received cartons to storage locations'),
 ('REPLEN',  'Replenishment',      3, true, 'Refill forward pick locations from reserve storage'),
 ('PICK',    'Picking',            4, true, 'Pick units for customer orders or store waves'),
 ('PACK',    'Packing',            5, true, 'Pack picked units into shipping cartons'),
 ('SORT',    'Sortation',          6, true, 'Sort packed cartons by carrier and route'),
 ('SHIP',    'Shipping and loading',7, true, 'Load trailers for carrier pulls and store routes'),
 ('RETURNS', 'Returns processing', 8, true, 'Receive, grade and restock customer returns'),
 ('ICQA',    'Inventory control (ICQA)', 9, true, 'Cycle counts and inventory accuracy audits');

INSERT INTO skill(skill_code, skill_name, function_code, is_certification, certifying_standard, validity_months, equipment, training_hours, description) VALUES
 ('RCV_DOCK',        'Dock receiving',                 'INBOUND', false, NULL, NULL, 'Handheld scanner', 8,  'Unload and scan inbound freight'),
 ('PIT_REACH',       'Reach truck operator',           'PUTAWAY', true,  'OSHA 29 CFR 1910.178(l)', 36, 'Reach truck', 24, 'Powered industrial truck: narrow-aisle reach'),
 ('PIT_FORKLIFT',    'Counterbalance forklift operator','REPLEN', true,  'OSHA 29 CFR 1910.178(l)', 36, 'Forklift', 24, 'Powered industrial truck: pallet moves'),
 ('PIT_ORDER_PICKER','Order picker operator',          'PICK',    true,  'OSHA 29 CFR 1910.178(l)', 36, 'Order picker', 16, 'Powered industrial truck: elevated picking'),
 ('PACK_STATION',    'Pack station',                   'PACK',    false, NULL, NULL, 'Pack bench', 6, 'Pack and label cartons'),
 ('SORT_OPS',        'Sorter operations',              'SORT',    false, NULL, NULL, 'Sorter induction', 8, 'Induct and clear the sorter'),
 ('SHIP_LOAD',       'Outbound loading',               'SHIP',    false, NULL, NULL, 'Dock plate', 8, 'Load trailers for carrier pulls'),
 ('RETURNS_PROC',    'Returns processing',             'RETURNS', false, NULL, NULL, 'Returns bench', 8, 'Grade and restock returns'),
 ('ICQA_CNT',        'ICQA cycle counting',            'ICQA',    false, NULL, NULL, 'Handheld scanner', 12, 'Count and reconcile inventory');

INSERT INTO labor_constraint_rule(rule_code, rule_name, rule_type, category, source, description, parameters, applies_to_dc, soft_penalty_weight, is_active) VALUES
 ('PIT_CERT',       'PIT certification required',        'HARD', 'Safety',     'OSHA 29 CFR 1910.178',  'Only associates with a valid certification may run powered industrial trucks.', '{"valid_months":36}', NULL, NULL, true),
 ('TEMP_NO_PIT',    'Agency temps do not drive PIT',     'HARD', 'Compliance', 'Staffing agency contract','Temporary associates are never assigned to PIT zones.', '{}', NULL, NULL, true),
 ('MED_RESTRICTION','Honour medical restrictions',       'HARD', 'Safety',     'HR policy',             'LIFT_25LB associates are not moved to receiving, loading or build zones; NO_PIT associates are not moved to PIT zones.', '{"restrictions":["LIFT_25LB","NO_PIT"]}', NULL, NULL, true),
 ('SKILL_MIN',      'Minimum proficiency in target zone','HARD', 'Skill',      'Operations standard',   'Mandatory zone skills must be held at or above the zone minimum proficiency.', '{}', NULL, NULL, true),
 ('MAX_MOVES_DAY',  'Maximum two moves per associate per day','HARD','Labor relations','Union agreement','Limits repeated reassignment of the same associate.', '{"max_moves":2}', NULL, NULL, true),
 ('MAX_DAILY_HOURS','Maximum paid hours per day',        'HARD', 'Compliance', 'Wage and hour policy',  'Regular plus overtime may not exceed 12 paid hours.', '{"max_hours":12}', NULL, NULL, true),
 ('MIN_ZONE_HC',    'Respect zone minimum headcount',    'HARD', 'Operations', 'Operations standard',   'A donor zone may not drop below its minimum headcount.', '{}', NULL, NULL, true),
 ('MIN_TRAVEL',     'Minimise walking time',             'SOFT', 'Efficiency', 'Industrial engineering','Prefer moves with shorter walk time between zones.', '{}', NULL, 0.30, true),
 ('SPREAD_MOVES',   'Spread moves fairly',               'SOFT', 'Labor relations','Operations standard','Avoid repeatedly moving the same associates.', '{}', NULL, 0.20, true),
 ('PREFER_VET',     'Prefer voluntary extra time',       'SOFT', 'Labor relations','HR policy',         'Offer voluntary extra time before mandatory overtime.', '{}', NULL, 0.40, true),
 ('RETURN_HOME',    'Return associates to home zone',    'SOFT', 'Efficiency', 'Operations standard',   'Send moved associates back once the bottleneck clears.', '{}', NULL, 0.15, true);

INSERT INTO dc(dc_id, dc_code, dc_name, city, state, region, timezone, dc_type, building_sqft, inbound_doors, outbound_doors,
               shifts_operated, operating_days, volume_uom, design_daily_volume, agent_cohort, general_manager,
               wms_platform, lms_platform, wfm_platform) VALUES
 (1, 'DAL01', 'Dallas Fulfillment Center',   'Dallas',    'TX', 'South',     'America/Chicago',  'ECOM_FC',   850000, 24, 40, 3, 'MON-SUN', 'units', 18000, 'PILOT_WAVE_1', 'Maria Hernandez', 'Manhattan WMS', 'Manhattan LMS', 'Kronos UKG'),
 (2, 'ATL01', 'Atlanta Omni DC',             'Atlanta',   'GA', 'Southeast', 'America/New_York', 'OMNI_DC',   720000, 20, 36, 3, 'MON-SUN', 'units', 15000, 'PILOT_WAVE_2', 'James Carter',    'Manhattan WMS', 'Manhattan LMS', 'Kronos UKG'),
 (3, 'PHX01', 'Phoenix Fulfillment Center',  'Phoenix',   'AZ', 'West',      'America/Phoenix',  'ECOM_FC',   780000, 22, 38, 3, 'MON-SUN', 'units', 16000, 'CONTROL',      'Priya Nair',      'Manhattan WMS', 'Manhattan LMS', 'Kronos UKG'),
 (4, 'CLE01', 'Cleveland Retail DC',         'Cleveland', 'OH', 'Midwest',   'America/New_York', 'RETAIL_DC', 640000, 18, 30, 3, 'MON-SUN', 'cases', 12000, 'CONTROL',      'Tom Brennan',     'Manhattan WMS', 'Manhattan LMS', 'Kronos UKG');

INSERT INTO shift_definition(dc_id, shift_code, shift_name, start_time, end_time, paid_hours, unpaid_meal_min, paid_breaks, is_part_time)
SELECT d.dc_id, s.code, s.nm, s.st::time, s.en::time, 7.5, 30, 2, false
FROM dc d CROSS JOIN (VALUES ('S1','Day','06:00','14:00'), ('S2','Swing','14:00','22:00'), ('S3','Night','22:00','06:00')) s(code, nm, st, en);

INSERT INTO agent_rollout(dc_id, phase, start_date, end_date, description) VALUES
 (1, 'BASELINE', '2026-09-26', '2026-09-28', 'Static plan only'),
 (1, 'SHADOW',   '2026-09-29', '2026-09-30', 'Agent logs recommendations; supervisors do not see them'),
 (1, 'ASSISTED', '2026-10-01', '2026-10-05', 'Supervisors approve each reallocation'),
 (1, 'AUTO',     '2026-10-06', NULL,         'Low-risk moves auto-executed'),
 (2, 'BASELINE', '2026-09-26', '2026-10-02', 'Static plan only'),
 (2, 'SHADOW',   '2026-10-03', '2026-10-06', 'Agent logs recommendations; supervisors do not see them'),
 (2, 'ASSISTED', '2026-10-07', NULL,         'Supervisors approve each reallocation'),
 (3, 'BASELINE', '2026-09-26', NULL,         'Control DC: static plan only'),
 (4, 'BASELINE', '2026-09-26', NULL,         'Control DC: static plan only');

INSERT INTO agent_model_version(model_version_id, component, version, algorithm, key_features, deployed_on, retired_on, release_notes) VALUES
 (1, 'WORKLOAD_FORECASTER',  '1.0', 'Gradient boosted quantile regression', ARRAY['hour of day','day of week','inbound appointments','trailing volume'], '2026-09-01', '2026-10-02', 'Initial day-ahead and intraday forecaster'),
 (2, 'WORKLOAD_FORECASTER',  '1.1', 'Gradient boosted quantile regression', ARRAY['hour of day','day of week','inbound appointments','trailing volume','promo calendar'], '2026-10-03', NULL, 'Adds promotion calendar and bias correction'),
 (3, 'BOTTLENECK_DETECTOR',  '1.0', 'Queue growth and task aging projection', ARRAY['queue depth','queue growth','task age','throughput trend'], '2026-09-01', NULL, 'Initial early-warning detector'),
 (4, 'REALLOCATION_POLICY',  '1.0', 'Constraint-based optimizer with learned scoring', ARRAY['skills','walk time','proficiency','home zone'], '2026-09-01', '2026-10-02', 'Initial reallocation policy'),
 (5, 'REALLOCATION_POLICY',  '1.1', 'Constraint-based optimizer with learned scoring', ARRAY['skills','walk time','proficiency','home zone','outcome feedback'], '2026-10-03', NULL, 'Learns from measured outcomes');

INSERT INTO agent_training_run(run_id, model_version_id, run_at, scope_dc_id, train_start, train_end, training_rows, metrics, promoted, notes) VALUES
 (1, 1, '2026-09-27 02:00+00', NULL, '2026-09-26', '2026-09-26', 3456,  '{"wmape_hourly_zone":24.8}', true,  'First weekly retrain'),
 (2, 3, '2026-09-27 02:30+00', NULL, '2026-09-26', '2026-09-26', 3456,  '{"precision":71.0,"episode_recall":58.0,"median_lead_min":28}', true, 'First detector calibration'),
 (3, 4, '2026-09-27 03:00+00', NULL, '2026-09-26', '2026-09-26', 120,   '{"acceptance_rate":0.0,"effective_rate":0.0,"mean_reward":0.0}', true, 'Policy bootstrap from shadow logs'),
 (4, 1, '2026-10-04 02:00+00', NULL, '2026-09-26', '2026-10-03', 27648, '{"wmape_hourly_zone":19.6}', true,  'Weekly retrain; improved bias'),
 (5, 3, '2026-10-04 02:30+00', NULL, '2026-09-26', '2026-10-03', 27648, '{"precision":78.0,"episode_recall":67.0,"median_lead_min":34}', true, 'Weekly detector retrain'),
 (6, 5, '2026-10-04 03:00+00', NULL, '2026-09-26', '2026-10-03', 410,   '{"acceptance_rate":0.62,"effective_rate":0.71,"mean_reward":0.34}', true, 'Policy retrained with outcome feedback'),
 (7, 2, '2026-10-04 04:00+00', NULL, '2026-09-26', '2026-10-03', 27648, '{"wmape_hourly_zone":17.9}', true,  'Forecaster 1.1 promoted');

-- ---------------------------------------------------------------------
-- 2. Zones, flows, plan, supervisors, pay rates
-- ---------------------------------------------------------------------
CREATE TEMP TABLE _fn(idx int, func text, prefix text, nm text, uom text, upu real, uph real, sla int, minhc int, maxhc int,
                      pit boolean, skill text, src text, defer boolean, shifts text, area text, floor int, volf numeric,
                      prof text, jt text, base_rate numeric) ON COMMIT DROP;
INSERT INTO _fn VALUES
 (1,'INBOUND','RCV','Receiving','cartons',1.0,220,60,2,10,false,'RCV_DOCK','INBOUND',false,'S1,S2,S3','Inbound dock',1,0.3333,'INBOUND','Receiving Associate',17.50),
 (2,'PUTAWAY','PUT','Putaway','cartons',1.0,90,90,2,12,true,'PIT_REACH',NULL,false,'S1,S2,S3','Reserve racking',1,0.3333,'INBOUND','Putaway Driver',19.25),
 (3,'REPLEN','RPL','Replenishment','cases',1.0,60,120,1,8,true,'PIT_FORKLIFT','REPLEN',false,'S1,S2,S3','Reserve racking',1,0.0833,'REPLEN','Replenishment Driver',19.50),
 (4,'PICK','PCK','Picking','units',1.0,100,45,6,30,true,'PIT_ORDER_PICKER','ORDERS',false,'S1,S2,S3','Pick modules',2,1.0,'ORDERS','Order Picker',18.75),
 (5,'PACK','PAK','Packing','packages',1.59,85,30,3,20,false,'PACK_STATION',NULL,false,'S1,S2,S3','Pack mezzanine',2,0.6289,'ORDERS','Packer',17.25),
 (6,'SORT','SRT','Sortation','packages',1.59,180,30,2,10,false,'SORT_OPS',NULL,false,'S1,S2,S3','Sorter',1,0.6289,'ORDERS','Sorter Operator',17.75),
 (7,'SHIP','SHP','Shipping and loading','packages',1.59,260,20,2,10,false,'SHIP_LOAD',NULL,false,'S1,S2,S3','Outbound dock',1,0.6289,'ORDERS','Dock Loader',18.00),
 (8,'RETURNS','RET','Returns processing','units',1.0,50,240,1,8,false,'RETURNS_PROC','RETURNS',true,'S1,S2','Returns cage',1,0.10,'RETURNS','Returns Associate',17.00),
 (9,'ICQA','ICQ','Inventory control (ICQA)','tasks',1.0,20,480,1,6,false,'ICQA_CNT','ICQA',true,'S1,S2','ICQA cage',1,0.04,'ICQA','ICQA Auditor',18.25);

INSERT INTO dc_zone(zone_id, dc_id, zone_code, zone_name, function_code, uom, units_per_uom, standard_uph, aging_sla_min,
                    min_headcount, max_headcount, requires_pit, primary_skill_code, work_source, flow_chain, is_deferrable,
                    operating_shifts, building_area, floor_level)
SELECT d.dc_id*10 + f.idx, d.dc_id, f.prefix || '-01', f.nm, f.func,
       CASE WHEN d.dc_type = 'RETAIL_DC' AND f.idx IN (5,6,7) THEN 'cases' ELSE f.uom END,
       CASE WHEN d.dc_type = 'RETAIL_DC' AND f.idx IN (5,6,7) THEN 1.0::real ELSE f.upu END,
       round((f.uph * (0.95 + 0.1 * ((d.dc_id*7 + f.idx*3) % 10) / 10.0))::numeric, 1)::real,
       f.sla, f.minhc, f.maxhc, f.pit, f.skill,
       CASE WHEN f.idx = 4 AND d.dc_type = 'RETAIL_DC' THEN 'STORE_WAVES' ELSE f.src END,
       CASE WHEN f.idx BETWEEN 4 AND 7 THEN (CASE WHEN d.dc_type = 'RETAIL_DC' THEN 'STORE' ELSE 'PARCEL' END) END,
       f.defer, f.shifts, f.area, f.floor
FROM dc d CROSS JOIN _fn f;

CREATE TEMP TABLE _zone ON COMMIT DROP AS
SELECT z.zone_id, z.dc_id, (z.zone_id % 10) AS zi, z.function_code AS func, z.zone_code, z.standard_uph AS uph,
       z.units_per_uom AS upu, z.aging_sla_min AS sla, z.min_headcount AS minhc, z.max_headcount AS maxhc,
       z.work_source AS src, z.is_deferrable AS defer, z.operating_shifts AS shifts, z.requires_pit AS pit,
       z.primary_skill_code AS skill, z.uom,
       CASE WHEN d.dc_type = 'RETAIL_DC' AND f.idx IN (4,5,6,7) THEN 'STORE_WAVES' ELSE f.prof END AS prof,
       CASE WHEN d.dc_type = 'RETAIL_DC' AND f.idx IN (5,6,7) THEN 1.0 ELSE f.volf END AS volf,
       d.design_daily_volume AS design, d.timezone AS tz, d.dc_type, f.jt
FROM dc_zone z JOIN dc d USING (dc_id) JOIN _fn f ON f.idx = z.zone_id % 10;

-- process flow: receiving -> putaway; pick -> pack -> sort -> ship
INSERT INTO zone_flow(from_zone_id, to_zone_id, conversion_factor, flow_share, transit_min)
SELECT a.zone_id, b.zone_id,
       CASE WHEN a.zi = 4 THEN (b.volf / a.volf)::real ELSE 1.0::real END, 1.0, CASE WHEN a.zi IN (1,7) THEN 15 ELSE 10 END
FROM _zone a JOIN _zone b ON a.dc_id = b.dc_id AND ((a.zi, b.zi) IN ((1,2),(4,5),(5,6),(6,7)));

INSERT INTO zone_travel_time(from_zone_id, to_zone_id, walk_minutes, ppe_change, same_floor)
SELECT a.zone_id, b.zone_id,
       round((1.5 + 0.9 * abs(a.zi - b.zi) + CASE WHEN fa.floor <> fb.floor THEN 1.5 ELSE 0 END)::numeric, 1)::real,
       ((a.zi IN (1,7,8)) <> (b.zi IN (1,7,8))), (fa.floor = fb.floor)
FROM _zone a JOIN _zone b ON a.dc_id = b.dc_id AND a.zone_id <> b.zone_id
JOIN _fn fa ON fa.idx = a.zi JOIN _fn fb ON fb.idx = b.zi;

INSERT INTO zone_skill_requirement(zone_id, skill_code, min_proficiency, is_mandatory)
SELECT zone_id, skill, CASE WHEN pit THEN 2 ELSE 1 END, true FROM _zone
UNION ALL
SELECT zone_id, 'PACK_STATION', 1, false FROM _zone WHERE zi = 4;

INSERT INTO carrier_cutoff(cutoff_id, dc_id, flow_chain, carrier, service_level, pull_time, lead_time_min, miss_cost_per_unit)
SELECT d.dc_id*10 + c.n, d.dc_id,
       CASE WHEN d.dc_type = 'RETAIL_DC' THEN 'STORE' ELSE 'PARCEL' END,
       CASE WHEN d.dc_type = 'RETAIL_DC' THEN c.store_route ELSE c.carrier END,
       CASE WHEN d.dc_type = 'RETAIL_DC' THEN 'ROUTE' ELSE c.svc END,
       c.pull::time, c.lead,
       CASE WHEN d.dc_type = 'RETAIL_DC' THEN c.cost * 0.45 ELSE c.cost END
FROM dc d CROSS JOIN (VALUES
  (1, 'Parcel Carrier A', 'GROUND',  '11:30', 90, 1.85, 'Store Route North'),
  (2, 'Parcel Carrier B', 'EXPRESS', '16:30', 90, 3.10, 'Store Route South'),
  (3, 'Regional Carrier', 'GROUND',  '20:30', 90, 2.40, 'Store Route East')) c(n, carrier, svc, pull, lead, cost, store_route);

-- supervisors
INSERT INTO ops_supervisor(supervisor_id, dc_id, full_name, title, shift_code, area, years_experience, agent_adoption_score)
SELECT d.dc_id*100 + row_number() OVER (PARTITION BY d.dc_id ORDER BY s.shift_code, a.area)::int, d.dc_id,
       (ARRAY['Alicia','Marcus','Dana','Rafael','Keisha','Owen','Leila','Gabriel','Tasha','Noah','Imani','Derek'])[1 + (d.dc_id*5 + s.sn*3 + a.an) % 12] || ' ' ||
       (ARRAY['Foster','Bennett','Ortiz','Shah','Coleman','Park','Murphy','Diaz','Powell','Ibrahim','Grant','Walsh'])[1 + (d.dc_id*7 + s.sn*5 + a.an*2) % 12],
       CASE WHEN a.an = 1 THEN 'Area Manager' ELSE 'Shift Supervisor' END, s.shift_code, a.area,
       (3 + (d.dc_id*3 + s.sn*5 + a.an*7) % 13)::smallint,
       CASE WHEN d.agent_cohort = 'CONTROL' THEN NULL ELSE round((0.45 + ((d.dc_id*13 + s.sn*17 + a.an*11) % 40) / 100.0)::numeric, 2)::real END
FROM dc d
CROSS JOIN (VALUES ('S1',1), ('S2',2), ('S3',3)) s(shift_code, sn)
CROSS JOIN (VALUES ('Inbound and storage',1), ('Outbound',2), ('Returns and ICQA',3)) a(area, an)
WHERE NOT (s.shift_code = 'S3' AND a.an = 3);

INSERT INTO pay_rate_card(dc_id, job_title, base_rate, temp_bill_rate, ot_multiplier, benefits_burden_pct)
SELECT d.dc_id, f.jt,
       round((f.base_rate * (CASE d.dc_id WHEN 1 THEN 1.00 WHEN 2 THEN 1.02 WHEN 3 THEN 1.06 ELSE 0.98 END))::numeric, 2),
       round((f.base_rate * (CASE d.dc_id WHEN 1 THEN 1.00 WHEN 2 THEN 1.02 WHEN 3 THEN 1.06 ELSE 0.98 END) * 1.38)::numeric, 2),
       1.50, 24.5
FROM dc d CROSS JOIN _fn f;

-- ---------------------------------------------------------------------
-- 3. Calendar, demand profiles and the static labor plan
-- ---------------------------------------------------------------------
CREATE TEMP TABLE _day ON COMMIT DROP AS
SELECT d::date AS d, extract(dow FROM d)::int AS dow,
       (ARRAY[0.74,1.00,0.98,0.96,0.98,1.04,0.82])[extract(dow FROM d)::int + 1]::numeric AS dowf
FROM generate_series('2026-09-26'::date, '2026-10-09'::date, '1 day') d;

CREATE TEMP TABLE _prof ON COMMIT DROP AS
SELECT p.prof, h, (1 + p.amp * cos(2 * pi() * (h - p.peak) / 24.0))::numeric AS w
FROM (VALUES ('ORDERS',15,0.55), ('STORE_WAVES',11,0.80), ('INBOUND',9,0.70),
             ('REPLEN',10,0.40), ('RETURNS',11,0.50), ('ICQA',12,0.30)) p(prof, peak, amp)
CROSS JOIN generate_series(0,23) h;

-- normalised hourly demand weight per zone (zero outside the shifts the zone operates)
CREATE TEMP TABLE _zh ON COMMIT DROP AS
WITH x AS (
  SELECT z.zone_id, p.h, p.w, z.shifts,
         CASE WHEN p.h BETWEEN 6 AND 13 THEN 'S1' WHEN p.h BETWEEN 14 AND 21 THEN 'S2' ELSE 'S3' END AS sh
  FROM _zone z JOIN _prof p ON p.prof = z.prof)
SELECT zone_id, h, sh,
       (CASE WHEN position(sh IN shifts) > 0 THEN w ELSE 0 END) /
       sum(CASE WHEN position(sh IN shifts) > 0 THEN w ELSE 0 END) OVER (PARTITION BY zone_id) AS wn
FROM x;

INSERT INTO wfm_static_labor_plan(dc_id, business_date, shift_code, zone_id, planned_volume, required_headcount,
                                  scheduled_headcount, planning_basis, published_at)
SELECT z.dc_id, dy.d, sh.sh, z.zone_id,
       round(z.design * z.volf * dy.dowf * sh.share)::int,
       round((z.design * z.volf * dy.dowf * sh.share / (z.uph * 7.5 * 0.93))::numeric, 2)::real,
       least(z.maxhc, greatest(z.minhc, ceil(z.design * z.volf * dy.dowf * sh.share / (z.uph * 7.5 * 0.93))))::smallint,
       'TRAILING_4W_SAME_WEEKDAY_AVG',
       ((dy.d - 1) + time '16:00') AT TIME ZONE z.tz
FROM _zone z CROSS JOIN _day dy
JOIN (SELECT zone_id, sh, sum(wn) AS share FROM _zh GROUP BY zone_id, sh) sh ON sh.zone_id = z.zone_id AND sh.share > 0;

-- ---------------------------------------------------------------------
-- 4. Associates, skills, timecards
-- ---------------------------------------------------------------------
CREATE TEMP TABLE _roster ON COMMIT DROP AS
SELECT p.dc_id, p.zone_id, p.shift_code, g AS n
FROM (SELECT dc_id, zone_id, shift_code, (ceil(avg(scheduled_headcount) * 1.40) + CASE WHEN avg(scheduled_headcount) < 4 THEN 1 ELSE 0 END)::int AS cnt
      FROM wfm_static_labor_plan GROUP BY dc_id, zone_id, shift_code) p
CROSS JOIN LATERAL generate_series(1, p.cnt) g;

CREATE TEMP TABLE _a ON COMMIT DROP AS
SELECT row_number() OVER (ORDER BY r.dc_id, r.zone_id, r.shift_code, r.n)::int + 1000 AS associate_id,
       r.dc_id, r.zone_id, r.shift_code, r.n, z.skill, z.pit, z.jt, z.zi,
       random() AS r1, random() AS r2, random() AS r3, random() AS r4, random() AS r5, random() AS r6, random() AS r7
FROM _roster r JOIN _zone z USING (zone_id);

ALTER TABLE _a ADD COLUMN emp text, ADD COLUMN restr text[];
UPDATE _a SET emp = CASE WHEN pit THEN (CASE WHEN r1 < 0.08 THEN 'PT' ELSE 'FT' END)
                         WHEN r1 < 0.14 THEN 'TEMP' WHEN r1 < 0.22 THEN 'PT' ELSE 'FT' END,
              restr = CASE WHEN NOT pit AND r7 < 0.03 THEN ARRAY['NO_PIT']
                           WHEN zi NOT IN (1,7) AND r7 >= 0.03 AND r7 < 0.08 THEN ARRAY['LIFT_25LB']
                           ELSE NULL END;

INSERT INTO associate(associate_id, kronos_person_num, badge_id, first_name, last_name, dc_id, home_zone_id, shift_code,
                      work_pattern, employment_type, staffing_agency, job_title, hourly_rate, hire_date, termination_date,
                      termination_reason, status, is_lead, is_flex_pool, restrictions, base_performance)
SELECT a.associate_id, 'K' || lpad(a.associate_id::text, 6, '0'), 'B' || lpad((a.associate_id * 37 % 99999)::text, 5, '0'),
       (ARRAY['James','Maria','Robert','Linda','Michael','Priya','David','Aisha','Carlos','Emily','Daniel','Sofia','Kevin','Nia','Brian',
              'Elena','Tyrone','Hannah','Luis','Grace','Omar','Jessica','Andre','Mei','Samuel','Rosa','Victor','Amara','Ethan','Carmen'])[1 + floor(a.r2 * 30)::int],
       (ARRAY['Johnson','Garcia','Smith','Patel','Williams','Nguyen','Brown','Lopez','Davis','Kim','Miller','Hernandez','Wilson','Okafor','Moore',
              'Martinez','Taylor','Singh','Anderson','Reyes','Thomas','Chen','Jackson','Flores','White','Ali','Harris','Torres','Clark','Rivera'])[1 + floor(a.r3 * 30)::int],
       a.dc_id, a.zone_id, a.shift_code,
       (ARRAY['MON-FRI','TUE-SAT','WED-SUN','THU-MON','FRI-TUE','SAT-WED','SUN-THU'])[1 + (a.n + a.zone_id) % 7],
       a.emp,
       CASE WHEN a.emp = 'TEMP' THEN (ARRAY['StaffRight Agency','FlexForce Staffing','ProLabor Partners'])[1 + floor(a.r2 * 3)::int] END,
       a.jt,
       round((c.base_rate * (1 + a.r4 * 0.08) * CASE WHEN a.emp = 'TEMP' THEN 0.97 ELSE 1 END)::numeric, 2),
       CASE WHEN a.emp = 'TEMP' THEN date '2026-09-26' - (14 + floor(a.r5 * 170))::int
            ELSE date '2026-09-26' - (30 + floor(a.r5 * 1600))::int END,
       CASE WHEN a.emp <> 'TEMP' AND a.r6 < 0.03 THEN date '2026-09-28' + floor(a.r5 * 8)::int END,
       CASE WHEN a.emp <> 'TEMP' AND a.r6 < 0.03 THEN (ARRAY['Voluntary resignation','Attendance policy','Performance','Relocation'])[1 + floor(a.r4 * 4)::int] END,
       CASE WHEN a.emp <> 'TEMP' AND a.r6 < 0.03 THEN 'TERMINATED' ELSE 'ACTIVE' END,
       (a.n = 1 AND a.emp = 'FT' AND a.r4 < 0.6),
       (a.r5 < 0.30),
       a.restr,
       round((0.85 + a.r3 * 0.30)::numeric, 3)::real
FROM _a a JOIN pay_rate_card c ON c.dc_id = a.dc_id AND c.job_title = a.jt;

-- home skill (certifications were renewed recently so they are still valid)
INSERT INTO associate_skill(associate_id, skill_code, proficiency, certified_on, expires_on, source, recommended_by_rec_id)
SELECT a.associate_id, a.skill, (2 + floor(a.r4 * 3))::smallint,
       cert.d, CASE WHEN s.is_certification THEN (cert.d + interval '36 months')::date END, 'HOME_ROLE', NULL
FROM _a a JOIN skill s ON s.skill_code = a.skill
JOIN associate x ON x.associate_id = a.associate_id
CROSS JOIN LATERAL (SELECT CASE WHEN s.is_certification
                                THEN greatest(x.hire_date + 14, date '2026-09-26' - floor(a.r5 * 900)::int)
                                ELSE x.hire_date + 14 END AS d) cert;

-- cross-trained skills (flex-pool associates hold three, everyone else one)
INSERT INTO associate_skill(associate_id, skill_code, proficiency, certified_on, expires_on, source, recommended_by_rec_id)
SELECT q.associate_id, q.skill_code, (CASE WHEN q.p < 0.4 THEN 3 ELSE 2 END)::smallint, q.cd,
       CASE WHEN q.is_certification THEN (q.cd + interval '36 months')::date END, 'CROSS_TRAINED', NULL
FROM (SELECT a.associate_id, sk.skill_code, sk.is_certification, random() AS p, x.is_flex_pool,
             least(date '2026-09-25', greatest(x.hire_date + 7, date '2026-09-26' - floor(random() * 500)::int)) AS cd,
             row_number() OVER (PARTITION BY a.associate_id ORDER BY random()) AS rn
      FROM _a a JOIN associate x ON x.associate_id = a.associate_id
      JOIN skill sk ON sk.skill_code <> a.skill
       AND (NOT sk.is_certification OR (x.employment_type <> 'TEMP' AND NOT ('NO_PIT' = ANY (COALESCE(x.restrictions, '{}')))))) q
WHERE q.rn <= CASE WHEN q.is_flex_pool THEN 3 ELSE 1 END;

-- timecards: one row per scheduled associate-day
CREATE TEMP TABLE _phase ON COMMIT DROP AS
SELECT dc.dc_id, dy.d,
       (SELECT r.phase FROM agent_rollout r WHERE r.dc_id = dc.dc_id AND dy.d BETWEEN r.start_date AND COALESCE(r.end_date, date '9999-12-31')) AS phase
FROM dc CROSS JOIN _day dy;

CREATE TEMP TABLE _tc ON COMMIT DROP AS
SELECT x.associate_id, dy.d, x.dc_id, x.shift_code, x.home_zone_id, x.employment_type, x.hourly_rate, x.termination_date,
       p.phase, (p.phase IN ('ASSISTED','AUTO')) AS live, dc.timezone AS tz, sd.start_time,
       random() AS a1, random() AS a2, random() AS a3, random() AS a4, random() AS a5, random() AS a6
FROM associate x
CROSS JOIN _day dy
JOIN _phase p ON p.dc_id = x.dc_id AND p.d = dy.d
JOIN dc ON dc.dc_id = x.dc_id
JOIN shift_definition sd ON sd.dc_id = x.dc_id AND sd.shift_code = x.shift_code
WHERE dy.d >= x.hire_date AND (x.termination_date IS NULL OR dy.d <= x.termination_date)
  AND (extract(isodow FROM dy.d)::int - 1 - (array_position(ARRAY['MON-FRI','TUE-SAT','WED-SUN','THU-MON','FRI-TUE','SAT-WED','SUN-THU'], x.work_pattern) - 1) + 7) % 7 < 5;

INSERT INTO wfm_timecard(associate_id, business_date, dc_id, shift_code, home_zone_id, clock_in, clock_out, unpaid_meal_min,
                         regular_hours, overtime_hours, vto_hours, absence_code, late_minutes, ot_type, labor_cost_usd)
SELECT t.associate_id, t.d, t.dc_id, t.shift_code, t.home_zone_id,
       CASE WHEN t.absence IS NULL THEN ((t.d + t.start_time + make_interval(mins => t.late)) AT TIME ZONE t.tz) END,
       CASE WHEN t.absence IS NULL THEN ((t.d + t.start_time + interval '8 hours' + make_interval(mins => round(60 * (t.ot - t.vto))::int)) AT TIME ZONE t.tz) END,
       30,
       CASE WHEN t.absence IS NULL THEN greatest(0, 7.5 - t.vto - t.late / 60.0)::real ELSE 0 END,
       CASE WHEN t.absence IS NULL THEN t.ot::real ELSE 0 END,
       CASE WHEN t.absence IS NULL THEN t.vto::real ELSE 0 END,
       t.absence, CASE WHEN t.absence IS NULL THEN t.late ELSE 0 END::smallint,
       CASE WHEN t.absence IS NULL AND t.ot > 0
            THEN (CASE WHEN t.live THEN (CASE WHEN t.a5 < 0.65 THEN 'VET' WHEN t.a5 < 0.85 THEN 'SCHEDULED' ELSE 'MANDATORY' END)
                       ELSE (CASE WHEN t.a5 < 0.55 THEN 'SCHEDULED' ELSE 'MANDATORY' END) END) END,
       CASE WHEN t.absence IS NULL THEN
            ((greatest(0, 7.5 - t.vto - t.late / 60.0) * t.hourly_rate + t.ot * t.hourly_rate * 1.5)
             * CASE WHEN t.employment_type = 'TEMP' THEN 1.38 ELSE 1.245 END)::real
       ELSE 0 END
FROM (SELECT c.*,
             CASE WHEN c.a1 < 0.035 THEN 'CALLOUT' WHEN c.a1 < 0.045 THEN 'NCNS'
                  WHEN c.a1 < 0.060 THEN (CASE WHEN c.employment_type = 'TEMP' THEN 'CALLOUT' ELSE 'PTO' END)
                  WHEN c.a1 < 0.065 THEN (CASE WHEN c.employment_type = 'TEMP' THEN 'CALLOUT' ELSE 'FMLA' END) END AS absence,
             CASE WHEN c.a2 < 0.09 THEN 5 + floor(c.a3 * 20)::int ELSE 0 END AS late,
             CASE WHEN c.a4 < (CASE WHEN c.live THEN 0.10 ELSE 0.21 END) THEN 1.0 + 0.5 * floor(c.a3 * 4) ELSE 0 END AS ot,
             CASE WHEN c.live AND c.a6 < 0.05 THEN 2.0 ELSE 0 END AS vto
      FROM _tc c) t;

-- ---------------------------------------------------------------------
-- 5. 15-minute zone simulation (queues, headcount, aging, forecasts)
--    Static-plan DCs/days use the people who clocked in at their home zone.
--    Agent-live days (ASSISTED/AUTO) move the same pool of people toward
--    the zones whose queues need them, within skill/flex limits.
-- ---------------------------------------------------------------------
CREATE TEMP TABLE _home ON COMMIT DROP AS
SELECT dc_id, business_date AS d, home_zone_id AS zone_id, shift_code, (count(*) FILTER (WHERE clock_in IS NOT NULL))::int AS heads
FROM wfm_timecard GROUP BY dc_id, business_date, home_zone_id, shift_code;

CREATE TEMP TABLE _dcday ON COMMIT DROP AS
SELECT p.dc_id, p.d, p.phase, dy.dowf,
       (1 + (random() - 0.5) * 0.10) * CASE WHEN random() < 0.20 THEN 1.10 + random() * 0.12 ELSE 1 END AS sg_ord,
       0.85 + random() * 0.30 AS sg_in,
       0.85 + random() * 0.30 AS sg_ret,
       0.95 + random() * 0.10 AS sg_rpl,
       (random() < 0.30) AS spk_ord, 16 + floor(random() * 56)::int AS spk_ord_at,
       (random() < 0.25) AS spk_in,  8 + floor(random() * 60)::int AS spk_in_at
FROM _phase p JOIN _day dy ON dy.d = p.d;

DO $seed$
DECLARE
  c record; dd record; zr record;
  uph float8[]; volf float8[]; minhc int[]; maxhc int[]; sla int[]; zid int[]; shifts text[]; wn float8[];
  heads int[]; plan int[]; eff float8[]; sg float8[];
  q float8[]; lastin float8[]; dn float8[]; infl float8[]; h float8[]; need float8[]; lo float8[]; hi float8[];
  ex float8[]; act boolean[]; estin float8[]; hp float8[];
  k int; i int; hr int; sidx int; shc text; ls int; its timestamptz;
  learn float8; live boolean; pilot boolean; spk float8;
  pool float8; s_d float8; s_lo float8; slack float8; s_room float8;
  wk float8; cap float8; qn float8; util float8; ag int; fd int; fi int;
BEGIN
  FOR c IN SELECT dc_id, design_daily_volume::float8 AS design, timezone AS tz, agent_cohort FROM dc ORDER BY dc_id LOOP
    uph := array_fill(0::float8, ARRAY[9]);  volf := array_fill(0::float8, ARRAY[9]);
    minhc := array_fill(0, ARRAY[9]);        maxhc := array_fill(0, ARRAY[9]);
    sla := array_fill(0, ARRAY[9]);          zid := array_fill(0, ARRAY[9]);
    shifts := array_fill(''::text, ARRAY[9]); wn := array_fill(0::float8, ARRAY[9,24]);
    q := array_fill(0::float8, ARRAY[9]);    lastin := array_fill(0::float8, ARRAY[9]);
    FOR zr IN SELECT * FROM _zone WHERE dc_id = c.dc_id ORDER BY zi LOOP
      uph[zr.zi] := zr.uph; volf[zr.zi] := zr.volf; minhc[zr.zi] := zr.minhc; maxhc[zr.zi] := zr.maxhc;
      sla[zr.zi] := zr.sla; zid[zr.zi] := zr.zone_id; shifts[zr.zi] := zr.shifts;
    END LOOP;
    FOR zr IN SELECT z.zi, hh.h, hh.wn FROM _zh hh JOIN _zone z USING (zone_id) WHERE z.dc_id = c.dc_id LOOP
      wn[zr.zi][zr.h + 1] := zr.wn;
    END LOOP;

    FOR dd IN SELECT * FROM _dcday WHERE dc_id = c.dc_id ORDER BY d LOOP
      heads := array_fill(0, ARRAY[9,3]);  plan := array_fill(0, ARRAY[9,3]);
      FOR zr IN SELECT z.zi, substr(x.shift_code, 2)::int AS si, x.heads
                FROM _home x JOIN _zone z USING (zone_id) WHERE x.dc_id = c.dc_id AND x.d = dd.d LOOP
        heads[zr.zi][zr.si] := zr.heads;
      END LOOP;
      FOR zr IN SELECT z.zi, substr(p.shift_code, 2)::int AS si, p.scheduled_headcount AS sc
                FROM wfm_static_labor_plan p JOIN _zone z USING (zone_id) WHERE p.dc_id = c.dc_id AND p.business_date = dd.d LOOP
        plan[zr.zi][zr.si] := zr.sc;
      END LOOP;
      eff := array_fill(0::float8, ARRAY[9]);  sg := array_fill(1::float8, ARRAY[9]);
      FOR i IN 1..9 LOOP eff[i] := 0.90 + random() * 0.08; END LOOP;
      sg[1] := dd.sg_in; sg[2] := dd.sg_in; sg[3] := dd.sg_rpl;
      sg[4] := dd.sg_ord; sg[5] := dd.sg_ord; sg[6] := dd.sg_ord; sg[7] := dd.sg_ord;
      sg[8] := dd.sg_ret; sg[9] := 1.0;
      live  := dd.phase IN ('ASSISTED','AUTO');
      pilot := (c.agent_cohort <> 'CONTROL') AND dd.phase <> 'BASELINE';
      learn := CASE WHEN dd.d >= date '2026-10-03' THEN 0.70 ELSE 0.45 END;

      FOR k IN 0..95 LOOP
        hr   := (6 + k / 4) % 24;
        sidx := 1 + k / 32;
        shc  := 'S' || sidx;
        ls   := (24 + k) % 96;
        its  := ((dd.d + time '06:00') + make_interval(mins => k * 15)) AT TIME ZONE c.tz;
        infl := array_fill(0::float8, ARRAY[9]); dn := array_fill(0::float8, ARRAY[9]);
        ex := array_fill(0::float8, ARRAY[9]);   act := array_fill(false, ARRAY[9]);
        h := array_fill(0::float8, ARRAY[9]);    hp := array_fill(0::float8, ARRAY[9]);
        FOR i IN 1..9 LOOP
          act[i] := position(shc IN shifts[i]) > 0;
          ex[i]  := c.design * volf[i] * dd.dowf * wn[i][hr + 1] / 4.0;
        END LOOP;

        -- headcount for this slot
        pool := 0;
        FOR i IN 1..9 LOOP IF act[i] THEN pool := pool + heads[i][sidx]; END IF; END LOOP;
        IF NOT live THEN
          FOR i IN 1..9 LOOP
            IF act[i] THEN h[i] := heads[i][sidx]; hp[i] := plan[i][sidx]; END IF;
          END LOOP;
        ELSE
          need := array_fill(0::float8, ARRAY[9]); lo := array_fill(0::float8, ARRAY[9]); hi := array_fill(0::float8, ARRAY[9]);
          FOR i IN 1..9 LOOP
            IF act[i] THEN
              estin := array_fill(0::float8, ARRAY[9]);
              estin[i] := CASE WHEN lastin[i] > 0 THEN 0.65 * lastin[i] + 0.35 * ex[i] * (1 + (sg[i] - 1) * learn)
                               ELSE ex[i] * (1 + (sg[i] - 1) * learn) END;
              need[i] := (q[i] + estin[i]) / (uph[i] * 0.25 * eff[i] * 0.88);
              lo[i] := floor(heads[i][sidx] * 0.65);
              hi[i] := least(maxhc[i], ceil(heads[i][sidx] * 1.35) + 1);
              h[i]  := least(hi[i], greatest(lo[i], need[i]));
              hp[i] := least(maxhc[i], greatest(minhc[i], ceil(ex[i] * (1 + (sg[i] - 1) * learn) / (uph[i] * 0.25 * 0.93 * 0.82))));
            END IF;
          END LOOP;
          s_d := 0; s_lo := 0;
          FOR i IN 1..9 LOOP IF act[i] THEN s_d := s_d + h[i]; s_lo := s_lo + lo[i]; END IF; END LOOP;
          IF s_d > pool THEN
            FOR i IN 1..9 LOOP
              IF act[i] THEN
                h[i] := CASE WHEN s_d > s_lo THEN lo[i] + (h[i] - lo[i]) * greatest(0, pool - s_lo) / (s_d - s_lo) ELSE lo[i] END;
              END IF;
            END LOOP;
          ELSIF s_d < pool THEN
            slack := pool - s_d; s_room := 0;
            FOR i IN 1..9 LOOP IF act[i] THEN s_room := s_room + (hi[i] - h[i]); END IF; END LOOP;
            IF s_room > 0 THEN
              FOR i IN 1..9 LOOP
                IF act[i] THEN h[i] := h[i] + least(slack, s_room) * (hi[i] - h[i]) / s_room; END IF;
              END LOOP;
            END IF;
          END IF;
          FOR i IN 1..9 LOOP IF act[i] THEN h[i] := round(h[i] * 2) / 2.0; END IF; END LOOP;
        END IF;

        -- work, queues and rows (upstream zones first)
        FOR i IN 1..9 LOOP
          CONTINUE WHEN NOT act[i];
          IF i IN (1,3,4,8,9) THEN
            spk := CASE WHEN i = 4 AND dd.spk_ord AND k BETWEEN dd.spk_ord_at AND dd.spk_ord_at + 7 THEN 1.40
                        WHEN i = 1 AND dd.spk_in  AND k BETWEEN dd.spk_in_at  AND dd.spk_in_at  + 5 THEN 1.80
                        ELSE 1 END;
            infl[i] := ex[i] * sg[i] * spk * (0.92 + 0.16 * random());
          ELSIF i = 2 THEN infl[i] := dn[1];
          ELSIF i = 5 THEN infl[i] := dn[4] * volf[5] / volf[4];
          ELSIF i = 6 THEN infl[i] := dn[5];
          ELSIF i = 7 THEN infl[i] := dn[6];
          END IF;
          wk  := q[i] + infl[i];
          cap := h[i] * uph[i] * 0.25 * eff[i] * (0.96 + 0.08 * random());
          dn[i] := least(wk, cap);
          qn  := wk - dn[i];
          util := CASE WHEN cap > 0 THEN least(1, dn[i] / cap) ELSE 0 END;
          ag := least(900, round(15 * qn / greatest(cap, 0.5) + 3 * random()))::int;
          IF pilot THEN
            fd := round(ex[i] * (1 + (sg[i] - 1) * learn) * (1 + (random() + random() + random() - 1.5) * 2 * 0.12))::int;
            fi := round(infl[i] * (1 + (random() + random() + random() - 1.5) * 2 * 0.06))::int;
          ELSE fd := NULL; fi := NULL; END IF;
          INSERT INTO wms_zone_interval(zone_id, interval_start, dc_id, business_date, local_slot, workload_in, workload_done,
                                        queue_depth, oldest_task_age_min, avg_task_age_min, hc_planned, hc_actual,
                                        direct_hours, idle_hours, fcst_dayahead, fcst_intraday, is_bottleneck)
          VALUES (zid[i], its, c.dc_id, dd.d, ls, round(infl[i])::int, round(dn[i])::int, round(qn)::int, ag, round(ag * 0.55)::int,
                  hp[i], h[i], round((h[i] * 0.25 * util * 0.94)::numeric, 3), round((h[i] * 0.25 * (1 - util) * 0.94)::numeric, 3),
                  fd, fi, ag > sla[i]);
          q[i] := qn; lastin[i] := infl[i];
        END LOOP;
      END LOOP;  -- slots
    END LOOP;    -- days
  END LOOP;      -- dcs
END
$seed$;

-- ---------------------------------------------------------------------
-- 6. Bottleneck episodes, alerts, recommendations, firefighting, moves
-- ---------------------------------------------------------------------
-- contiguous runs of bottlenecked 15-minute intervals per zone
CREATE TEMP TABLE _ep ON COMMIT DROP AS
SELECT row_number() OVER (ORDER BY e.dc_id, e.started_at, e.zone_id)::int AS episode_id,
       e.dc_id, e.zone_id, e.business_date, e.started_at, e.ended_at, e.duration_min, e.peak_queue, e.peak_age,
       ph.phase, z.zi, z.func, z.sla, z.tz, z.zone_code,
       random() AS r1, random() AS r2, random() AS r3, random() AS r4
FROM (SELECT dc_id, zone_id, min(business_date) AS business_date, min(interval_start) AS started_at,
             max(interval_start) + interval '15 minutes' AS ended_at, (count(*) * 15)::int AS duration_min,
             max(queue_depth) AS peak_queue, max(oldest_task_age_min)::int AS peak_age
      FROM (SELECT i.*, i.interval_start - row_number() OVER (PARTITION BY i.zone_id ORDER BY i.interval_start) * interval '15 minutes' AS grp
            FROM wms_zone_interval i WHERE i.is_bottleneck) x
      GROUP BY dc_id, zone_id, grp) e
JOIN _zone z ON z.zone_id = e.zone_id
JOIN _phase ph ON ph.dc_id = e.dc_id AND ph.d = e.business_date;

INSERT INTO ops_bottleneck_episode(episode_id, dc_id, zone_id, business_date, started_at, ended_at, duration_min, peak_queue,
                                   peak_oldest_age_min, root_cause, agent_mode, first_alert_id, alert_lead_min)
SELECT episode_id, dc_id, zone_id, business_date, started_at, ended_at, least(duration_min, 32000)::smallint, peak_queue,
       least(peak_age, 32000)::smallint,
       CASE WHEN zi = 1 AND r1 < 0.6 THEN 'LATE_TRUCK_BUNCHING'
            WHEN zi IN (5,6,7) AND r1 < 0.5 THEN 'UPSTREAM_SURGE'
            WHEN r1 < 0.45 THEN 'VOLUME_SPIKE' WHEN r1 < 0.70 THEN 'UNDERSTAFFED'
            WHEN r1 < 0.88 THEN 'ABSENTEEISM' ELSE 'EQUIPMENT_SLOWDOWN' END,
       phase, NULL, NULL
FROM _ep;

-- alerts: detected before the breach (true positives) plus some false positives, pilot DCs after shadow starts
CREATE TEMP TABLE _alx ON COMMIT DROP AS
WITH tp AS (
  SELECT e.episode_id, e.dc_id, e.zone_id, e.phase, e.tz, e.sla, e.zi, e.zone_code, e.started_at, e.ended_at, e.peak_queue, e.peak_age,
         (15 * (1 + floor(random() * 5)))::int AS lead, random() AS ra, random() AS rb, random() AS rc
  FROM _ep e JOIN dc ON dc.dc_id = e.dc_id
  WHERE dc.agent_cohort <> 'CONTROL' AND e.phase <> 'BASELINE' AND random() < CASE WHEN e.phase = 'SHADOW' THEN 0.60 ELSE 0.82 END),
fp AS (
  SELECT NULL::int AS episode_id, ph.dc_id, z.zone_id, ph.phase, z.tz, z.sla, z.zi, z.zone_code,
         ((ph.d + time '06:00') + make_interval(mins => 15 * (8 + floor(random() * 72))::int)) AT TIME ZONE z.tz AS started_at,
         NULL::timestamptz AS ended_at, (z.sla * 3)::int AS peak_queue, z.sla AS peak_age, 0 AS lead,
         random() AS ra, random() AS rb, random() AS rc
  FROM _phase ph JOIN dc ON dc.dc_id = ph.dc_id CROSS JOIN generate_series(1, 2) g
  JOIN LATERAL (SELECT * FROM _zone zz WHERE zz.dc_id = ph.dc_id AND zz.zi IN (1,4,5,6,7) ORDER BY random() LIMIT 1) z ON true
  WHERE dc.agent_cohort <> 'CONTROL' AND ph.phase <> 'BASELINE' AND random() < 0.80)
SELECT row_number() OVER (ORDER BY started_at - make_interval(mins => lead), zone_id)::int AS alert_id, u.*,
       (started_at - make_interval(mins => lead)) AS detected_at
FROM (SELECT * FROM tp UNION ALL SELECT * FROM fp) u;

ALTER TABLE _alx ADD COLUMN bd date, ADD COLUMN shc text;
UPDATE _alx SET bd = ((detected_at AT TIME ZONE tz) - interval '6 hours')::date,
                shc = CASE WHEN extract(hour FROM detected_at AT TIME ZONE tz) BETWEEN 6 AND 13 THEN 'S1'
                           WHEN extract(hour FROM detected_at AT TIME ZONE tz) BETWEEN 14 AND 21 THEN 'S2' ELSE 'S3' END;
DELETE FROM _alx WHERE bd < date '2026-09-26' OR bd > date '2026-10-09';

INSERT INTO agent_bottleneck_alert(alert_id, dc_id, zone_id, detected_at, agent_mode, model_version_id, signal_type, severity,
                                   queue_depth, queue_growth_pct_per_hr, oldest_task_age_min, throughput_trend_pct,
                                   projected_wait_min, projected_breach_at, lead_time_min, projected_units_at_risk, cutoff_id,
                                   probable_cause, status, closed_at, episode_id)
SELECT a.alert_id, a.dc_id, a.zone_id, a.detected_at, a.phase, 3,
       CASE WHEN a.ra < 0.40 THEN 'QUEUE_GROWTH' WHEN a.ra < 0.75 THEN 'TASK_AGING' ELSE 'THROUGHPUT_DROP' END,
       CASE WHEN a.episode_id IS NULL THEN (CASE WHEN a.rb < 0.6 THEN 'LOW' ELSE 'MEDIUM' END)
            WHEN a.peak_age::numeric / a.sla > 2.5 THEN 'CRITICAL' WHEN a.peak_age::numeric / a.sla > 1.6 THEN 'HIGH'
            WHEN a.peak_age::numeric / a.sla > 1.2 THEN 'MEDIUM' ELSE 'LOW' END,
       greatest(1, round(a.peak_queue * 0.45))::int, round((25 + a.rb * 90)::numeric, 1)::real,
       greatest(1, round(a.sla * (0.6 + a.rc * 0.3)))::smallint, round((-5 - a.rc * 30)::numeric, 1)::real,
       round(a.sla * (1.3 + a.rb))::smallint, a.started_at, a.lead::smallint, round(a.peak_queue * 0.8)::int,
       CASE WHEN a.zi BETWEEN 4 AND 7 THEN
            (SELECT c.cutoff_id FROM carrier_cutoff c WHERE c.dc_id = a.dc_id
              AND c.pull_time > (a.started_at AT TIME ZONE a.tz)::time ORDER BY c.pull_time LIMIT 1) END,
       CASE WHEN a.episode_id IS NULL THEN 'Pattern resembled a past bottleneck but volume normalised'
            ELSE (SELECT oe.root_cause FROM ops_bottleneck_episode oe WHERE oe.episode_id = a.episode_id) END,
       CASE WHEN a.episode_id IS NULL THEN 'FALSE_POSITIVE'
            WHEN a.phase = 'SHADOW' THEN 'BREACHED'
            WHEN a.rb < 0.58 THEN 'MITIGATED' ELSE 'BREACHED' END,
       CASE WHEN a.episode_id IS NULL THEN a.started_at + interval '45 minutes' ELSE a.ended_at END,
       a.episode_id
FROM _alx a;

UPDATE ops_bottleneck_episode e
SET first_alert_id = x.alert_id, alert_lead_min = x.lead::smallint
FROM (SELECT DISTINCT ON (episode_id) episode_id, alert_id, lead FROM _alx WHERE episode_id IS NOT NULL ORDER BY episode_id, detected_at) x
WHERE e.episode_id = x.episode_id;

-- associates on the clock who hold the target zone's skill (candidates to move)
CREATE TEMP TABLE _cand ON COMMIT DROP AS
SELECT DISTINCT ON (al.alert_id) al.alert_id, a.associate_id, a.home_zone_id, s.proficiency, tt.walk_minutes
FROM _alx al
JOIN _zone tz ON tz.zone_id = al.zone_id
JOIN wfm_timecard t ON t.dc_id = al.dc_id AND t.business_date = al.bd AND t.shift_code = al.shc AND t.clock_in IS NOT NULL
JOIN associate a ON a.associate_id = t.associate_id AND a.home_zone_id <> al.zone_id
JOIN associate_skill s ON s.associate_id = a.associate_id AND s.skill_code = tz.skill
 AND s.proficiency >= CASE WHEN tz.pit THEN 2 ELSE 1 END AND s.certified_on <= al.bd AND (s.expires_on IS NULL OR s.expires_on >= al.bd)
LEFT JOIN zone_travel_time tt ON tt.from_zone_id = a.home_zone_id AND tt.to_zone_id = al.zone_id
WHERE NOT ('LIFT_25LB' = ANY (COALESCE(a.restrictions, '{}')) AND tz.zi IN (1,7))
ORDER BY al.alert_id, random();

-- recommendations: reallocations / voluntary extra time from alerts, plus cross-training and VTO offers
CREATE TEMP TABLE _rc ON COMMIT DROP AS
WITH base AS (
  SELECT al.dc_id, al.alert_id, al.detected_at + make_interval(mins => 1 + floor(random() * 3)::int) AS created_at,
         al.phase, al.zone_id AS to_zone, al.zone_code AS to_code, al.sla, al.bd, al.shc, al.tz, al.peak_queue, al.peak_age,
         al.episode_id,
         CASE WHEN c.associate_id IS NOT NULL AND random() < 0.85 THEN 'REALLOCATE' ELSE 'VET_OFFER' END AS rec_type,
         c.associate_id, c.home_zone_id AS from_zone, c.proficiency, c.walk_minutes,
         CASE WHEN al.episode_id IS NULL THEN 'MEDIUM' WHEN al.peak_age::numeric / al.sla > 1.6 THEN 'HIGH'
              WHEN al.peak_age::numeric / al.sla > 1.2 THEN 'MEDIUM' ELSE 'LOW' END AS priority,
         random() AS r1, random() AS r2, random() AS r3
  FROM _alx al LEFT JOIN _cand c USING (alert_id)
  WHERE random() < 0.9),
xt AS (
  SELECT ph.dc_id, NULL::int AS alert_id, ((ph.d + time '17:00') AT TIME ZONE z.tz) AS created_at, ph.phase, z.zone_id AS to_zone,
         z.zone_code AS to_code, z.sla, ph.d AS bd, 'S2'::text AS shc, z.tz, 0 AS peak_queue, 0 AS peak_age, NULL::int AS episode_id,
         'CROSS_TRAIN'::text AS rec_type, a.associate_id, NULL::smallint AS from_zone, 2::smallint AS proficiency, NULL::real AS walk_minutes,
         'MEDIUM'::text AS priority, random() AS r1, random() AS r2, random() AS r3
  FROM _phase ph JOIN dc ON dc.dc_id = ph.dc_id
  JOIN LATERAL (SELECT * FROM _zone zz WHERE zz.dc_id = ph.dc_id AND zz.zi IN (5,6,7,8,9) ORDER BY random() LIMIT 1) z ON true
  JOIN LATERAL (SELECT x.associate_id FROM associate x
                WHERE x.dc_id = ph.dc_id AND x.is_flex_pool AND x.status = 'ACTIVE' AND x.employment_type <> 'TEMP'
                  AND NOT EXISTS (SELECT 1 FROM associate_skill s WHERE s.associate_id = x.associate_id AND s.skill_code = z.skill)
                ORDER BY random() LIMIT 1) a ON true
  WHERE dc.agent_cohort <> 'CONTROL' AND ph.phase <> 'BASELINE' AND random() < 0.40),
vto AS (
  SELECT ph.dc_id, NULL::int, ((ph.d + time '13:30') AT TIME ZONE z.tz), ph.phase, z.zone_id, z.zone_code, z.sla, ph.d, 'S1'::text,
         z.tz, 0, 0, NULL::int, 'VTO_OFFER'::text, NULL::int, z.zone_id::smallint, NULL::smallint, NULL::real, 'LOW'::text,
         random(), random(), random()
  FROM _phase ph JOIN dc ON dc.dc_id = ph.dc_id
  JOIN LATERAL (SELECT * FROM _zone zz WHERE zz.dc_id = ph.dc_id AND zz.zi IN (3,8,9) ORDER BY random() LIMIT 1) z ON true
  WHERE dc.agent_cohort <> 'CONTROL' AND ph.phase IN ('ASSISTED','AUTO') AND random() < 0.5)
SELECT row_number() OVER (ORDER BY created_at, dc_id, to_zone)::int AS rec_id, u.*
FROM (SELECT * FROM base UNION ALL SELECT * FROM xt UNION ALL SELECT * FROM vto) u
WHERE u.bd BETWEEN date '2026-09-26' AND date '2026-10-09';

INSERT INTO agent_recommendation(rec_id, dc_id, alert_id, created_at, agent_mode, model_version_id, rec_type, priority, from_zone_id,
        to_zone_id, headcount, skill_code, window_start, window_end, expected_workload_gain, expected_aging_reduction_min,
        expected_sla_units_protected, expected_benefit_usd, expected_cost_usd, confidence, hard_constraints_checked,
        soft_constraints_flagged, rationale, status, decided_by_supervisor_id, decided_at, rejection_reason)
SELECT r.rec_id, r.dc_id, r.alert_id, r.created_at, r.phase,
       CASE WHEN r.created_at >= timestamptz '2026-10-03 00:00+00' THEN 5 ELSE 4 END,
       r.rec_type, r.priority,
       CASE WHEN r.rec_type = 'REALLOCATE' THEN r.from_zone END,
       r.to_zone,
       CASE WHEN r.rec_type = 'VET_OFFER' THEN 2 WHEN r.rec_type = 'VTO_OFFER' THEN 2 ELSE 1 END,
       CASE WHEN r.rec_type IN ('REALLOCATE','CROSS_TRAIN') THEN z.skill END,
       CASE WHEN r.rec_type IN ('REALLOCATE','VET_OFFER') THEN r.created_at + interval '5 minutes' END,
       CASE WHEN r.rec_type IN ('REALLOCATE','VET_OFFER') THEN r.created_at + interval '95 minutes' END,
       CASE WHEN r.rec_type IN ('REALLOCATE','VET_OFFER') THEN round(z.uph * 0.8 * CASE WHEN r.rec_type = 'VET_OFFER' THEN 2 ELSE 1 END)::int END,
       CASE WHEN r.rec_type IN ('REALLOCATE','VET_OFFER') THEN (6 + floor(r.r1 * 20))::smallint END,
       CASE WHEN r.rec_type IN ('REALLOCATE','VET_OFFER') THEN round(z.uph * 0.5)::int END,
       CASE WHEN r.rec_type IN ('REALLOCATE','VET_OFFER') THEN round(z.uph * 0.5 * 2.1)::real
            WHEN r.rec_type = 'CROSS_TRAIN' THEN 180::real WHEN r.rec_type = 'VTO_OFFER' THEN 0::real END,
       CASE WHEN r.rec_type = 'REALLOCATE' THEN 24::real WHEN r.rec_type = 'VET_OFFER' THEN 96::real
            WHEN r.rec_type = 'CROSS_TRAIN' THEN 120::real ELSE 0::real END,
       round((0.55 + r.r2 * 0.40)::numeric, 3)::real, 7,
       CASE WHEN r.walk_minutes > 4 THEN ARRAY['MIN_TRAVEL'] WHEN r.r3 < 0.1 THEN ARRAY['SPREAD_MOVES'] END,
       CASE r.rec_type
         WHEN 'REALLOCATE' THEN format('Move 1 associate from %s to %s. Queue is about %s units and the oldest task is heading past the %s min aging SLA. The associate holds proficiency %s in %s; walk time %s min.',
                                       (SELECT zone_code FROM _zone WHERE zone_id = r.from_zone), r.to_code, r.peak_queue, r.sla, r.proficiency, z.skill, COALESCE(r.walk_minutes::text, 'n/a'))
         WHEN 'VET_OFFER'  THEN format('Offer voluntary extra time to 2 associates already in %s. Queue is growing and no qualified associate is free to move.', r.to_code)
         WHEN 'CROSS_TRAIN' THEN format('Cross-train 1 flex-pool associate on %s. %s has a thin qualified bench and depends on a few people.', z.skill, r.to_code)
         ELSE format('Offer voluntary time off to 2 associates in %s. Forecast workload is below the static plan for the rest of the shift.', r.to_code) END,
       CASE WHEN r.phase = 'SHADOW' THEN 'SHADOW_LOGGED'
            WHEN r.phase = 'AUTO' AND r.rec_type = 'REALLOCATE' AND r.r2 > 0.55 AND r.r1 < 0.75 THEN 'AUTO_EXECUTED'
            WHEN r.r3 < 0.62 THEN 'ACCEPTED' WHEN r.r3 < 0.80 THEN 'REJECTED' ELSE 'EXPIRED' END,
       NULL, NULL, NULL
FROM _rc r JOIN _zone z ON z.zone_id = r.to_zone;

-- supervisor decisions
UPDATE agent_recommendation r
SET decided_by_supervisor_id = (SELECT s.supervisor_id FROM ops_supervisor s
                                WHERE s.dc_id = r.dc_id AND s.shift_code = c.shc ORDER BY random() LIMIT 1),
    decided_at = r.created_at + make_interval(mins => 2 + floor(random() * 5)::int),
    rejection_reason = CASE WHEN r.status = 'REJECTED' THEN
         (ARRAY['Associate needed in home zone','Skill not recent enough','Walk time too long','Supervisor prefers ad-hoc fix',
                'Union rotation fairness','Bottleneck clearing on its own'])[1 + floor(random() * 6)::int] END
FROM _rc c
WHERE c.rec_id = r.rec_id AND r.status IN ('ACCEPTED','REJECTED');

-- evaluation of every executed recommendation
INSERT INTO agent_outcome(rec_id, evaluated_at, actual_workload_gain, actual_aging_reduction_min, actual_sla_units_protected,
                          realized_benefit_usd, realized_cost_usd, outcome_label, reward, learning_note)
SELECT t.rec_id, t.window_end + interval '30 minutes',
       round(COALESCE(t.expected_workload_gain, 0) * t.ratio)::int,
       round(COALESCE(t.expected_aging_reduction_min, 0) * t.ratio)::smallint,
       round(COALESCE(t.expected_sla_units_protected, 0) * t.ratio)::int,
       (COALESCE(t.expected_benefit_usd, 0) * t.ratio)::real,
       (COALESCE(t.expected_cost_usd, 0) * (0.9 + 0.2 * t.ratio))::real,
       CASE WHEN t.ratio >= 0.80 THEN 'EFFECTIVE' WHEN t.ratio >= 0.50 THEN 'PARTIALLY_EFFECTIVE'
            WHEN t.ratio >= 0.25 THEN 'INEFFECTIVE' ELSE 'ADVERSE' END,
       least(1, greatest(-1, (t.ratio - 0.5) * 1.6))::real,
       CASE WHEN t.ratio >= 0.80 THEN 'Move cleared the queue as predicted; keep weighting skill and walk time.'
            WHEN t.ratio >= 0.50 THEN 'Partial relief; the donor zone slowed more than expected.'
            ELSE 'Little effect; raise the minimum proficiency for this zone.' END
FROM (SELECT r.*, (0.20 + random() * 1.0) AS ratio FROM agent_recommendation r
      WHERE r.status IN ('ACCEPTED','AUTO_EXECUTED') AND r.rec_type IN ('REALLOCATE','VET_OFFER')) t
WHERE t.window_end IS NOT NULL;

-- accepted cross-training recommendations become skills
INSERT INTO associate_skill(associate_id, skill_code, proficiency, certified_on, expires_on, source, recommended_by_rec_id)
SELECT c.associate_id, r.skill_code, 2, least(date '2026-10-10', c.bd + 3 + floor(random() * 4)::int), NULL, 'AGENT_CROSS_TRAIN', r.rec_id
FROM agent_recommendation r JOIN _rc c USING (rec_id)
WHERE r.rec_type = 'CROSS_TRAIN' AND r.status IN ('ACCEPTED','AUTO_EXECUTED') AND c.associate_id IS NOT NULL
ON CONFLICT (associate_id, skill_code) DO NOTHING;

-- firefighting: reactive supervisor interventions (far more common on static-plan days)
CREATE TEMP TABLE _ff ON COMMIT DROP AS
SELECT row_number() OVER (ORDER BY occurred_at, episode_id)::int AS event_id, q.*
FROM (SELECT e.episode_id, e.dc_id, e.zone_id, e.zi, e.func, e.zone_code, e.tz, e.phase,
             e.started_at + make_interval(mins => 5 + floor(e.r2 * 20)::int) AS occurred_at,
             CASE WHEN e.func IN ('SHIP','SORT','PACK') AND e.r3 > 0.78 THEN 'CARRIER_HOLD'
                  WHEN e.r3 < 0.50 THEN 'ADHOC_REASSIGN' WHEN e.r3 < 0.75 THEN 'MANDATORY_OT' ELSE 'ESCALATION' END AS event_type,
             e.r2, e.r3, e.r4, e.peak_age
      FROM _ep e
      WHERE e.r4 < CASE WHEN e.phase IN ('ASSISTED','AUTO') THEN 0.25 ELSE 0.85 END) q;

INSERT INTO ops_firefighting_event(event_id, dc_id, zone_id, occurred_at, event_type, trigger, associates_affected,
                                   supervisor_minutes, added_cost_usd, supervisor_id, episode_id, notes)
SELECT f.event_id, f.dc_id, f.zone_id, f.occurred_at, f.event_type,
       format('%s exceeded its aging SLA (oldest task %s min)', f.zone_code, f.peak_age),
       CASE f.event_type WHEN 'ADHOC_REASSIGN' THEN 1 + floor(f.r2 * 3) WHEN 'MANDATORY_OT' THEN 4 + floor(f.r2 * 7) ELSE 0 END::smallint,
       (CASE WHEN f.phase IN ('ASSISTED','AUTO') THEN 8 + floor(f.r3 * 15) ELSE 15 + floor(f.r3 * 35) END)::smallint,
       (CASE f.event_type WHEN 'MANDATORY_OT' THEN (4 + floor(f.r2 * 7)) * 2 * 27 WHEN 'CARRIER_HOLD' THEN 450 + f.r2 * 900
                          WHEN 'ADHOC_REASSIGN' THEN 60 ELSE 0 END)::real,
       (SELECT s.supervisor_id FROM ops_supervisor s WHERE s.dc_id = f.dc_id
          AND s.shift_code = CASE WHEN extract(hour FROM f.occurred_at AT TIME ZONE f.tz) BETWEEN 6 AND 13 THEN 'S1'
                                  WHEN extract(hour FROM f.occurred_at AT TIME ZONE f.tz) BETWEEN 14 AND 21 THEN 'S2' ELSE 'S3' END
        ORDER BY random() LIMIT 1),
       f.episode_id,
       CASE f.event_type WHEN 'ESCALATION' THEN 'Escalated to area manager' WHEN 'CARRIER_HOLD' THEN 'Asked carrier to hold the trailer' END
FROM _ff f;

-- labor moves: agent recommendations executed, ad-hoc supervisor moves, scheduled playbook moves
CREATE TEMP TABLE _mv ON COMMIT DROP AS
SELECT m.*, row_number() OVER (ORDER BY m.requested_at, m.associate_id)::int AS move_id
FROM (
  -- executed agent reallocations
  SELECT c.dc_id, c.bd AS business_date, c.associate_id, c.from_zone::smallint AS from_zone_id, c.to_zone::smallint AS to_zone_id,
         CASE WHEN r.status = 'AUTO_EXECUTED' THEN 'AGENT_AUTO' ELSE 'AGENT_ASSISTED' END AS move_source,
         r.rec_id, NULL::int AS firefight_event_id, r.created_at + interval '3 minutes' AS requested_at,
         r.created_at + interval '6 minutes' AS started_at, r.window_end AS ended_at,
         COALESCE(c.walk_minutes, 4.0)::real AS travel_min, c.proficiency::smallint AS target_skill_proficiency,
         (z.uph * 0.85)::real AS est_workload_done
  FROM agent_recommendation r JOIN _rc c USING (rec_id) JOIN _zone z ON z.zone_id = c.to_zone
  WHERE r.rec_type = 'REALLOCATE' AND r.status IN ('ACCEPTED','AUTO_EXECUTED') AND c.associate_id IS NOT NULL
  UNION ALL
  -- supervisor ad-hoc reassignments (any associate on the clock, skill often missing)
  SELECT g.dc_id, g.bd, g.associate_id, g.home_zone_id::smallint, g.zone_id::smallint, 'SUPERVISOR_ADHOC', NULL::int, g.event_id,
         g.occurred_at, g.occurred_at + interval '5 minutes', g.occurred_at + interval '95 minutes',
         round((COALESCE(g.walk_minutes, 5.0) * 1.6)::numeric, 1)::real, g.proficiency::smallint, (g.uph * 0.55)::real
  FROM (SELECT DISTINCT ON (f.event_id) f.event_id, f.dc_id, f.zone_id, f.occurred_at, a.associate_id, a.home_zone_id,
               ((f.occurred_at AT TIME ZONE f.tz) - interval '6 hours')::date AS bd, tt.walk_minutes, s.proficiency, z.uph
        FROM _ff f JOIN _zone z ON z.zone_id = f.zone_id
        JOIN wfm_timecard t ON t.dc_id = f.dc_id AND t.business_date = ((f.occurred_at AT TIME ZONE f.tz) - interval '6 hours')::date
         AND t.shift_code = CASE WHEN extract(hour FROM f.occurred_at AT TIME ZONE f.tz) BETWEEN 6 AND 13 THEN 'S1'
                                 WHEN extract(hour FROM f.occurred_at AT TIME ZONE f.tz) BETWEEN 14 AND 21 THEN 'S2' ELSE 'S3' END
         AND t.clock_in IS NOT NULL
        JOIN associate a ON a.associate_id = t.associate_id AND a.home_zone_id <> f.zone_id
        LEFT JOIN zone_travel_time tt ON tt.from_zone_id = a.home_zone_id AND tt.to_zone_id = f.zone_id
        LEFT JOIN associate_skill s ON s.associate_id = a.associate_id AND s.skill_code = z.skill
        WHERE f.event_type = 'ADHOC_REASSIGN'
        ORDER BY f.event_id, random()) g
  UNION ALL
  -- playbook moves at the start of each shift on agent-live days
  SELECT p.dc_id, p.d, p.associate_id, p.home_zone_id::smallint, p.zone_id::smallint, 'PLAYBOOK', NULL::int, NULL::int,
         p.t0 - interval '10 minutes', p.t0, p.t0 + interval '120 minutes', COALESCE(p.walk_minutes, 4.0)::real,
         p.proficiency::smallint, (p.uph * 1.5)::real
  FROM (SELECT DISTINCT ON (ph.dc_id, ph.d, sh.shc) ph.dc_id, ph.d, sh.shc, a.associate_id, a.home_zone_id, tz.zone_id, tt.walk_minutes,
               s.proficiency, tz.uph, ((ph.d + sh.st + interval '60 minutes') AT TIME ZONE dc.timezone) AS t0
        FROM _phase ph JOIN dc ON dc.dc_id = ph.dc_id
        CROSS JOIN (VALUES ('S1', time '06:00'), ('S2', time '14:00')) sh(shc, st)
        JOIN _zone tz ON tz.dc_id = ph.dc_id AND tz.zi IN (4,5)
        JOIN wfm_timecard t ON t.dc_id = ph.dc_id AND t.business_date = ph.d AND t.shift_code = sh.shc AND t.clock_in IS NOT NULL
        JOIN associate a ON a.associate_id = t.associate_id AND a.home_zone_id <> tz.zone_id AND a.is_flex_pool
        JOIN associate_skill s ON s.associate_id = a.associate_id AND s.skill_code = tz.skill AND s.proficiency >= 2
         AND s.certified_on <= ph.d AND (s.expires_on IS NULL OR s.expires_on >= ph.d)
        LEFT JOIN zone_travel_time tt ON tt.from_zone_id = a.home_zone_id AND tt.to_zone_id = tz.zone_id
        WHERE ph.phase IN ('ASSISTED','AUTO') AND NOT ('LIFT_25LB' = ANY (COALESCE(a.restrictions, '{}')) AND tz.zi IN (1,7))
        ORDER BY ph.dc_id, ph.d, sh.shc, random()) p
) m;

INSERT INTO ops_labor_move(move_id, dc_id, business_date, associate_id, from_zone_id, to_zone_id, move_source, rec_id,
                           firefight_event_id, requested_at, started_at, ended_at, travel_min, target_skill_proficiency, est_workload_done)
SELECT move_id, dc_id, business_date, associate_id, from_zone_id, to_zone_id, move_source, rec_id, firefight_event_id,
       requested_at, started_at, ended_at, travel_min, target_skill_proficiency, est_workload_done
FROM _mv;

-- ---------------------------------------------------------------------
-- 7. LMS performance, inbound appointments, downtime, carrier cutoffs
-- ---------------------------------------------------------------------
CREATE TEMP TABLE _zutil ON COMMIT DROP AS
SELECT zone_id, business_date, sum(direct_hours) / NULLIF(sum(direct_hours + idle_hours), 0) AS util
FROM wms_zone_interval GROUP BY zone_id, business_date;

CREATE TEMP TABLE _mvh ON COMMIT DROP AS
SELECT DISTINCT ON (associate_id, business_date, to_zone_id)
       associate_id, business_date, to_zone_id AS zone_id, dc_id, extract(epoch FROM (ended_at - started_at)) / 3600.0 AS hrs
FROM _mv ORDER BY associate_id, business_date, to_zone_id, requested_at;

INSERT INTO lms_associate_daily(associate_id, business_date, zone_id, dc_id, direct_hours, indirect_hours, idle_hours,
                                workload_done, earned_hours, pct_to_standard, reallocated_in)
SELECT x.associate_id, x.business_date, x.home_zone_id, x.dc_id,
       round(x.dh::numeric, 3)::real, round((x.hh * 0.06)::numeric, 3)::real, round(x.ih::numeric, 3)::real,
       round(x.wd::numeric, 2)::real, round((x.wd / x.uph)::numeric, 3)::real,
       CASE WHEN x.dh > 0 THEN round((x.wd / x.uph / x.dh)::numeric, 4)::real END, false
FROM (SELECT t.associate_id, t.business_date, t.home_zone_id, t.dc_id, z.uph, hh.hh,
             hh.hh * 0.94 * COALESCE(u.util, 0.7) AS dh, hh.hh * 0.94 * (1 - COALESCE(u.util, 0.7)) AS ih,
             hh.hh * 0.94 * COALESCE(u.util, 0.7) * z.uph * a.base_performance * (0.94 + 0.12 * random()) AS wd
      FROM wfm_timecard t
      JOIN associate a ON a.associate_id = t.associate_id
      JOIN _zone z ON z.zone_id = t.home_zone_id
      LEFT JOIN _zutil u ON u.zone_id = t.home_zone_id AND u.business_date = t.business_date
      CROSS JOIN LATERAL (SELECT greatest(0, t.regular_hours + t.overtime_hours
                                  - COALESCE((SELECT sum(m.hrs) FROM _mvh m WHERE m.associate_id = t.associate_id AND m.business_date = t.business_date), 0)) AS hh) hh
      WHERE t.clock_in IS NOT NULL) x;

INSERT INTO lms_associate_daily(associate_id, business_date, zone_id, dc_id, direct_hours, indirect_hours, idle_hours,
                                workload_done, earned_hours, pct_to_standard, reallocated_in)
SELECT m.associate_id, m.business_date, m.zone_id, m.dc_id,
       round((m.hrs * 0.85)::numeric, 3)::real, round((m.hrs * 0.05)::numeric, 3)::real, round((m.hrs * 0.10)::numeric, 3)::real,
       round((m.hrs * 0.85 * z.uph * a.base_performance * 0.92)::numeric, 2)::real,
       round((m.hrs * 0.85 * a.base_performance * 0.92)::numeric, 3)::real,
       round((a.base_performance * 0.92)::numeric, 4)::real, true
FROM _mvh m JOIN _zone z ON z.zone_id = m.zone_id JOIN associate a ON a.associate_id = m.associate_id;

INSERT INTO wms_inbound_appointment(appt_id, dc_id, appt_number, vendor, load_type, scheduled_at, arrived_at, door, cartons,
                                    pallets, status, lateness_min)
SELECT row_number() OVER (ORDER BY x.dc_id, x.sched)::int, x.dc_id,
       'A' || x.dc_id || '-' || to_char(x.d, 'MMDD') || '-' || lpad(x.g::text, 2, '0'),
       (ARRAY['Summit Apparel','Harbor Home Goods','Pinecrest Electronics','Redwood Toys','Lakeside Beauty','Granite Sports','Willow Kitchenware','Cobalt Accessories'])[1 + floor(x.r5 * 8)::int],
       (ARRAY['FLOOR_LOADED','PALLETIZED','LTL'])[1 + floor(x.r6 * 3)::int],
       x.sched,
       CASE WHEN x.r3 < 0.03 THEN NULL ELSE x.sched + make_interval(mins => x.late) END,
       (1 + floor(x.r4 * x.inbound_doors))::smallint,
       round((300 + x.r1 * 1800) * x.design / 15000.0)::int,
       round((300 + x.r1 * 1800) * x.design / 15000.0 / 45)::smallint,
       CASE WHEN x.r3 < 0.03 THEN 'NO_SHOW' WHEN x.late > 30 THEN 'LATE' ELSE 'ON_TIME' END,
       CASE WHEN x.r3 < 0.03 THEN NULL ELSE x.late::smallint END
FROM (SELECT dc.dc_id, dc.inbound_doors, dc.design_daily_volume AS design, dy.d, g,
             ((dy.d + time '06:00' + make_interval(mins => 15 * floor(random() * 64)::int)) AT TIME ZONE dc.timezone) AS sched,
             random() AS r1, round((random() * random()) * 150 - 15)::int AS late, random() AS r3, random() AS r4, random() AS r5, random() AS r6
      FROM dc CROSS JOIN _day dy CROSS JOIN generate_series(1, 14) g
      WHERE g <= round(10 * dy.dowf)) x;

INSERT INTO wms_equipment_downtime(event_id, dc_id, zone_id, equipment, cause, started_at, ended_at, capacity_loss_pct)
SELECT row_number() OVER (ORDER BY x.dc_id, x.st)::int, x.dc_id, x.zone_id,
       (ARRAY['Dock conveyor','Reach truck fleet','Forklift fleet','Order picker fleet','Sorter'])[CASE x.zi WHEN 1 THEN 1 WHEN 2 THEN 2 WHEN 3 THEN 3 WHEN 4 THEN 4 ELSE 5 END],
       (ARRAY['Mechanical fault','Battery failure','Sensor fault','Scheduled maintenance','Jam'])[1 + floor(x.r2 * 5)::int],
       x.st, x.st + make_interval(mins => 20 + floor(x.r3 * 160)::int), (15 + floor(x.r4 * 45))::smallint
FROM (SELECT z.dc_id, z.zone_id, z.zi,
             ((dy.d + time '06:00' + make_interval(mins => 15 * floor(random() * 76)::int)) AT TIME ZONE z.tz) AS st,
             random() AS r2, random() AS r3, random() AS r4
      FROM _zone z CROSS JOIN _day dy WHERE z.zi IN (1,2,3,4,6) AND random() < 0.03) x;

CREATE TEMP TABLE _bnf ON COMMIT DROP AS
SELECT dc_id, business_date AS d, avg(is_bottleneck::int) AS frac
FROM wms_zone_interval WHERE zone_id % 10 IN (5,6,7) GROUP BY dc_id, business_date;

INSERT INTO ops_cutoff_performance(dc_id, business_date, cutoff_id, pull_at, units_due, units_on_time, units_missed, backlog_at_pull, miss_cost_usd)
SELECT x.dc_id, x.d, x.cutoff_id, x.pull_at, x.due, x.due - x.missed, x.missed, x.missed + round(x.due * 0.02 * x.r2)::int,
       (x.missed * x.miss_cost_per_unit)::real
FROM (SELECT c.dc_id, dd.d, c.cutoff_id, c.miss_cost_per_unit, ((dd.d + c.pull_time) AT TIME ZONE dc.timezone) AS pull_at, random() AS r2,
             due.due,
             round(due.due * least(0.35, (CASE WHEN dd.phase IN ('ASSISTED','AUTO') THEN 0.014 ELSE 0.034 END)
                                          + 0.35 * COALESCE(b.frac, 0) + 0.01 * random()))::int AS missed
      FROM carrier_cutoff c JOIN dc ON dc.dc_id = c.dc_id
      JOIN _dcday dd ON dd.dc_id = c.dc_id
      LEFT JOIN _bnf b ON b.dc_id = c.dc_id AND b.d = dd.d
      CROSS JOIN LATERAL (SELECT round(dc.design_daily_volume * dd.dowf * (CASE c.cutoff_id % 10 WHEN 1 THEN 0.28 WHEN 2 THEN 0.37 ELSE 0.35 END)
                                       * (0.97 + 0.06 * random()))::int AS due) due) x;

-- ---------------------------------------------------------------------
-- 8. Forecasts and daily playbooks (pilot DCs once the agent runs in shadow)
-- ---------------------------------------------------------------------
INSERT INTO agent_workload_forecast(zone_id, interval_start, dc_id, business_date, local_slot, generated_at, model_version_id,
                                    fcst_p10, fcst_p50, fcst_p90, required_hc_p50)
SELECT i.zone_id, i.interval_start, i.dc_id, i.business_date, i.local_slot,
       ((i.business_date - 1) + time '18:00') AT TIME ZONE dc.timezone,
       CASE WHEN i.business_date >= date '2026-10-03' THEN 2 ELSE 1 END,
       round(i.fcst_dayahead * 0.80)::int, i.fcst_dayahead, round(i.fcst_dayahead * 1.25)::int,
       (i.fcst_dayahead / (z.uph * 0.25 * 0.93 * 0.85))::real
FROM wms_zone_interval i JOIN dc ON dc.dc_id = i.dc_id JOIN _zone z ON z.zone_id = i.zone_id
WHERE i.fcst_dayahead IS NOT NULL;

CREATE TEMP TABLE _pb ON COMMIT DROP AS
SELECT row_number() OVER (ORDER BY ph.d, ph.dc_id)::int AS playbook_id, ph.dc_id, ph.d, ph.phase, dc.timezone AS tz
FROM _phase ph JOIN dc ON dc.dc_id = ph.dc_id
WHERE dc.agent_cohort <> 'CONTROL' AND ph.phase <> 'BASELINE';

INSERT INTO agent_playbook(playbook_id, dc_id, business_date, generated_at, model_version_id, agent_mode, status,
                           acknowledged_by_supervisor_id, fcst_volume, fcst_volume_p10, fcst_volume_p90, actual_volume,
                           static_plan_hours, recommended_hours, recommended_vet_hours, recommended_vto_hours, risk_windows, narrative)
SELECT pb.playbook_id, pb.dc_id, pb.d, ((pb.d - 1) + time '18:00') AT TIME ZONE pb.tz,
       CASE WHEN pb.d >= date '2026-10-03' THEN 2 ELSE 1 END, pb.phase,
       CASE WHEN pb.phase = 'SHADOW' THEN 'SHADOW' WHEN s.ack THEN 'ACKNOWLEDGED' ELSE 'PUBLISHED' END,
       CASE WHEN pb.phase <> 'SHADOW' AND s.ack THEN
            (SELECT sv.supervisor_id FROM ops_supervisor sv WHERE sv.dc_id = pb.dc_id AND sv.shift_code = 'S1' ORDER BY sv.supervisor_id LIMIT 1) END,
       v.fcst, round(v.fcst * 0.88)::int, round(v.fcst * 1.13)::int, v.act,
       p.plan_hours::real, (p.plan_hours * CASE WHEN pb.phase IN ('ASSISTED','AUTO') THEN 0.96 ELSE 1.0 END)::real,
       (CASE WHEN pb.phase IN ('ASSISTED','AUTO') THEN 12 + floor(s.r * 18) ELSE 0 END)::real,
       (CASE WHEN pb.phase IN ('ASSISTED','AUTO') THEN 8 + floor(s.r * 16) ELSE 0 END)::real,
       (SELECT jsonb_agg(jsonb_build_object('zone', t.zc, 'local_hour', t.hh, 'reason', 'Forecast demand above the static plan'))
          FROM (SELECT z.zone_code AS zc, (i.local_slot / 4) AS hh
                FROM wms_zone_interval i JOIN _zone z ON z.zone_id = i.zone_id
                WHERE i.dc_id = pb.dc_id AND i.business_date = pb.d AND z.zi = 4 AND i.fcst_dayahead IS NOT NULL
                GROUP BY z.zone_code, (i.local_slot / 4) ORDER BY sum(i.fcst_dayahead) DESC LIMIT 2) t),
       format('Expect about %s units (P10 %s, P90 %s). Picking is the pressure point; the playbook shifts flex labor toward picking and packing in the afternoon and releases hours in returns and ICQA.',
              v.fcst, round(v.fcst * 0.88)::int, round(v.fcst * 1.13)::int)
FROM _pb pb
CROSS JOIN LATERAL (SELECT random() < 0.8 AS ack, random() AS r) s
CROSS JOIN LATERAL (SELECT COALESCE(sum(i.fcst_dayahead), 0)::int AS fcst, COALESCE(sum(i.workload_in), 0)::int AS act
                    FROM wms_zone_interval i
                    WHERE i.dc_id = pb.dc_id AND i.business_date = pb.d AND i.zone_id % 10 = 4) v
CROSS JOIN LATERAL (SELECT sum(sp.scheduled_headcount) * 7.5 AS plan_hours FROM wfm_static_labor_plan sp
                    WHERE sp.dc_id = pb.dc_id AND sp.business_date = pb.d) p;

INSERT INTO agent_playbook_line(playbook_id, zone_id, local_hour, fcst_workload, required_hours, recommended_hc, static_plan_hc, flex_in, flex_out)
SELECT y.playbook_id, y.zone_id, y.hh, y.fcst, y.req, y.rec, y.stat,
       greatest(0, y.rec - y.stat)::smallint, greatest(0, y.stat - y.rec)::smallint
FROM (SELECT pb.playbook_id, i.zone_id, (i.local_slot / 4)::smallint AS hh, sum(i.fcst_dayahead)::int AS fcst,
             (sum(i.fcst_dayahead) / z.uph)::real AS req,
             least(z.maxhc, greatest(z.minhc, ceil(sum(i.fcst_dayahead) / z.uph / 0.85)))::smallint AS rec,
             p.scheduled_headcount AS stat
      FROM _pb pb
      JOIN wms_zone_interval i ON i.dc_id = pb.dc_id AND i.business_date = pb.d
      JOIN _zone z ON z.zone_id = i.zone_id
      JOIN wfm_static_labor_plan p ON p.dc_id = i.dc_id AND p.business_date = i.business_date AND p.zone_id = i.zone_id
       AND p.shift_code = CASE WHEN i.local_slot / 4 BETWEEN 6 AND 13 THEN 'S1' WHEN i.local_slot / 4 BETWEEN 14 AND 21 THEN 'S2' ELSE 'S3' END
      WHERE i.fcst_dayahead IS NOT NULL
      GROUP BY pb.playbook_id, i.zone_id, (i.local_slot / 4), z.uph, z.minhc, z.maxhc, p.scheduled_headcount) y;

-- ---------------------------------------------------------------------
-- 9. Refresh the materialized views (order matters: mv_dc_daily reads mv_zone_daily)
-- ---------------------------------------------------------------------
REFRESH MATERIALIZED VIEW mv_zone_daily;
REFRESH MATERIALIZED VIEW mv_dc_daily;
REFRESH MATERIALIZED VIEW mv_forecast_accuracy;
REFRESH MATERIALIZED VIEW mv_bottleneck_heatmap;

COMMIT;

-- ---------------------------------------------------------------------
-- Row counts per table (check the result grid)
-- ---------------------------------------------------------------------
SELECT c.relname AS table_name, (xpath('/row/n/text()', query_to_xml(format('SELECT count(*) AS n FROM labor_allocation.%I', c.relname), false, true, '')))[1]::text::bigint AS row_count
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'labor_allocation' AND c.relkind = 'r'
ORDER BY c.relname;
