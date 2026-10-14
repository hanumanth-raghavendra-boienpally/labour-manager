package com.winfo.labour.auth;

import java.util.LinkedHashMap;
import java.util.Map;

/** The signed-in user for one request. */
public record Session(int userId, String username, String displayName, String role, String title) {

    public boolean is(String r) {
        return role.equals(r);
    }

    public Map<String, Object> toMap() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("userId", userId);
        m.put("username", username);
        m.put("displayName", displayName);
        m.put("role", role);
        m.put("roleLabel", Roles.label(role));
        m.put("title", title);
        m.put("pages", Roles.pages(role));
        m.put("permissions", Roles.permissions(role));
        return m;
    }
}
