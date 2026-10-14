package com.winfo.labour;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

import com.winfo.labour.db.DbPreflight;
import com.winfo.labour.db.DbSettings;

/**
 * WINFO Labour Manager.
 *
 *   AI agent -> DB1 (labor_allocation) -> Forecast page (store manager approves / rejects) -> DB2 (workflow) -> Allocation page (user)
 *                                                                                                    \-> Admin page (both)
 */
@SpringBootApplication
@EnableScheduling
public class LabourManagerApplication {

    public static void main(String[] args) {
        // Check both databases first, so any problem is one short readable message, not a stack trace.
        String problem;
        DbSettings db1 = null, db2 = null;
        String where = null;
        try {
            db1 = DbSettings.db1();
            where = db1.source;
            problem = DbPreflight.checkDb1(db1);
            if (problem == null) {
                db2 = DbSettings.db2();
                where = db2.source;
                problem = DbPreflight.checkDb2(db2);
            }
        } catch (DbSettings.ConfigException e) {
            problem = e.getMessage();
        }
        if (problem != null) {
            System.err.println();
            System.err.println("==================== DATABASE SETUP ====================");
            System.err.println(DbPreflight.forDisplay(problem));
            if (where != null) System.err.println("\n(Settings read from: " + where + ")");
            System.err.println("========================================================");
            System.exit(1);
        }
        System.out.println("DB1 OK (agent data, read-only): " + db1.database + " on " + db1.host + " as " + db1.user);
        System.out.println("DB2 OK (workflow data):         " + db2.database + " on " + db2.host + " as " + db2.user);
        SpringApplication.run(LabourManagerApplication.class, args);
    }
}
