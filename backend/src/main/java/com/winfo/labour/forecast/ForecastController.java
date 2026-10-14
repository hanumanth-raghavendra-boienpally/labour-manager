package com.winfo.labour.forecast;

import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.winfo.labour.auth.AuthService;
import com.winfo.labour.auth.Roles;
import com.winfo.labour.auth.Session;

/** Page 1: the agent's forecast request (DB1) and the store manager's decision (written to DB2). */
@RestController
@RequestMapping("/api/forecast")
public class ForecastController {

    private final AuthService auth;
    private final ForecastService forecasts;

    public ForecastController(AuthService auth, ForecastService forecasts) {
        this.auth = auth;
        this.forecasts = forecasts;
    }

    /** Latest request version for a DC and business date (store manager, admin). */
    @GetMapping
    public Map<String, Object> current(@RequestHeader(value = "Authorization", required = false) String authorization,
                                       @RequestParam("dcId") int dcId, @RequestParam("date") String date) {
        Session s = auth.require(authorization, Roles.STORE_MANAGER, Roles.ADMIN);
        return forecasts.viewLatest(s, dcId, date);
    }

    /** One specific request version (store manager, admin). */
    @GetMapping("/{requestId}")
    public Map<String, Object> detail(@RequestHeader(value = "Authorization", required = false) String authorization,
                                      @PathVariable("requestId") int requestId) {
        Session s = auth.require(authorization, Roles.STORE_MANAGER, Roles.ADMIN);
        return forecasts.view(s, requestId);
    }

    /** Body: { rowVersion, comment? }. Approves the forecast as sent and creates the allocation (ready at once). */
    @PostMapping("/{requestId}/approve")
    public Map<String, Object> approve(@RequestHeader(value = "Authorization", required = false) String authorization,
                                       @PathVariable("requestId") int requestId, @RequestBody Map<String, Object> body) {
        Session s = auth.require(authorization, Roles.STORE_MANAGER);
        return forecasts.approve(s, requestId, body);
    }

    /** Body: { rowVersion, comment? }. */
    @PostMapping("/{requestId}/reject")
    public Map<String, Object> reject(@RequestHeader(value = "Authorization", required = false) String authorization,
                                      @PathVariable("requestId") int requestId, @RequestBody Map<String, Object> body) {
        Session s = auth.require(authorization, Roles.STORE_MANAGER);
        return forecasts.reject(s, requestId, body);
    }

    /** Body: { rowVersion, comment? }. Rejected -> pending review again, review cycle + 1. */
    @PostMapping("/{requestId}/reopen")
    public Map<String, Object> reopen(@RequestHeader(value = "Authorization", required = false) String authorization,
                                      @PathVariable("requestId") int requestId, @RequestBody Map<String, Object> body) {
        Session s = auth.require(authorization, Roles.STORE_MANAGER);
        return forecasts.reopen(s, requestId, body);
    }
}
