package com.winfo.labour.db;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Finds the settings of the two databases once, in plain Java (no Spring), so a mistake is reported in one clear
 * message instead of a stack trace.
 *
 *   DB1 = the agent database (schema labor_allocation, the 49 tables). The AI agent writes here; this app only reads it.
 *   DB2 = the workflow database (schema workflow). Decisions, allocations, notifications and the audit log go here.
 *
 * Where it looks, in this order (first one found wins):
 *   1. a file called ".env" in the backend folder (or the project folder above it)
 *   2. environment variables
 *
 * What it accepts, for DB1 (DB2 is the same with DB2_ in front):
 *   DB1_URL=postgresql://USER:PASSWORD@HOST/DATABASE      (paste the Render/Neon URL as it is)
 *   or DB1_URL=jdbc:postgresql://HOST:5432/DATABASE  plus  DB1_USER  and  DB1_PASSWORD
 *   DATABASE_URL is still accepted as another name for DB1_URL.
 *
 * There are no defaults on purpose: the app never silently falls back to "postgres on localhost".
 */
public final class DbSettings {

    public final String jdbcUrl;
    public final String user;
    public final String password;
    public final String host;
    public final String database;
    public final String source;
    /** "DB1" or "DB2", used in messages. */
    public final String label;

    private DbSettings(String label, String jdbcUrl, String user, String password, String host, String database, String source) {
        this.label = label;
        this.jdbcUrl = jdbcUrl;
        this.user = user;
        this.password = password;
        this.host = host;
        this.database = database;
        this.source = source;
    }

    /** Thrown with a message that is safe to show to the user as it is. */
    public static final class ConfigException extends RuntimeException {
        public ConfigException(String message) { super(message); }
    }

    private static volatile DbSettings db1;
    private static volatile DbSettings db2;

    /** The agent database (labor_allocation). */
    public static synchronized DbSettings db1() {
        if (db1 == null) db1 = load("DB1");
        return db1;
    }

    /** The workflow database (workflow schema). */
    public static synchronized DbSettings db2() {
        if (db2 == null) {
            try {
                db2 = load("DB2");
            } catch (ConfigException noDb2Url) {
                // Only one Postgres URL? Then DB2 lives in the same database as DB1, in its own "workflow" schema.
                db2 = load("DB1");
            }
        }
        return db2;
    }

    static final List<Path> ENV_FILES = List.of(Path.of(".env"), Path.of("backend", ".env"), Path.of("..", ".env"));

    static List<String> keys(String label) {
        return "DB1".equals(label)
                ? List.of("DB1_URL", "DATABASE_URL", "DB1_USER", "DB1_PASSWORD")
                : List.of("DB2_URL", "DB2_USER", "DB2_PASSWORD");
    }

    public static DbSettings load(String label) {
        return load(label, System.getenv(), ENV_FILES);
    }

    public static DbSettings load(String label, Map<String, String> env, List<Path> envFiles) {
        List<String> keys = keys(label);
        Map<String, String> values = new LinkedHashMap<>();
        String source = "environment variables";
        for (String key : keys) {
            String v = clean(env.get(key));
            if (!v.isEmpty()) values.put(key, v);
        }
        for (Path file : envFiles) {
            if (!Files.isRegularFile(file)) continue;
            Map<String, String> fromFile = readEnvFile(file);
            Map<String, String> fileValues = new LinkedHashMap<>();
            boolean any = false;
            for (String key : keys) {
                String v = clean(fromFile.get(key));
                if (!v.isEmpty()) { fileValues.put(key, v); any = true; }
            }
            if (any) { // a .env file replaces environment variables completely, so old values can never mix in
                values = fileValues;
                source = file.toAbsolutePath().normalize().toString();
                break;
            }
        }
        // Normalise to URL / USER / PASSWORD.
        Map<String, String> v = new LinkedHashMap<>();
        String url = values.get(label + "_URL");
        if (url == null && "DB1".equals(label)) url = values.get("DATABASE_URL");
        if (url != null) v.put("URL", url);
        if (values.containsKey(label + "_USER")) v.put("USER", values.get(label + "_USER"));
        if (values.containsKey(label + "_PASSWORD")) v.put("PASSWORD", values.get(label + "_PASSWORD"));
        return build(label, v, source);
    }

