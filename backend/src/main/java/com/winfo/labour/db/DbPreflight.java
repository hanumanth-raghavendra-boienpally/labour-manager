package com.winfo.labour.db;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.Properties;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Tries both databases before Spring starts and turns every failure into one plain-language message
 * (what is wrong and what to change). Never prints a password.
 */
public final class DbPreflight {

    private DbPreflight() { }

    /** DB1 must be reachable and hold labor_allocation with the agent's playbook tables. @return null when fine. */
    public static String checkDb1(DbSettings s) {
        return withRetry(s, c -> {
            try (Statement st = c.createStatement();
                 ResultSet rs = st.executeQuery("select count(*) filter (where true), "
                         + "count(*) filter (where table_name in ('agent_playbook', 'agent_playbook_line')) "
                         + "from information_schema.tables where table_schema = 'labor_allocation'")) {
                rs.next();
                if (rs.getInt(1) == 0) {
                    return "Connected to DB1 database '" + s.database + "' as '" + s.user + "', but it has no labor_allocation schema.\n"
                            + "DB1_URL must point at the database that holds the 49 tables the agent writes to.";
                }
                if (rs.getInt(2) < 2) {
                    return "DB1 database '" + s.database + "' has a labor_allocation schema but no agent_playbook / agent_playbook_line tables.\n"
                            + "Run database/db1/01-labor_allocation_schema.sql on it first.";
                }
                return null;
            }
        });
    }

    /** DB2 must be reachable. On a local server a missing DB2 database is created. @return null when fine. */
    public static String checkDb2(DbSettings s) {
        String problem = withRetry(s, c -> null);
        if (problem == null || !problem.startsWith(MISSING_DB)) return problem;
        // Missing database: try to create it through the server's "postgres" database with the same account.
        String adminUrl = replaceDatabase(s.jdbcUrl, s.database, "postgres");
        try (Connection c = DriverManager.getConnection(adminUrl, props(s)); Statement st = c.createStatement()) {
            st.execute("create database \"" + s.database.replace("\"", "") + "\"");
            System.out.println("Created DB2 database '" + s.database + "' on " + s.host + ".");
            return withRetry(s, x -> null);
        } catch (SQLException e) {
            return "DB2 database '" + s.database + "' does not exist on " + s.host + " and could not be created automatically ("
                    + firstLine(String.valueOf(e.getMessage())) + ").\n"
                    + "Fix: create it yourself (pgAdmin: right-click Databases > Create > Database, name: " + s.database + "),\n"
                    + "or point DB2_URL at an existing database. It may even be the same database as DB1: DB2 uses its own 'workflow' schema.";
        }
    }

    private static final String MISSING_DB = "MISSING_DB:";

    interface Check { String run(Connection c) throws SQLException; }

    private static String withRetry(DbSettings s, Check check) {
        SQLException last = null;
        for (int attempt = 1; attempt <= 3; attempt++) {
            try (Connection c = DriverManager.getConnection(s.jdbcUrl, props(s))) {
                return check.run(c);
            } catch (SQLException e) {
                last = e;
                if ("3D000".equals(e.getSQLState())) return MISSING_DB + explain(s, e);
                if (!transientError(e)) break;
                try { Thread.sleep(2500L * attempt); } catch (InterruptedException ie) { Thread.currentThread().interrupt(); break; }
            }
        }
        return explain(s, last);
    }

    /** Strips the internal marker before showing a message. */
    public static String forDisplay(String problem) {
        return problem != null && problem.startsWith(MISSING_DB) ? problem.substring(MISSING_DB.length()) : problem;
    }

    private static Properties props(DbSettings s) {
        Properties p = new Properties();
        p.setProperty("user", s.user);
        p.setProperty("password", s.password);
        return p;
    }

    static String replaceDatabase(String jdbcUrl, String database, String replacement) {
        Matcher m = Pattern.compile("/" + Pattern.quote(database) + "(\\?|$)").matcher(jdbcUrl);
        return m.find() ? jdbcUrl.substring(0, m.start()) + "/" + replacement + m.group(1) + jdbcUrl.substring(m.end()) : jdbcUrl;
    }

    private static boolean transientError(SQLException e) {
        String st = e.getSQLState() == null ? "" : e.getSQLState();
        return st.startsWith("08") || st.equals("57P03") || st.equals("53300");
    }

    static String explain(DbSettings s, SQLException e) {
        if (e == null) return s.label + ": the database connection failed for an unknown reason.";
        String state = e.getSQLState() == null ? "" : e.getSQLState();
        String msg = String.valueOf(e.getMessage());
        String key = s.label + "_URL";
        String who = s.label + " (user '" + s.user + "' on " + s.host + " / database '" + s.database + "')";
        if (state.equals("28P01") || state.equals("28000") || msg.contains("password authentication failed")) {
            return "The database rejected the sign-in for " + who + ".\n"
                    + "The user name or password in " + key + " is wrong (or the password was changed/rotated).\n"
                    + "Fix: copy the connection URL again from your provider (Render: External Database URL) and paste it as " + key + " in .env.";
        }
        if (state.equals("3D000")) {
            return "The server for " + s.label + " is reachable, but there is no database called '" + s.database + "'.\n"
                    + "Fix: the last part of " + key + " in .env must be an existing database name.";
        }
        if (msg.contains("UnknownHost") || msg.toLowerCase().contains("unknownhost") || msg.contains("No such host")) {
            return "The host name '" + s.host + "' in " + key + " could not be found.\n"
                    + "Fix: on Render use the External Database URL (host ends in .render.com), and check your internet connection.";
        }
        if (msg.toLowerCase().contains("ssl") || msg.contains("no pg_hba.conf entry")) {
            return s.label + ": the server needs an encrypted (SSL) connection and the settings do not match: " + firstLine(msg) + "\n"
                    + "Fix: keep ?sslmode=require for hosted databases (it is added automatically for non-local hosts).";
        }
        if (state.startsWith("08") || msg.contains("timed out") || msg.contains("Connection refused")) {
            return "Could not reach " + s.label + " at " + s.host + " (" + firstLine(msg) + ").\n"
                    + "Fix: check that PostgreSQL is running (local) or your internet/VPN/firewall (hosted). "
                    + "Free hosted databases can also be paused: open your provider's dashboard.";
        }
        return "The database connection failed for " + who + ".\nDetail: " + firstLine(msg) + " (SQL state " + state + ")";
    }

    private static String firstLine(String s) {
        int i = s.indexOf('\n');
        return i < 0 ? s : s.substring(0, i);
    }
}
