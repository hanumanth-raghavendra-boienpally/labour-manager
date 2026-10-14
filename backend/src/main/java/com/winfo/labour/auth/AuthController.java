package com.winfo.labour.auth;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.winfo.labour.config.AppSettings;
import com.winfo.labour.db.Rows;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService auth;
    private final AppSettings settings;

    public AuthController(AuthService auth, AppSettings settings) {
        this.auth = auth;
        this.settings = settings;
    }

    @PostMapping("/login")
    public Map<String, Object> login(@RequestBody Map<String, Object> body) {
        return auth.login(Rows.s(body, "username"), Rows.s(body, "password"));
    }

    @GetMapping("/me")
    public Map<String, Object> me(@RequestHeader(value = "Authorization", required = false) String authorization) {
        return auth.require(authorization).toMap();
    }

    @GetMapping("/demo-identities")
    public List<Map<String, Object>> demoIdentities() {
        return auth.demoIdentities();
    }

    @GetMapping("/app-info")
    public Map<String, Object> appInfo() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("name", settings.appName());
        return m;
    }
}
