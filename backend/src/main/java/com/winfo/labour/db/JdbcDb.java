package com.winfo.labour.db;

import java.math.BigDecimal;
import java.sql.Array;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;

/** {@link Db} on top of Spring's JdbcTemplate, so it joins @Transactional transactions. See {@link Db1} and {@link Db2}. */
public abstract class JdbcDb implements Db {

    private final JdbcTemplate jdbc;

    protected JdbcDb(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public List<Map<String, Object>> rows(String sql, Object... args) {
        List<Map<String, Object>> raw = jdbc.queryForList(sql, args);
        List<Map<String, Object>> out = new ArrayList<>(raw.size());
        for (Map<String, Object> row : raw) {
            Map<String, Object> clean = new LinkedHashMap<>();
            for (Map.Entry<String, Object> e : row.entrySet()) clean.put(e.getKey(), normalise(e.getValue()));
            out.add(clean);
        }
        return out;
    }

    @Override
    public int exec(String sql, Object... args) {
        return jdbc.update(sql, args);
    }

    @Override
    public void execute(String sql) {
        jdbc.execute(sql);
    }

    static Object normalise(Object v) {
        if (v == null) return null;
        if (v instanceof Timestamp ts) return ts.toInstant().toString();
        if (v instanceof OffsetDateTime odt) return odt.toInstant().toString();
        if (v instanceof java.sql.Date d) return d.toLocalDate().toString();
        if (v instanceof LocalDate ld) return ld.toString();
        if (v instanceof BigDecimal bd) return bd.doubleValue();
        if (v instanceof Float f) return f.doubleValue();
        if (v instanceof Short s) return s.intValue();
        if (v instanceof Array arr) {
            try {
                Object[] items = (Object[]) arr.getArray();
                List<Object> list = new ArrayList<>(items.length);
                for (Object item : items) list.add(normalise(item));
                return list;
            } catch (SQLException e) {
                throw new IllegalStateException("Cannot read SQL array", e);
            }
        }
        return v;
    }
}
