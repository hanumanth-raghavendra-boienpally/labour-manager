package com.winfo.labour.db;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

import com.winfo.labour.auth.DemoUsers;

/**
 * On start-up: creates/updates the DB2 workflow schema (db/db2-workflow-schema.sql is idempotent)
 * and adds the demo sign-ins if they are missing. DB1 is never changed.
 */
@Component
public class SchemaInitializer implements ApplicationRunner {

    private final Db2 db2;
    private final DemoUsers demoUsers;

    public SchemaInitializer(Db2 db2, DemoUsers demoUsers) {
        this.db2 = db2;
        this.demoUsers = demoUsers;
    }

    @Override
    public void run(ApplicationArguments args) {
        initialise();
    }

    public void initialise() {
        for (String statement : splitStatements(readResource("/db/db2-workflow-schema.sql"))) db2.execute(statement);
        demoUsers.ensure();
    }

    static String readResource(String path) {
        try (InputStream in = SchemaInitializer.class.getResourceAsStream(path)) {
            if (in == null) throw new IllegalStateException("Missing resource " + path);
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new IllegalStateException("Cannot read " + path, e);
        }
    }

    /** Splits a SQL script on semicolons, ignoring "--" comment lines and anything inside $$ ... $$ bodies. */
    public static List<String> splitStatements(String script) {
        List<String> out = new ArrayList<>();
        StringBuilder current = new StringBuilder();
        boolean inDollar = false;
        for (String line : script.split("\n")) {
            String trimmed = line.trim();
            if (!inDollar && trimmed.startsWith("--")) continue;
            current.append(line).append('\n');
            int dollars = countOccurrences(line, "$$");
            if (dollars % 2 == 1) inDollar = !inDollar;
            if (!inDollar && trimmed.endsWith(";")) {
                String statement = current.toString().trim();
                statement = statement.substring(0, statement.length() - 1).trim();
                if (!statement.isEmpty()) out.add(statement);
                current.setLength(0);
            }
        }
        String rest = current.toString().trim();
        if (!rest.isEmpty()) out.add(rest);
        return out;
    }

    private static int countOccurrences(String text, String token) {
        int count = 0;
        for (int i = text.indexOf(token); i >= 0; i = text.indexOf(token, i + token.length())) count++;
        return count;
    }
}
