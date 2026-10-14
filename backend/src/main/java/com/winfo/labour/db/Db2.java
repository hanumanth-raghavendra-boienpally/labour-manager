package com.winfo.labour.db;

import org.springframework.jdbc.core.JdbcTemplate;

/**
 * DB2: the workflow database (schema workflow). Store manager decisions, allocations, notifications,
 * sign-in accounts and the audit log. @Transactional methods run on this database.
 */
public class Db2 extends JdbcDb {

    public Db2(JdbcTemplate jdbc) {
        super(jdbc);
    }
}
