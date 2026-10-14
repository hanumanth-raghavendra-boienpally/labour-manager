package com.winfo.labour.admin;

import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.winfo.labour.auth.AuthService;
import com.winfo.labour.auth.Roles;

@RestController
@RequestMapping("/api/admin")
public class AdminController {

    private final AuthService auth;
    private final AdminService admin;

    public AdminController(AuthService auth, AdminService admin) {
        this.auth = auth;
        this.admin = admin;
    }

    @GetMapping("/overview")
    public Map<String, Object> overview(@RequestHeader(value = "Authorization", required = false) String authorization) {
        auth.require(authorization, Roles.ADMIN);
        return admin.overview();
    }
}
