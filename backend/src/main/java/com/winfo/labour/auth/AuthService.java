package com.winfo.labour.auth;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;

import com.winfo.labour.config.AppSettings;
import com.winfo.labour.db.Db2;
import com.winfo.labour.db.Rows;
import com.winfo.labour.web.ApiException;

@Service
public class AuthService {

    private final Db2 db;
    private final TokenService tokens;
    private final AppSettings settings;

    public AuthService(Db2 db, TokenService tokens, AppSettings settings) {
        this.db = db;
        this.tokens = tokens;
        this.settings = settings;
    }

    public Map<String, Object> login(String username, String password) {
        if (username == null || username.isBlank() || password == null || password.isEmpty()) {
            throw ApiException.badRequest("Enter your username and password.");
        }
        Map<String, Object> row = db.one(
                "select user_id, username, display_name, role, title, password_hash, is_active "
                        + "from workflow.app_user where lower(username) = lower(?::text)", username.trim());
        if (row == null || !PasswordHasher.matches(password, Rows.s(row, "password_hash"))) {
            throw ApiException.unauthorized("Wrong username or password.");
        }
        if (!Rows.b(row, "is_active")) throw ApiException.forbidden("This account is disabled.");
        Session session = toSession(row);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("token", tokens.issue(session.userId()));
        out.put("user", session.toMap());
        return out;
    }

    /** Resolves the bearer token and checks the role. No roles given means any signed-in user. */
    public Session require(String authorization, String... roles) {
        if (authorization == null || !authorization.startsWith("Bearer ")) {
            throw ApiException.unauthorized("Sign in to continue.");
        }
        int userId = tokens.verify(authorization.substring("Bearer ".length()).trim());
        Map<String, Object> row = db.one(
                "select user_id, username, display_name, role, title, is_active from workflow.app_user where user_id = ?", userId);
        if (row == null || !Rows.b(row, "is_active")) throw ApiException.unauthorized("Sign in to continue.");
        Session session = toSession(row);
        if (roles.length > 0) {
            boolean allowed = false;
            for (String r : roles) allowed |= session.is(r);
            if (!allowed) {
                throw ApiException.forbidden("Your role (" + Roles.label(session.role()) + ") cannot do this.");
            }
        }
        return session;
    }

    public List<Map<String, Object>> demoIdentities() {
        List<Map<String, Object>> out = new ArrayList<>();
        if (!settings.demoUsers()) return out;
        for (Map<String, Object> row : db.rows(
                "select username, role from workflow.app_user where is_active order by case role "
                        + "when 'STORE_MANAGER' then 1 when 'ALLOCATOR' then 2 else 3 end, username")) {
            String role = Rows.s(row, "role");
            String purpose = switch (role) {
                case Roles.STORE_MANAGER -> "Store manager · approves or rejects the agent's forecasts";
                case Roles.ALLOCATOR -> "User · sees the outcome and the allocation";
                default -> "Administrator · every forecast and allocation, read-only";
            };
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("username", Rows.s(row, "username"));
            m.put("label", purpose);
            out.add(m);
        }
        return out;
    }

    private static Session toSession(Map<String, Object> row) {
        return new Session(Rows.i(row, "user_id"), Rows.s(row, "username"), Rows.s(row, "display_name"),
                Rows.s(row, "role"), Rows.s(row, "title"));
    }
}
