package com.winfo.labour.agent;

import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.winfo.labour.config.AppSettings;
import com.winfo.labour.db.Rows;

/**
 * Watches DB1 for the agent's dumps. Every few seconds (app.agent.poll-ms) it lists agent_playbook rows whose status is
 * one of app.agent.request-statuses (PUBLISHED by default) and registers each publication it has not seen yet.
 * A playbook without lines is skipped until the agent has written them.
 */
@Component
public class AgentWatcher {

    private static final Logger log = LoggerFactory.getLogger(AgentWatcher.class);

    private final AgentPlaybookReader reader;
    private final RequestIntake intake;
    private final AppSettings settings;
    private final Set<String> reportedFailures = new HashSet<>();

    public AgentWatcher(AgentPlaybookReader reader, RequestIntake intake, AppSettings settings) {
        this.reader = reader;
        this.intake = intake;
        this.settings = settings;
    }

    @Scheduled(initialDelayString = "${app.agent.initial-delay-ms:2000}", fixedDelayString = "${app.agent.poll-ms:3000}")
    public void poll() {
        try {
            for (Map<String, Object> p : reader.publications(settings.requestStatuses())) {
                String key = Rows.s(p, "source_key");
                if (Rows.i(p, "lines") == 0 || intake.known(key)) continue;
                try {
                    AgentForecast f = reader.read(Rows.i(p, "playbook_id"));
                    if (f == null || !key.equals(f.sourceKey())) continue; // changed while we looked: next poll
                    Integer id = intake.register(f);
                    if (id != null) log.info("Agent playbook #{} ({} {}) registered as forecast request {}", f.playbookId(), f.dcCode(),
                            f.businessDate(), id);
                    reportedFailures.remove(key);
                } catch (RuntimeException e) {
                    if (reportedFailures.add(key)) log.warn("Agent playbook {} could not be registered: {}", key, e.getMessage());
                }
            }
        } catch (RuntimeException e) {
            if (reportedFailures.add("poll")) log.warn("Checking DB1 for agent playbooks failed: {}", e.getMessage());
            return;
        }
        reportedFailures.remove("poll");
    }
}
