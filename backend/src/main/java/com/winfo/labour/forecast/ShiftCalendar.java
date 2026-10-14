package com.winfo.labour.forecast;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import com.winfo.labour.db.Db;
import com.winfo.labour.db.Rows;

/**
 * Business-day clock for one DC. The business day starts when the first shift (S1) starts, 06:00 in the sample data.
 * Hour index 0 is the first hour of the business day and 23 the last; window ends are exclusive (0..24).
 */
public final class ShiftCalendar {

    public record Shift(String code, String name, int startIndex, int endIndex, double paidHours) {
        public boolean covers(int hourIndex) { return hourIndex >= startIndex && hourIndex < endIndex; }
    }

    private final int dayStartHour;
    private final Map<String, Shift> shifts;

    private ShiftCalendar(int dayStartHour, Map<String, Shift> shifts) {
        this.dayStartHour = dayStartHour;
        this.shifts = shifts;
    }

    public static ShiftCalendar load(Db db, int dcId) {
        List<Map<String, Object>> rows = db.rows(
                "select shift_code, shift_name, extract(hour from start_time)::int as start_h, "
                        + "extract(hour from end_time)::int as end_h, paid_hours "
                        + "from labor_allocation.shift_definition where dc_id = ? order by start_time", dcId);
        int dayStart = 6;
        for (Map<String, Object> r : rows) if ("S1".equals(Rows.s(r, "shift_code"))) dayStart = Rows.i(r, "start_h");
        Map<String, Shift> map = new LinkedHashMap<>();
        for (Map<String, Object> r : rows) {
            int start = ((Rows.i(r, "start_h") - dayStart) % 24 + 24) % 24;
            int length = ((Rows.i(r, "end_h") - Rows.i(r, "start_h")) % 24 + 24) % 24;
            if (length == 0) length = 24;
            map.put(Rows.s(r, "shift_code"), new Shift(Rows.s(r, "shift_code"), Rows.s(r, "shift_name"),
                    start, Math.min(24, start + length), Rows.d(r, "paid_hours")));
        }
        if (map.isEmpty()) {
            map.put("S1", new Shift("S1", "Day", 0, 8, 7.5));
            map.put("S2", new Shift("S2", "Swing", 8, 16, 7.5));
            map.put("S3", new Shift("S3", "Night", 16, 24, 7.5));
        }
        return new ShiftCalendar(dayStart, map);
    }

    /**
     * Calendar for pages that only read DB2: three 8-hour shifts (S1, S2, S3) from the business-day start hour
     * that was stored with the snapshot. Matches labor_allocation.shift_definition in the sample data.
     */
    public static ShiftCalendar ofDayStart(int dayStartHour) {
        Map<String, Shift> map = new LinkedHashMap<>();
        map.put("S1", new Shift("S1", "Day", 0, 8, 7.5));
        map.put("S2", new Shift("S2", "Swing", 8, 16, 7.5));
        map.put("S3", new Shift("S3", "Night", 16, 24, 7.5));
        return new ShiftCalendar(((dayStartHour % 24) + 24) % 24, map);
    }

    public int dayStartHour() {
        return dayStartHour;
    }

    public int localHour(int hourIndex) {
        return (dayStartHour + hourIndex) % 24;
    }

    public int hourIndex(int localHour) {
        return ((localHour - dayStartHour) % 24 + 24) % 24;
    }

    public Shift shiftAt(int hourIndex) {
        for (Shift s : shifts.values()) if (s.covers(hourIndex)) return s;
        return shifts.values().iterator().next();
    }

    public Shift shift(String code) {
        Shift s = shifts.get(code);
        return s != null ? s : shifts.values().iterator().next();
    }

    public List<Shift> all() {
        return new ArrayList<>(shifts.values());
    }

    /** "6a", "12p", "9p" for the start of an hour index (24 = end of the business day). */
    public String label(int hourIndex) {
        return clockLabel(localHour(hourIndex));
    }

    public String window(int startIndex, int endIndexExclusive) {
        return label(startIndex) + "–" + label(endIndexExclusive);
    }

    public static String clockLabel(int localHour) {
        int h = localHour % 12 == 0 ? 12 : localHour % 12;
        return h + (localHour < 12 ? "a" : "p");
    }

    public List<Map<String, Object>> hoursForUi() {
        List<Map<String, Object>> out = new ArrayList<>();
        for (int i = 0; i < 24; i++) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("index", i);
            m.put("localHour", localHour(i));
            m.put("label", label(i));
            m.put("shift", shiftAt(i).code());
            out.add(m);
        }
        return out;
    }
}