    static DbSettings build(String label, Map<String, String> v, String source) {
        String what = "DB1".equals(label) ? "DB1 (the agent database with the labor_allocation tables)"
                : "DB2 (the workflow database for decisions and allocations)";
        String raw = v.get("URL");
        if (raw == null) {
            throw new ConfigException("No URL for " + what + ".\n\n"
                    + "One-time setup (takes a minute):\n"
                    + "  1. In the backend folder, copy  .env.example  to  .env\n"
                    + "  2. Open .env and fill in DB1_URL and DB2_URL (see the comments in the file)\n"
                    + "  3. Run the backend again. You never have to set anything per window.");
        }
        if (raw.toUpperCase().contains("YOUR_") || raw.contains("<") || raw.contains("HOST") && raw.contains("PASSWORD")) {
            throw new ConfigException(label + "_URL in .env is still the placeholder text. Replace it with your real database URL.");
        }

        String user = v.get("USER");
        String password = v.get("PASSWORD");
        String host;
        int port = 5432;
        String database;
        String query = "";

        String lower = raw.toLowerCase();
        if (lower.startsWith("postgres://") || lower.startsWith("postgresql://")) {
            String rest = raw.substring(raw.indexOf("://") + 3);
            int q = rest.indexOf('?');
            if (q >= 0) { query = rest.substring(q + 1); rest = rest.substring(0, q); }
            int at = rest.lastIndexOf('@');
            if (at >= 0) {
                String creds = rest.substring(0, at);
                rest = rest.substring(at + 1);
                int colon = creds.indexOf(':');
                String u = colon >= 0 ? creds.substring(0, colon) : creds;
                String p = colon >= 0 ? creds.substring(colon + 1) : null;
                if (!u.isEmpty()) user = percentDecode(u);
                if (p != null && !p.isEmpty()) password = percentDecode(p);
            }
            int slash = rest.indexOf('/');
            String hostPort = slash >= 0 ? rest.substring(0, slash) : rest;
            database = slash >= 0 ? rest.substring(slash + 1) : "";
            int colon = hostPort.lastIndexOf(':');
            if (colon >= 0 && hostPort.substring(colon + 1).matches("\\d+")) {
                port = Integer.parseInt(hostPort.substring(colon + 1));
                hostPort = hostPort.substring(0, colon);
            }
            host = hostPort;
        } else if (lower.startsWith("jdbc:postgresql://")) {
            String rest = raw.substring("jdbc:postgresql://".length());
            int q = rest.indexOf('?');
            if (q >= 0) { query = rest.substring(q + 1); rest = rest.substring(0, q); }
            if (rest.contains("@")) {
                throw new ConfigException("Do not put the user and password inside a jdbc: URL. Either paste the plain Render "
                        + "URL (postgresql://USER:PASSWORD@HOST/DATABASE) as " + label + "_URL, or use " + label + "_USER and " + label + "_PASSWORD.");
            }
            int slash = rest.indexOf('/');
            String hostPort = slash >= 0 ? rest.substring(0, slash) : rest;
            database = slash >= 0 ? rest.substring(slash + 1) : "";
            int colon = hostPort.lastIndexOf(':');
            if (colon >= 0 && hostPort.substring(colon + 1).matches("\\d+")) {
                port = Integer.parseInt(hostPort.substring(colon + 1));
                hostPort = hostPort.substring(0, colon);
            }
            host = hostPort;
        } else {
            throw new ConfigException("The database URL must start with postgresql:// (Render's URL) or jdbc:postgresql://. "
                    + "Check that " + label + "_URL in .env holds the whole URL.");
        }

        if (host.isEmpty()) throw new ConfigException(label + "_URL has no host name.");
        if (database.isEmpty()) throw new ConfigException(label + "_URL has no database name at the end (.../DATABASE).");
        if (user == null || user.isEmpty()) {
            throw new ConfigException("No database user. Use the full Render URL (postgresql://USER:PASSWORD@HOST/DATABASE) "
                    + "or add " + label + "_USER=... next to " + label + "_URL.");
        }
        if (password == null || password.isEmpty()) {
            throw new ConfigException("No database password. Use the full Render URL (postgresql://USER:PASSWORD@HOST/DATABASE) "
                    + "or add " + label + "_PASSWORD=... next to " + label + "_URL.");
        }
        if (host.startsWith("dpg-") && !host.contains(".")) {
            throw new ConfigException(label + ": the host '" + host + "' is Render's internal name and only works inside Render. "
                    + "Use the External Database URL, whose host ends in .render.com.");
        }

        boolean local = host.equals("localhost") || host.equals("127.0.0.1") || host.equals("::1");
        if (!local && !query.toLowerCase().contains("sslmode=")) query = query.isEmpty() ? "sslmode=require" : query + "&sslmode=require";
        if (!query.toLowerCase().contains("connecttimeout=")) query = query.isEmpty() ? "connectTimeout=15" : query + "&connectTimeout=15";

        String jdbc = "jdbc:postgresql://" + (host.contains(":") ? "[" + host + "]" : host) + ":" + port + "/" + database
                + (query.isEmpty() ? "" : "?" + query);
        return new DbSettings(label, jdbc, user, password, host + ":" + port, database, source);
    }

    // ---- helpers ----

    static Map<String, String> readEnvFile(Path file) {
        Map<String, String> out = new LinkedHashMap<>();
        List<String> lines;
        try {
            lines = Files.readAllLines(file, StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new ConfigException("Cannot read " + file.toAbsolutePath() + ": " + e.getMessage());
        }
        for (String line : lines) {
            String t = line.replace("﻿", "").strip();
            if (t.isEmpty() || t.startsWith("#")) continue;
            if (t.startsWith("export ")) t = t.substring(7).strip();
            int eq = t.indexOf('=');
            if (eq <= 0) continue;
            out.put(t.substring(0, eq).strip(), t.substring(eq + 1));
        }
        return out;
    }

    /** Trims spaces, stray carriage returns and one pair of surrounding quotes (common copy/paste slips). */
    static String clean(String v) {
        if (v == null) return "";
        String s = v.strip();
        if (s.length() >= 2 && (s.startsWith("\"") && s.endsWith("\"") || s.startsWith("'") && s.endsWith("'"))) {
            s = s.substring(1, s.length() - 1).strip();
        }
        return s;
    }

    /** Decodes %XX only ('+' stays a plus sign, which is what a password normally means). */
    static String percentDecode(String s) {
        if (s.indexOf('%') < 0) return s;
        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
        byte[] b = s.getBytes(StandardCharsets.UTF_8);
        for (int i = 0; i < b.length; i++) {
            if (b[i] == '%' && i + 2 < b.length + 0 && isHex(b[i + 1]) && isHex(b[i + 2])) {
                out.write(Integer.parseInt(new String(b, i + 1, 2, StandardCharsets.US_ASCII), 16));
                i += 2;
            } else out.write(b[i]);
        }
        return out.toString(StandardCharsets.UTF_8);
    }

    private static boolean isHex(byte c) {
        return c >= '0' && c <= '9' || c >= 'a' && c <= 'f' || c >= 'A' && c <= 'F';
    }
}
