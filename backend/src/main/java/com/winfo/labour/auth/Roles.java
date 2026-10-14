package com.winfo.labour.auth;

import java.util.List;
import java.util.Map;

/** The three sign-in roles. */
public final class Roles {

    /** Person A: is notified when the agent sends a forecast, approves or rejects it (page 1, reads DB1). */
    public static final String STORE_MANAGER = "STORE_MANAGER";
    /** Person B ("user"): is notified of the decision and sees the outcome and the allocation (page 2, reads DB2). Read-only. */
    public static final String ALLOCATOR = "ALLOCATOR";
    /** Person C: sees every forecast request and what happened to it (DB1 + DB2), the audit log; read-only. */
    public static final String ADMIN = "ADMIN";

    private Roles() {}

    public static String label(String role) {
        return switch (role) {
            case STORE_MANAGER -> "Store manager";
            case ALLOCATOR -> "User";
            case ADMIN -> "Administrator";
            default -> role;
        };
    }

    /** Pages each role sees in the navigation bar. */
    public static List<String> pages(String role) {
        return switch (role) {
            case STORE_MANAGER -> List.of("forecast");
            case ALLOCATOR -> List.of("allocation");
            case ADMIN -> List.of("admin");
            default -> List.of();
        };
    }

    public static Map<String, Boolean> permissions(String role) {
        return Map.of(
                "reviewForecast", STORE_MANAGER.equals(role),
                "viewAllocation", ALLOCATOR.equals(role),
                "viewAdmin", ADMIN.equals(role));
    }
}
