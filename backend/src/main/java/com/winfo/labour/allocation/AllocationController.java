package com.winfo.labour.allocation;

import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.winfo.labour.auth.AuthService;
import com.winfo.labour.auth.Roles;
import com.winfo.labour.auth.Session;

/** Page 2: the outcome of the store manager's decision (DB2). Read-only. */
@RestController
@RequestMapping("/api/allocation")
public class AllocationController {

    private final AuthService auth;
    private final AllocationService allocations;

    public AllocationController(AuthService auth, AllocationService allocations) {
        this.auth = auth;
        this.allocations = allocations;
    }

    /** Latest request for a DC and business date (user, admin). */
    @GetMapping
    public Map<String, Object> current(@RequestHeader(value = "Authorization", required = false) String authorization,
                                       @RequestParam("dcId") int dcId, @RequestParam("date") String date) {
        Session s = auth.require(authorization, Roles.ALLOCATOR, Roles.ADMIN);
        return allocations.viewLatest(s, dcId, date);
    }

    /** One specific request (user, admin). */
    @GetMapping("/request/{requestId}")
    public Map<String, Object> byRequest(@RequestHeader(value = "Authorization", required = false) String authorization,
                                         @PathVariable("requestId") int requestId) {
        Session s = auth.require(authorization, Roles.ALLOCATOR, Roles.ADMIN);
        return allocations.view(s, requestId);
    }
}
