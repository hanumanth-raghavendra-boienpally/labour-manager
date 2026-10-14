-- =====================================================================================================
-- AGENT SIMULATOR (DB1) · stands in for the AI agent until the real one is connected.
--
-- Run this file once on DB1 (the database with labor_allocation). It creates a separate schema "agent_sim" with
-- three functions. They write labor_allocation.agent_playbook + agent_playbook_line exactly the way the agent does,
-- so the app sees a real "AI dump" and the store manager gets the popup.
--
--   SELECT agent_sim.publish('DAL01', DATE '2026-10-10');   -- the agent sends a forecast for Dallas, Sat 10 Oct
--   SELECT agent_sim.publish('ATL01', DATE '2026-10-10');   -- ... and one for Atlanta
--   SELECT agent_sim.publish('DAL01', DATE '2026-10-10');   -- run again: the agent rewrites it -> becomes version 2
--   SELECT agent_sim.publish('DAL01', DATE '2026-10-09');   -- a date from the sample data: re-sends that playbook as is
--   SELECT * FROM agent_sim.status();                        -- what the agent has written
--   SELECT agent_sim.cleanup();                              -- removes everything the simulator did (restores re-sent playbooks)
--
-- Only the pilot DCs (DAL01, ATL01) have playbooks in the sample data; the simulator copies the shape of the DC's
-- latest playbook and varies the numbers a little, so every run looks like a fresh forecast.
-- Safe to run this file again (CREATE OR REPLACE).
-- =====================================================================================================

CREATE SCHEMA IF NOT EXISTS agent_sim;

-- Playbooks the simulator re-sent, with their original values, so cleanup() can restore them.
CREATE TABLE IF NOT EXISTS agent_sim.resent (
  playbook_id      int PRIMARY KEY,
  old_status       text NOT NULL,
  old_generated_at timestamptz NOT NULL,
  old_ack_by       smallint
);

CREATE OR REPLACE FUNCTION agent_sim.publish(p_dc_code text, p_business_date date) RETURNS text
LANGUAGE plpgsql AS $$
DECLARE
  v_dc_id    smallint;
  v_tpl      labor_allocation.agent_playbook%ROWTYPE;
  v_existing labor_allocation.agent_playbook%ROWTYPE;
  v_id       int;
  v_factor   numeric := round((0.94 + random() * 0.14)::numeric, 3);
