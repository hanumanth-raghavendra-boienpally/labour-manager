package com.winfo.labour.auth;

import java.util.List;

import org.springframework.stereotype.Component;

import com.winfo.labour.config.AppSettings;
import com.winfo.labour.db.Db2;

/** Creates the three demo sign-ins in DB2 the first time the app starts (passwords are listed in the README). */
@Component
public class DemoUsers {

    record DemoUser(String username, String password, String displayName, String role, String title) {}

    static final List<DemoUser> USERS = List.of(
            new DemoUser("store_manager", "Store@123", "Sam Carter", Roles.STORE_MANAGER, "Store manager"),
            new DemoUser("user", "User@123", "Ravi Kumar", Roles.ALLOCATOR, "Allocation user"),
            new DemoUser("admin", "Admin@123", "System Admin", Roles.ADMIN, "Administrator"));

    private final Db2 db;
    private final AppSettings settings;

    public DemoUsers(Db2 db, AppSettings settings) {
        this.db = db;
        this.settings = settings;
    }

    public void ensure() {
        if (!settings.demoUsers()) return;
        for (DemoUser u : USERS) {
            int exists = db.intValue("select count(*) from workflow.app_user where username = ?::text", u.username());
            if (exists == 0) {
                db.exec("insert into workflow.app_user (username, display_name, role, title, password_hash) "
                                + "values (?::text, ?::text, ?::text, ?::text, ?::text) on conflict (username) do nothing",
                        u.username(), u.displayName(), u.role(), u.title(), PasswordHasher.hash(u.password()));
            }
        }
    }
}
