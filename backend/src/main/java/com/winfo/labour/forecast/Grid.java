package com.winfo.labour.forecast;

/**
 * Zone x hour arithmetic behind the four KPI cards (Forecast, Allocation and Admin pages).
 * need[z][h] is the requirement (agent_playbook_line.recommended_hc), staff[z][h] the cover (agent_playbook_line.static_plan_hc).
 */
public final class Grid {

    private Grid() {}

    /** Critical shortage: short by 2+ staff, or short and less than half of the need covered. */
    public static boolean critical(int need, int staff) {
        int shortBy = need - staff;
        return shortBy >= 2 || (shortBy >= 1 && staff * 2 < need);
    }

    /** "Forecast required" / "Scheduled": the sum over every zone and hour, in staff-hours. */
    public static int sum(int[][] grid) {
        int total = 0;
        for (int[] row : grid) for (int v : row) total += v;
        return total;
    }

    /** Share of the need that the cover meets, in percent (one decimal). */
    public static double coverage(int[][] need, int[][] staff) {
        long needed = 0, met = 0;
        for (int z = 0; z < need.length; z++) {
            for (int h = 0; h < need[z].length; h++) {
                needed += need[z][h];
                met += Math.min(need[z][h], staff[z][h]);
            }
        }
        return needed == 0 ? 100.0 : Math.round(met * 1000.0 / needed) / 10.0;
    }

    /** "Critical shortage hours": zone-hours that are critically short. */
    public static int criticalCount(int[][] need, int[][] staff) {
        int n = 0;
        for (int z = 0; z < need.length; z++) for (int h = 0; h < need[z].length; h++) if (critical(need[z][h], staff[z][h])) n++;
        return n;
    }

    /** "Overstaffed hours": zone-hours with 2+ more staff scheduled than needed. */
    public static int overstaffedCount(int[][] need, int[][] staff) {
        int n = 0;
        for (int z = 0; z < need.length; z++) for (int h = 0; h < need[z].length; h++) if (staff[z][h] - need[z][h] >= 2) n++;
        return n;
    }
}
