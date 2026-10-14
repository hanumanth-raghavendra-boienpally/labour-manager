package com.winfo.labour.db;

import java.util.List;
import java.util.Map;

/**
 * Small SQL helper used by every service.
 * Rows come back as maps with plain values only: String, Integer, Long, Double, Boolean or null.
 * Dates are "yyyy-MM-dd" strings and timestamps are ISO-8601 strings, so they serialise to JSON unchanged.
 * Parameters use "?" placeholders; cast non-numeric parameters in SQL (for example ?::date).
 */
public interface Db {

    List<Map<String, Object>> rows(String sql, Object... args);

    /** Runs INSERT/UPDATE/DELETE and returns the affected row count. */
    int exec(String sql, Object... args);

    /** Runs one statement with no parameters (DDL). */
    void execute(String sql);

    default Map<String, Object> one(String sql, Object... args) {
        List<Map<String, Object>> r = rows(sql, args);
        return r.isEmpty() ? null : r.get(0);
    }

    default int intValue(String sql, Object... args) {
        Map<String, Object> r = one(sql, args);
        if (r == null || r.isEmpty()) return 0;
        Object v = r.values().iterator().next();
        return v == null ? 0 : ((Number) v).intValue();
    }
}
