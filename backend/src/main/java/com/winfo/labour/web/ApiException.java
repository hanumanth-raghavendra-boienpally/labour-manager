package com.winfo.labour.web;

/** An error with an HTTP status and a message the UI shows as-is. */
public class ApiException extends RuntimeException {

    private final int status;

    public ApiException(int status, String message) {
        super(message);
        this.status = status;
    }

    public int status() {
        return status;
    }

    public static ApiException badRequest(String message) { return new ApiException(400, message); }
    public static ApiException unauthorized(String message) { return new ApiException(401, message); }
    public static ApiException forbidden(String message) { return new ApiException(403, message); }
    public static ApiException notFound(String message) { return new ApiException(404, message); }
    public static ApiException conflict(String message) { return new ApiException(409, message); }
}
