package com.winfo.labour.config;

import java.util.ArrayList;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Values from the "app" section of application.yml (each can be overridden in backend/.env). */
@Component
public class AppSettings {

    private final String appName;
    private final String tokenSecret;
    private final int tokenTtlHours;
    private final String allowedOrigins;
    private final boolean demoUsers;
    private final List<String> requestStatuses;

    public AppSettings(
            @Value("${app.name:WINFO Labour Manager}") String appName,
            @Value("${app.token-secret}") String tokenSecret,
            @Value("${app.token-ttl-hours:10}") int tokenTtlHours,
            @Value("${app.allowed-origins:http://localhost:5173}") String allowedOrigins,
            @Value("${app.demo-users:true}") boolean demoUsers,
            @Value("${app.agent.request-statuses:PUBLISHED}") String requestStatuses) {
        if (tokenSecret.startsWith("dev-only-")) {
            org.slf4j.LoggerFactory.getLogger(AppSettings.class).warn(
                    "Using the built-in TOKEN_SECRET. Fine on your own PC; set your own in backend/.env before anyone else can reach this server.");
        }
        this.appName = appName;
        this.tokenSecret = tokenSecret;
        this.tokenTtlHours = tokenTtlHours;
        this.allowedOrigins = allowedOrigins;
        this.demoUsers = demoUsers;
        List<String> statuses = new ArrayList<>();
        for (String st : requestStatuses.split(",")) {
            String t = st.trim().toUpperCase();
            if (t.isEmpty()) continue;
            if (!t.matches("[A-Z_]+")) throw new IllegalArgumentException("app.agent.request-statuses: invalid status '" + st + "'");
            statuses.add(t);
        }
        if (statuses.isEmpty()) statuses.add("PUBLISHED");
        this.requestStatuses = List.copyOf(statuses);
    }

    public String appName() { return appName; }
    public String tokenSecret() { return tokenSecret; }
    public int tokenTtlHours() { return tokenTtlHours; }
    public String[] allowedOrigins() { return allowedOrigins.split("\\s*,\\s*"); }
    public boolean demoUsers() { return demoUsers; }
    /** agent_playbook.status values that mean "the agent is asking for a decision" (validated: letters and _ only). */
    public List<String> requestStatuses() { return requestStatuses; }
}
