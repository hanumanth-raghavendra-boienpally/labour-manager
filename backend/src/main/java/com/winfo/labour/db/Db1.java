package com.winfo.labour.db;

import org.springframework.jdbc.core.JdbcTemplate;

/**
 * DB1: the agent database (schema labor_allocation, the 49 tables). The AI agent writes its forecast here
 * (agent_playbook + agent_playbook_line). This application only ever READS DB1.
 */
public class Db1 extends JdbcDb {

    public Db1(JdbcTemplate jdbc) {
        super(jdbc);
    }

    @Override
    public int exec(String sql, Object... args) {
        throw new UnsupportedOperationException("DB1 belongs to the agent and is read-only for this application.");
    }

    @Override
    public void execute(String sql) {
        throw new UnsupportedOperationException("DB1 belongs to the agent and is read-only for this application.");
    }
}
