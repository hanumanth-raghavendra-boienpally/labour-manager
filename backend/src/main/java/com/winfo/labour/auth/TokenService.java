package com.winfo.labour.auth;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.Base64;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.stereotype.Component;

import com.winfo.labour.config.AppSettings;
import com.winfo.labour.web.ApiException;

/** Signed bearer tokens: base64url("userId.expiresEpoch") + "." + base64url(HMAC-SHA256). */
@Component
public class TokenService {

    private final byte[] secret;
    private final long ttlSeconds;

    public TokenService(AppSettings settings) {
        this.secret = settings.tokenSecret().getBytes(StandardCharsets.UTF_8);
        this.ttlSeconds = settings.tokenTtlHours() * 3600L;
    }

    public String issue(int userId) {
        String payload = userId + "." + (Instant.now().getEpochSecond() + ttlSeconds);
        Base64.Encoder b64 = Base64.getUrlEncoder().withoutPadding();
        return b64.encodeToString(payload.getBytes(StandardCharsets.UTF_8)) + "." + b64.encodeToString(sign(payload));
    }

    /** Returns the user id inside a valid, unexpired token, or throws 401. */
    public int verify(String token) {
        try {
            String[] parts = token.split("\\.");
            if (parts.length != 2) throw ApiException.unauthorized("Invalid sign-in token.");
            String payload = new String(Base64.getUrlDecoder().decode(parts[0]), StandardCharsets.UTF_8);
            byte[] signature = Base64.getUrlDecoder().decode(parts[1]);
            if (!MessageDigest.isEqual(signature, sign(payload))) throw ApiException.unauthorized("Invalid sign-in token.");
            String[] fields = payload.split("\\.");
            long expires = Long.parseLong(fields[1]);
            if (Instant.now().getEpochSecond() > expires) throw ApiException.unauthorized("Your session has expired. Sign in again.");
            return Integer.parseInt(fields[0]);
        } catch (IllegalArgumentException | ArrayIndexOutOfBoundsException e) {
            throw ApiException.unauthorized("Invalid sign-in token.");
        }
    }

    private byte[] sign(String payload) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret, "HmacSHA256"));
            return mac.doFinal(payload.getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("HmacSHA256 is not available", e);
        }
    }
}
