package com.winfo.labour.notify;

import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.winfo.labour.auth.AuthService;
import com.winfo.labour.auth.Session;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    private final AuthService auth;
    private final NotificationService notifications;

    public NotificationController(AuthService auth, NotificationService notifications) {
        this.auth = auth;
        this.notifications = notifications;
    }

    @GetMapping
    public Map<String, Object> list(@RequestHeader(value = "Authorization", required = false) String authorization) {
        Session s = auth.require(authorization);
        return notifications.list(s.userId());
    }

    @PostMapping("/{id}/read")
    public Map<String, Object> read(@RequestHeader(value = "Authorization", required = false) String authorization,
                                    @PathVariable("id") int id) {
        Session s = auth.require(authorization);
        notifications.markRead(s.userId(), id);
        return notifications.list(s.userId());
    }

    @PostMapping("/read-all")
    public Map<String, Object> readAll(@RequestHeader(value = "Authorization", required = false) String authorization) {
        Session s = auth.require(authorization);
        notifications.markAllRead(s.userId());
        return notifications.list(s.userId());
    }
}