BEGIN
  SELECT dc_id INTO v_dc_id FROM labor_allocation.dc WHERE dc_code = upper(p_dc_code);
  IF v_dc_id IS NULL THEN
    RAISE EXCEPTION 'No DC with code % in labor_allocation.dc', p_dc_code;
  END IF;

  SELECT * INTO v_existing FROM labor_allocation.agent_playbook WHERE dc_id = v_dc_id AND business_date = p_business_date;

  -- A playbook from the sample data: re-send it unchanged (new generated_at, status PUBLISHED).
  IF FOUND AND v_existing.narrative NOT LIKE '%[simulated]%' THEN
    INSERT INTO agent_sim.resent (playbook_id, old_status, old_generated_at, old_ack_by)
    VALUES (v_existing.playbook_id, v_existing.status, v_existing.generated_at, v_existing.acknowledged_by_supervisor_id)
    ON CONFLICT (playbook_id) DO NOTHING;
    UPDATE labor_allocation.agent_playbook
       SET status = 'PUBLISHED', generated_at = clock_timestamp(), acknowledged_by_supervisor_id = NULL
     WHERE playbook_id = v_existing.playbook_id;
    RETURN format('Re-sent playbook #%s for %s %s (status PUBLISHED, new generated_at).', v_existing.playbook_id, upper(p_dc_code), p_business_date);
  END IF;

  -- Template: the DC's latest real playbook that has lines.
  SELECT p.* INTO v_tpl FROM labor_allocation.agent_playbook p
   WHERE p.dc_id = v_dc_id AND p.narrative NOT LIKE '%[simulated]%'
     AND EXISTS (SELECT 1 FROM labor_allocation.agent_playbook_line l WHERE l.playbook_id = p.playbook_id)
   ORDER BY p.business_date DESC LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'DC % has no agent playbook to copy. In the sample data only the pilot DCs DAL01 and ATL01 have one.', upper(p_dc_code);
  END IF;

  IF v_existing.playbook_id IS NOT NULL THEN
    v_id := v_existing.playbook_id;
    UPDATE labor_allocation.agent_playbook SET
      generated_at = clock_timestamp(), status = 'PUBLISHED', acknowledged_by_supervisor_id = NULL,
      model_version_id = v_tpl.model_version_id, agent_mode = v_tpl.agent_mode,
      fcst_volume = round(v_tpl.fcst_volume * v_factor), fcst_volume_p10 = round(v_tpl.fcst_volume * v_factor * 0.88),
      fcst_volume_p90 = round(v_tpl.fcst_volume * v_factor * 1.13),
      recommended_hours = round((v_tpl.recommended_hours * v_factor)::numeric, 1),
      narrative = format('Expect about %s units (P10 %s, P90 %s). Picking is the pressure point; the playbook shifts flex labor toward picking and packing in the afternoon. [simulated]',
                         round(v_tpl.fcst_volume * v_factor), round(v_tpl.fcst_volume * v_factor * 0.88), round(v_tpl.fcst_volume * v_factor * 1.13))
    WHERE playbook_id = v_id;
    DELETE FROM labor_allocation.agent_playbook_line WHERE playbook_id = v_id;
  ELSE
    SELECT coalesce(max(playbook_id), 0) + 1 INTO v_id FROM labor_allocation.agent_playbook;
    INSERT INTO labor_allocation.agent_playbook (playbook_id, dc_id, business_date, generated_at, model_version_id, agent_mode, status,
           acknowledged_by_supervisor_id, fcst_volume, fcst_volume_p10, fcst_volume_p90, actual_volume, static_plan_hours,
           recommended_hours, recommended_vet_hours, recommended_vto_hours, risk_windows, narrative)
    VALUES (v_id, v_dc_id, p_business_date, clock_timestamp(), v_tpl.model_version_id, v_tpl.agent_mode, 'PUBLISHED', NULL,
            round(v_tpl.fcst_volume * v_factor), round(v_tpl.fcst_volume * v_factor * 0.88), round(v_tpl.fcst_volume * v_factor * 1.13),
            NULL, v_tpl.static_plan_hours, round((v_tpl.recommended_hours * v_factor)::numeric, 1),
            v_tpl.recommended_vet_hours, v_tpl.recommended_vto_hours, v_tpl.risk_windows,
            format('Expect about %s units (P10 %s, P90 %s). Picking is the pressure point; the playbook shifts flex labor toward picking and packing in the afternoon. [simulated]',
                   round(v_tpl.fcst_volume * v_factor), round(v_tpl.fcst_volume * v_factor * 0.88), round(v_tpl.fcst_volume * v_factor * 1.13)));
  END IF;

  -- Zone x hour lines: the template's shape, workload scaled, recommended headcount nudged up or down here and there.
  INSERT INTO labor_allocation.agent_playbook_line (playbook_id, zone_id, local_hour, fcst_workload, required_hours,
         recommended_hc, static_plan_hc, flex_in, flex_out)
  SELECT v_id, l.zone_id, l.local_hour, round(l.fcst_workload * v_factor), (l.required_hours * v_factor)::real, x.rec,
         l.static_plan_hc, greatest(0, x.rec - l.static_plan_hc), greatest(0, l.static_plan_hc - x.rec)
  FROM labor_allocation.agent_playbook_line l
  CROSS JOIN LATERAL (SELECT greatest(0, round(l.recommended_hc * v_factor)
                        + CASE WHEN random() < 0.15 THEN 1 WHEN random() < 0.08 THEN -1 ELSE 0 END)::smallint AS rec) x
  WHERE l.playbook_id = v_tpl.playbook_id;

  RETURN format('Agent wrote playbook #%s for %s %s (status PUBLISHED). The store manager will be notified within a few seconds.',
                v_id, upper(p_dc_code), p_business_date);
END;
$$;

CREATE OR REPLACE FUNCTION agent_sim.status()
RETURNS TABLE (playbook_id int, dc_code text, business_date date, status text, generated_at timestamptz, lines bigint, simulated boolean)
LANGUAGE sql AS $$
  SELECT p.playbook_id, d.dc_code, p.business_date, p.status, p.generated_at,
         (SELECT count(*) FROM labor_allocation.agent_playbook_line l WHERE l.playbook_id = p.playbook_id),
         p.narrative LIKE '%[simulated]%' OR EXISTS (SELECT 1 FROM agent_sim.resent r WHERE r.playbook_id = p.playbook_id)
  FROM labor_allocation.agent_playbook p JOIN labor_allocation.dc d ON d.dc_id = p.dc_id
  ORDER BY p.generated_at DESC;
$$;

CREATE OR REPLACE FUNCTION agent_sim.cleanup() RETURNS text
LANGUAGE plpgsql AS $$
DECLARE
  v_removed int;
  v_restored int;
BEGIN
  DELETE FROM labor_allocation.agent_playbook_line
   WHERE playbook_id IN (SELECT playbook_id FROM labor_allocation.agent_playbook WHERE narrative LIKE '%[simulated]%');
  DELETE FROM labor_allocation.agent_playbook WHERE narrative LIKE '%[simulated]%';
  GET DIAGNOSTICS v_removed = ROW_COUNT;
  UPDATE labor_allocation.agent_playbook p
     SET status = r.old_status, generated_at = r.old_generated_at, acknowledged_by_supervisor_id = r.old_ack_by
    FROM agent_sim.resent r WHERE r.playbook_id = p.playbook_id;
  GET DIAGNOSTICS v_restored = ROW_COUNT;
  DELETE FROM agent_sim.resent;
  RETURN format('Removed %s simulated playbook(s), restored %s re-sent playbook(s). Run database/reset-db2.sql to clear DB2 as well.',
                v_removed, v_restored);
END;
$$;
