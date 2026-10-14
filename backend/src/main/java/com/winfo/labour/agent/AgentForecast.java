package com.winfo.labour.agent;

import java.util.List;

import com.winfo.labour.forecast.Grid;
import com.winfo.labour.forecast.ShiftCalendar;

/**
 * One AI labour forecast: everything the "AI labour forecast" card and the zone x hour breakdown show.
 * Built from DB1 (the agent's playbook, live) or from the DB2 snapshot taken when the store manager decided.
 *
 * Grids are [zone][hourIndex], hour index 0 = first hour of the business day (06:00 in the sample data).
 */
public record AgentForecast(
        int playbookId,
        String sourceKey,
        String playbookStatus,
        int dcId,
        String dcCode,
        String dcName,
        String businessDate,
        String dateLabel,
        String generatedAt,
        String generatedBy,
        String agentMode,
        String workloadSource,
        String scheduleSource,
        String coverage,
        List<String> drivers,
        String narrative,
        ShiftCalendar calendar,
        List<Zone> zones,
        int[][] workload,
        int[][] required,
        int[][] scheduled) {

    public record Zone(int id, String code, String name, String skill) {}

    public int requiredHours() {
        return Grid.sum(required);
    }

    public int scheduledHours() {
        return Grid.sum(scheduled);
    }

    /** Index of a zone in {@link #zones()}, or -1. */
    public int zoneIndex(int zoneId) {
        for (int i = 0; i < zones.size(); i++) if (zones.get(i).id() == zoneId) return i;
        return -1;
    }
}
