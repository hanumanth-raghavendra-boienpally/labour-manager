package com.winfo.labour.web;

import java.util.LinkedHashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/** Turns exceptions into {"status", "title", "detail"} JSON that the React client displays. */
@RestControllerAdvice
public class ApiExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<Map<String, Object>> api(ApiException e) {
        return ResponseEntity.status(e.status()).body(problem(e.status(), e.getMessage()));
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, Object>> conflict(DataIntegrityViolationException e) {
        log.warn("Integrity violation: {}", e.getMostSpecificCause().getMessage());
        return ResponseEntity.status(409).body(problem(409,
                "Someone else changed this record at the same time. Refresh and try again."));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> other(Exception e) {
        // Spring MVC's own request errors, matched by name so this works across Spring versions.
        switch (e.getClass().getSimpleName()) {
            case "NoResourceFoundException", "NoHandlerFoundException" -> {
                return ResponseEntity.status(404).body(problem(404, "No such API endpoint."));
            }
            case "HttpMessageNotReadableException", "MethodArgumentTypeMismatchException",
                 "MissingServletRequestParameterException", "HttpMediaTypeNotSupportedException" -> {
                return ResponseEntity.status(400).body(problem(400, "Invalid request: " + e.getMessage()));
            }
            case "HttpRequestMethodNotSupportedException" -> {
                return ResponseEntity.status(405).body(problem(405, e.getMessage()));
            }
            default -> { }
        }
        log.error("Unexpected error", e);
        return ResponseEntity.status(500).body(problem(500, "Unexpected server error: " + e.getMessage()));
    }

    public static Map<String, Object> problem(int status, String detail) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("status", status);
        body.put("title", switch (status) {
            case 400 -> "Bad request";
            case 401 -> "Sign-in required";
            case 403 -> "Not allowed";
            case 404 -> "Not found";
            case 409 -> "Conflict";
            default -> "Error";
        });
        body.put("detail", detail);
        return body;
    }
}
