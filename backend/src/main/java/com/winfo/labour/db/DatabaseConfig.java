package com.winfo.labour.db;

import javax.sql.DataSource;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;

/**
 * Two connection pools: DB1 (agent data, read-only) and DB2 (workflow data). Settings come from {@link DbSettings}
 * (backend/.env), never from hidden defaults. Transactions (@Transactional) run on DB2, where all writes happen.
 * Every injection names its bean explicitly, so DB1 can never be handed the primary (DB2) pool by mistake.
 */
@Configuration
@EnableTransactionManagement
public class DatabaseConfig {

    private static HikariDataSource pool(DbSettings s, String name, boolean readOnly, int size) {
        HikariConfig c = new HikariConfig();
        c.setPoolName(name);
        c.setJdbcUrl(s.jdbcUrl);
        c.setUsername(s.user);
        c.setPassword(s.password);
        c.setMaximumPoolSize(size);
        c.setReadOnly(readOnly);
        c.setConnectionTimeout(20_000);
        // Far-away hosted databases: keep connections open and warm, so no request pays for a new TLS login (1-2 s).
        c.setMinimumIdle(size);
        c.setKeepaliveTime(30_000);
        c.setMaxLifetime(600_000);
        c.addDataSourceProperty("tcpKeepAlive", "true");
        c.addDataSourceProperty("reWriteBatchedInserts", "true");
        c.setInitializationFailTimeout(-1); // Spring only starts after DbPreflight has already proven the login works
        return new HikariDataSource(c);
    }

    @Bean(name = "db1DataSource", destroyMethod = "close")
    public HikariDataSource db1DataSource() {
        return pool(DbSettings.db1(), "db1-agent", true, 8);
    }

    @Bean(name = "db2DataSource", destroyMethod = "close")
    @Primary
    public HikariDataSource db2DataSource() {
        return pool(DbSettings.db2(), "db2-workflow", false, 10);
    }

    @Bean
    public Db1 db1(@Qualifier("db1DataSource") HikariDataSource db1DataSource) {
        return new Db1(new JdbcTemplate(db1DataSource));
    }

    @Bean
    @Primary
    public JdbcTemplate db2JdbcTemplate(@Qualifier("db2DataSource") HikariDataSource db2DataSource) {
        return new JdbcTemplate(db2DataSource);
    }

    @Bean
    public Db2 db2(@Qualifier("db2JdbcTemplate") JdbcTemplate db2JdbcTemplate) {
        return new Db2(db2JdbcTemplate);
    }

    @Bean(name = "transactionManager")
    public DataSourceTransactionManager transactionManager(@Qualifier("db2DataSource") HikariDataSource db2DataSource) {
        return new DataSourceTransactionManager((DataSource) db2DataSource);
    }
}
