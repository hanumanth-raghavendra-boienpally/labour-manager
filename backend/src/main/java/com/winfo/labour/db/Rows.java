package com.winfo.labour.db;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/** Null-safe readers for row maps and JSON request bodies. */
public final class Rows {

    private Rows() {}

    public static int i(Map<String, ?> m, String key) {
        Object v = m.get(key);
        if (v == null) return 0;
        if (v instanceof Number n) return n.intValue();
        return Integer.parseInt(v.toString().trim());
    }

    public static Integer iOrNull(Map<String, ?> m, String key) {
        Object v = m.get(key);
        if (v == null || v.toString().isBlank()) return null;
        if (v instanceof Number n) return n.intValue();
        return Integer.parseInt(v.toString().trim());
    }

    public static double d(Map<String, ?> m, String key) {
        Object v = m.get(key);
        if (v == null) return 0;
        if (v instanceof Number n) return n.doubleValue();
        return Double.parseDouble(v.toString().trim());
    }

    public static String s(Map<String, ?> m, String key) {
        Object v = m.get(key);
        return v == null ? null : v.toString();
    }

    public static boolean b(Map<String, ?> m, String key) {
        Object v = m.get(key);
        if (v == null) return false;
        if (v instanceof Boolean bool) return bool;
        return "true".equalsIgnoreCase(v.toString()) || "t".equalsIgnoreCase(v.toString());
    }

    @SuppressWarnings("unchecked")
    public static List<Map<String, Object>> list(Map<String, ?> m, String key) {
        Object v = m.get(key);
        if (!(v instanceof List<?> raw)) return List.of();
        List<Map<String, Object>> out = new ArrayList<>();
        for (Object item : raw) if (item instanceof Map<?, ?> map) out.add((Map<String, Object>) map);
        return out;
    }

    @SuppressWarnings("unchecked")
    public static List<String> strings(Map<String, ?> m, String key) {
        Object v = m.get(key);
        if (!(v instanceof List<?> raw)) return List.of();
        List<String> out = new ArrayList<>();
        for (Object item : raw) if (item != null) out.add(item.toString());
        return out;
    }
}
